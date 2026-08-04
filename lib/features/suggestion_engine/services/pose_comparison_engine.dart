import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../pose_library/models/target_pose.dart';
import '../models/joint_delta.dart';

class PoseComparisonEngine {
  static const double defaultAngleToleranceDegrees = 15.0;
  static const double maxPenaltyAngleDegrees = 45.0;

  /// Calculate the 2D/3D angle in degrees at vertex landmark [mid]
  /// formed by vectors (mid -> first) and (mid -> last).
  static double calculateAngle(
    PoseLandmark first,
    PoseLandmark mid,
    PoseLandmark last,
  ) {
    final double baX = first.x - mid.x;
    final double baY = first.y - mid.y;

    final double bcX = last.x - mid.x;
    final double bcY = last.y - mid.y;

    final double dotProduct = (baX * bcX) + (baY * bcY);
    final double magBA = sqrt((baX * baX) + (baY * baY));
    final double magBC = sqrt((bcX * bcX) + (bcY * bcY));

    if (magBA == 0.0 || magBC == 0.0) return 0.0;

    final double cosine = (dotProduct / (magBA * magBC)).clamp(-1.0, 1.0);
    final double angleRadians = acos(cosine);
    return angleRadians * (180.0 / pi);
  }

  /// Pure Dart function: live keypoints + target keypoints → per-joint deltas.
  /// UI-independent and fully unit-testable.
  List<JointDelta> comparePoses({
    required Pose livePose,
    required TargetPose targetPose,
    double toleranceDegrees = defaultAngleToleranceDegrees,
  }) {
    final List<JointDelta> deltas = [];
    final landmarks = livePose.landmarks;

    void processJoint({
      required String jointName,
      required PoseLandmarkType firstType,
      required PoseLandmarkType midType,
      required PoseLandmarkType lastType,
    }) {
      final first = landmarks[firstType];
      final mid = landmarks[midType];
      final last = landmarks[lastType];

      final targetAngle = targetPose.targetAngles[jointName];
      if (first == null || mid == null || last == null || targetAngle == null) {
        return;
      }

      if (first.likelihood < 0.5 || mid.likelihood < 0.5 || last.likelihood < 0.5) {
        return;
      }

      final liveAngle = calculateAngle(first, mid, last);
      final delta = liveAngle - targetAngle;
      final isWithin = delta.abs() <= toleranceDegrees;

      deltas.add(
        JointDelta(
          jointName: jointName,
          liveAngleDegrees: liveAngle,
          targetAngleDegrees: targetAngle,
          deltaDegrees: delta,
          isWithinTolerance: isWithin,
        ),
      );
    }

    processJoint(
      jointName: 'left_elbow',
      firstType: PoseLandmarkType.leftShoulder,
      midType: PoseLandmarkType.leftElbow,
      lastType: PoseLandmarkType.leftWrist,
    );

    processJoint(
      jointName: 'right_elbow',
      firstType: PoseLandmarkType.rightShoulder,
      midType: PoseLandmarkType.rightElbow,
      lastType: PoseLandmarkType.rightWrist,
    );

    processJoint(
      jointName: 'left_shoulder',
      firstType: PoseLandmarkType.leftHip,
      midType: PoseLandmarkType.leftShoulder,
      lastType: PoseLandmarkType.leftElbow,
    );

    processJoint(
      jointName: 'right_shoulder',
      firstType: PoseLandmarkType.rightHip,
      midType: PoseLandmarkType.rightShoulder,
      lastType: PoseLandmarkType.rightElbow,
    );

    processJoint(
      jointName: 'left_hip',
      firstType: PoseLandmarkType.leftShoulder,
      midType: PoseLandmarkType.leftHip,
      lastType: PoseLandmarkType.leftKnee,
    );

    processJoint(
      jointName: 'right_hip',
      firstType: PoseLandmarkType.rightShoulder,
      midType: PoseLandmarkType.rightHip,
      lastType: PoseLandmarkType.rightKnee,
    );

    processJoint(
      jointName: 'left_knee',
      firstType: PoseLandmarkType.leftHip,
      midType: PoseLandmarkType.leftKnee,
      lastType: PoseLandmarkType.leftAnkle,
    );

    processJoint(
      jointName: 'right_knee',
      firstType: PoseLandmarkType.rightHip,
      midType: PoseLandmarkType.rightKnee,
      lastType: PoseLandmarkType.rightAnkle,
    );

    return deltas;
  }

  /// Calculate an overall numeric match score (0.0 to 100.0%) from joint deltas (Item 15)
  double calculateMatchScore(List<JointDelta> deltas) {
    if (deltas.isEmpty) return 0.0;

    double totalNormalizedPenalty = 0.0;

    for (final d in deltas) {
      final absDelta = d.deltaDegrees.abs();
      // Normalize penalty between 0.0 (perfect) and 1.0 (>= maxPenaltyAngleDegrees)
      final penalty = (absDelta / maxPenaltyAngleDegrees).clamp(0.0, 1.0);
      totalNormalizedPenalty += penalty;
    }

    final averagePenalty = totalNormalizedPenalty / deltas.length;
    final score = (1.0 - averagePenalty) * 100.0;
    return score.clamp(0.0, 100.0);
  }
}
