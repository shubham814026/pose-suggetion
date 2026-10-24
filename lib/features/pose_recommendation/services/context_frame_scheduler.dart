import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../pose_library/data/models/target_pose.dart';
import 'pose_recommendation_service.dart';

/// Body stance posture state detected from real-time joints
enum StanceType { standing, sitting, crouching, closeUpPortrait, unknown }

/// Multi-Tier Context Frame Scheduler (Phase 14).
/// Aggregates:
///  - Fast Pipeline (30 FPS): Live 3D skeleton keypoints, people count, and joint angles.
///  - Medium Pipeline (2 FPS): Stance classification (sitting vs standing) & motion stability.
///  - Slow Pipeline (0.5 FPS): Semantic scene embeddings (64-d) & prop detection tokens.
class ContextFrameScheduler extends ChangeNotifier {
  final PoseRecommendationService _recommender;

  // Real-time Aggregated Context State
  List<double> _currentContextVector = List.filled(80, 0.0);
  List<double> _sceneVector = List.filled(64, 0.0);
  int _detectedPeopleCount = 0;
  int _detectedPropIndex = 4; // Default to Home, Cozy & Balcony (4), not Beach (0)
  bool _isFrontCamera = true;
  StanceType _currentStance = StanceType.standing;
  List<Pose> _currentPoses = [];
  TargetPose? _neuralGeneratedPose;
  double _shoulderWidthNorm = 0.16;
  double _torsoHeightNorm = 0.40;
  bool _isLegsVisible = true;
  bool _isSelfieComposition = false;
  double _kneeAngleNorm = 0.95;
  double _hipAngleNorm = 0.95;
  double _interPersonProximity = 0.0;

  // Pipeline Execution Timers & Latches (ms)
  int _lastFastRunMs = 0;
  int _lastMediumRunMs = 0;
  int _lastSlowRunMs = 0;

  ContextFrameScheduler({
    required PoseRecommendationService recommender,
  }) : _recommender = recommender {
    _recomputeContextVector();
  }

  List<double> get currentContextVector => List.unmodifiable(_currentContextVector);
  List<double> get sceneVector => List.unmodifiable(_sceneVector);
  int get detectedPeopleCount => _detectedPeopleCount;
  int get detectedPropIndex => _detectedPropIndex;
  bool get isFrontCamera => _isFrontCamera;
  StanceType get currentStance => _currentStance;
  List<Pose> get currentPoses => _currentPoses;
  TargetPose? get neuralGeneratedPose => _neuralGeneratedPose;

  /// Fast Pipeline (30 FPS / ~80ms throttle):
  /// Ingests live poses and detected people count from ML detectors to update people count & joint stance.
  void onFramePoses(List<Pose> poses, {required bool isFrontCamera, int? peopleCount}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _isFrontCamera = isFrontCamera;
    _currentPoses = poses;

    final int exactPeopleCount = peopleCount ?? poses.length;

    // Fast Pipeline Latch: ~60ms
    if (now - _lastFastRunMs >= 60) {
      _lastFastRunMs = now;
      final int previousCount = _detectedPeopleCount;
      _detectedPeopleCount = exactPeopleCount;

      if (previousCount != _detectedPeopleCount) {
        _recomputeContextVector();
        notifyListeners();
      }
    }

    // Medium Pipeline Latch: ~400ms
    if (now - _lastMediumRunMs >= 400) {
      _lastMediumRunMs = now;
      _processMediumPipeline(poses);
    }
  }

  /// Medium Pipeline (2 FPS / 500ms):
  /// Classifies user stance (sitting, standing, close-up) from knee & hip angles.
  void _processMediumPipeline(List<Pose> poses) {
    if (poses.isEmpty) {
      if (_currentStance != StanceType.unknown) {
        _currentStance = StanceType.unknown;
        notifyListeners();
      }
      return;
    }

    final pose = poses.first;
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder != null && rightShoulder != null &&
        leftShoulder.likelihood > 0.4 && rightShoulder.likelihood > 0.4) {
      _shoulderWidthNorm = (rightShoulder.x - leftShoulder.x).abs();
    }

    if (leftShoulder != null && rightShoulder != null && leftHip != null && rightHip != null) {
      final double shoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
      final double hipY = (leftHip.y + rightHip.y) / 2.0;
      _torsoHeightNorm = (hipY - shoulderY).abs();
    }

    _isLegsVisible = (leftAnkle != null && leftAnkle.likelihood > 0.4) ||
        (rightAnkle != null && rightAnkle.likelihood > 0.4);

    _isSelfieComposition = _isFrontCamera || (_shoulderWidthNorm > 0.22 && !_isLegsVisible);

    StanceType detectedStance = StanceType.standing;

    if (leftHip != null && leftKnee != null && leftAnkle != null &&
        leftHip.likelihood > 0.5 && leftKnee.likelihood > 0.5) {
      final double kneeAngle = _calculate2DAngle(leftHip, leftKnee, leftAnkle);
      _kneeAngleNorm = (kneeAngle / 180.0).clamp(0.0, 1.0);
      if (kneeAngle < 125.0) {
        detectedStance = StanceType.sitting;
      }
    } else if (rightHip != null && rightKnee != null && rightAnkle != null &&
        rightHip.likelihood > 0.5 && rightKnee.likelihood > 0.5) {
      final double kneeAngle = _calculate2DAngle(rightHip, rightKnee, rightAnkle);
      _kneeAngleNorm = (kneeAngle / 180.0).clamp(0.0, 1.0);
      if (kneeAngle < 125.0) {
        detectedStance = StanceType.sitting;
      }
    }

    if (leftShoulder != null && leftHip != null && leftKnee != null &&
        leftShoulder.likelihood > 0.4 && leftHip.likelihood > 0.4) {
      final double hipAngle = _calculate2DAngle(leftShoulder, leftHip, leftKnee);
      _hipAngleNorm = (hipAngle / 180.0).clamp(0.0, 1.0);
    }

    if (poses.length >= 2) {
      final p1 = poses[0].landmarks[PoseLandmarkType.nose];
      final p2 = poses[1].landmarks[PoseLandmarkType.nose];
      if (p1 != null && p2 != null) {
        final dist = (p1.x - p2.x).abs();
        _interPersonProximity = (1.0 - dist).clamp(0.0, 1.0);
      }
    } else {
      _interPersonProximity = 0.0;
    }

    if (detectedStance != _currentStance) {
      _currentStance = detectedStance;
      _recomputeContextVector();
      notifyListeners();
    }
  }

  /// Slow Pipeline (0.5 FPS / 2000ms):
  /// Ingests semantic scene embedding vectors and detected prop tokens.
  void updateSceneAndProps({
    List<double>? sceneVector,
    int? propIndex,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSlowRunMs < 1000) return;
    _lastSlowRunMs = now;

    bool changed = false;

    if (sceneVector != null && sceneVector.length == 64) {
      _sceneVector = sceneVector;
      changed = true;
    }

    if (propIndex != null && propIndex != _detectedPropIndex) {
      _detectedPropIndex = propIndex.clamp(0, 9);
      changed = true;
    }

    if (changed) {
      _recomputeContextVector();
      notifyListeners();
    }
  }

  /// Recomputes the 80-d context conditioning tensor and generates target silhouette from neural net
  void _recomputeContextVector() {
    _currentContextVector = _recommender.buildContextVector(
      sceneVector: _sceneVector,
      propIndex: _detectedPropIndex,
      peopleCount: _detectedPeopleCount,
      isFrontCamera: _isFrontCamera,
      isSelfieComposition: _isSelfieComposition,
      shoulderWidthNorm: _shoulderWidthNorm,
      torsoHeightNorm: _torsoHeightNorm,
      isSitting: _currentStance == StanceType.sitting,
      isStanding: _currentStance == StanceType.standing,
      isLegsVisible: _isLegsVisible,
      kneeAngleNorm: _kneeAngleNorm,
      hipAngleNorm: _hipAngleNorm,
      interPersonProximity: _interPersonProximity,
    );

    // If weights are loaded and at least 1 person is detected, generate novel real-time target pose
    if (_recommender.isInitialized && _detectedPeopleCount > 0) {
      _neuralGeneratedPose = _recommender.generatePoseFromContext(_currentContextVector);
    } else {
      _neuralGeneratedPose = null;
    }
  }

  /// Calculates 2D interior joint angle in degrees
  double _calculate2DAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final double radians = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
    double angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }
}

