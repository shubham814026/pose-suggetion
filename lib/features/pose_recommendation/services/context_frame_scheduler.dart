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
  List<double> _sceneVector = List.filled(64, 0.15);
  int _detectedPeopleCount = 1;
  int _detectedPropIndex = 0;
  bool _isFrontCamera = true;
  StanceType _currentStance = StanceType.standing;
  TargetPose? _neuralGeneratedPose;

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
  TargetPose? get neuralGeneratedPose => _neuralGeneratedPose;

  /// Fast Pipeline (30 FPS / ~80ms throttle):
  /// Ingests live poses from Google ML Kit to update people count & joint stance.
  void onFramePoses(List<Pose> poses, {required bool isFrontCamera}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _isFrontCamera = isFrontCamera;

    // Fast Pipeline Latch: ~60ms (up to ~16 FPS on mobile)
    if (now - _lastFastRunMs >= 60) {
      _lastFastRunMs = now;
      final int previousCount = _detectedPeopleCount;
      _detectedPeopleCount = max(1, poses.length);

      if (previousCount != _detectedPeopleCount) {
        _recomputeContextVector();
        notifyListeners();
      }
    }

    // Medium Pipeline Latch: ~500ms (2 FPS)
    if (now - _lastMediumRunMs >= 500) {
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
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    StanceType detectedStance = StanceType.standing;

    if (leftHip != null && leftKnee != null && leftAnkle != null &&
        leftHip.likelihood > 0.5 && leftKnee.likelihood > 0.5) {
      final double kneeAngle = _calculate2DAngle(leftHip, leftKnee, leftAnkle);
      if (kneeAngle < 125.0) {
        detectedStance = StanceType.sitting;
      }
    } else if (rightHip != null && rightKnee != null && rightAnkle != null &&
        rightHip.likelihood > 0.5 && rightKnee.likelihood > 0.5) {
      final double kneeAngle = _calculate2DAngle(rightHip, rightKnee, rightAnkle);
      if (kneeAngle < 125.0) {
        detectedStance = StanceType.sitting;
      }
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
    );

    // If weights are loaded, generate novel real-time target pose
    if (_recommender.isInitialized) {
      _neuralGeneratedPose = _recommender.generatePoseFromContext(_currentContextVector);
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

