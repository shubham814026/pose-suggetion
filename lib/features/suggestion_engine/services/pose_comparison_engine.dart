import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../pose_library/data/models/target_pose.dart';

/// 3D Point representation for scale-invariant normalized keypoint math
class Point3D {
  final double x;
  final double y;
  final double z;

  const Point3D(this.x, this.y, this.z);

  Point3D operator -(Point3D other) => Point3D(x - other.x, y - other.y, z - other.z);
  Point3D operator /(double divisor) => Point3D(x / divisor, y / divisor, z / divisor);

  double get norm => sqrt(x * x + y * y + z * z);
}

/// Normalized Keypoint with visibility weight
class NormalizedLandmark {
  final Point3D point;
  final double visibility;

  const NormalizedLandmark(this.point, this.visibility);
}

/// Advanced Pose Comparison Engine using normalized bounding-box translation,
/// torso scale invariance, Object Keypoint Similarity (OKS), and 3D Euclidean joint angle loss.
class PoseComparisonEngine {
  /// Calculates 3D vertex angle in degrees at joint B between vectors BA and BC:
  /// theta = arccos( (BA . BC) / (||BA|| * ||BC||) )
  static double calculate3DAngle(Point3D a, Point3D b, Point3D c) {
    final double baX = a.x - b.x;
    final double baY = a.y - b.y;
    final double baZ = a.z - b.z;

    final double bcX = c.x - b.x;
    final double bcY = c.y - b.y;
    final double bcZ = c.z - b.z;

    final double dotProduct = (baX * bcX) + (baY * bcY) + (baZ * bcZ);
    final double normBA = sqrt((baX * baX) + (baY * baY) + (baZ * baZ));
    final double normBC = sqrt((bcX * bcX) + (bcY * bcY) + (bcZ * bcZ));

    if (normBA == 0.0 || normBC == 0.0) return 0.0;

    final double cosine = (dotProduct / (normBA * normBC)).clamp(-1.0, 1.0);
    final double angleRadians = acos(cosine);
    return (angleRadians * 180.0 / pi);
  }

  /// Normalizes ML Kit [Pose] landmarks to be scale-invariant, centered at mid-hip (0,0,0),
  /// and scaled by torso length (mid-hip to mid-shoulder distance).
  static Map<int, NormalizedLandmark> normalizeLivePose(Pose pose) {
    final Map<int, NormalizedLandmark> rawPoints = {};
    for (final landmark in pose.landmarks.values) {
      // Landmark index maps to MediaPipe 33 keypoint schema
      final int index = landmark.type.index;
      rawPoints[index] = NormalizedLandmark(
        Point3D(landmark.x, landmark.y, landmark.z),
        landmark.likelihood.clamp(0.0, 1.0),
      );
    }

    // Mid-Hip (Indices 23: Left Hip, 24: Right Hip)
    final pLeftHip = rawPoints[23]?.point;
    final pRightHip = rawPoints[24]?.point;
    if (pLeftHip == null || pRightHip == null) return {};

    final midHip = Point3D(
      (pLeftHip.x + pRightHip.x) / 2.0,
      (pLeftHip.y + pRightHip.y) / 2.0,
      (pLeftHip.z + pRightHip.z) / 2.0,
    );

    // Mid-Shoulder (Indices 11: Left Shoulder, 12: Right Shoulder)
    final pLeftShoulder = rawPoints[11]?.point;
    final pRightShoulder = rawPoints[12]?.point;
    final midShoulder = (pLeftShoulder != null && pRightShoulder != null)
        ? Point3D(
            (pLeftShoulder.x + pRightShoulder.x) / 2.0,
            (pLeftShoulder.y + pRightShoulder.y) / 2.0,
            (pLeftShoulder.z + pRightShoulder.z) / 2.0,
          )
        : null;

    // Torso length scale factor
    double torsoScale = (midShoulder != null) ? (midShoulder - midHip).norm : 1.0;
    if (torsoScale <= 0.001) torsoScale = 1.0;

    final Map<int, NormalizedLandmark> normalized = {};
    rawPoints.forEach((idx, lm) {
      final centered = (lm.point - midHip) / torsoScale;
      normalized[idx] = NormalizedLandmark(centered, lm.visibility);
    });

    return normalized;
  }

  /// Normalizes target pose keypoint list relative to mid-hip and torso scale.
  static Map<int, NormalizedLandmark> normalizeTargetPose(TargetPose targetPose) {
    final Map<int, NormalizedLandmark> rawPoints = {};
    for (int i = 0; i < targetPose.keypoints.length; i++) {
      final kp = targetPose.keypoints[i];
      rawPoints[i] = NormalizedLandmark(
        Point3D(kp.x, kp.y, kp.z),
        kp.visibility.clamp(0.0, 1.0),
      );
    }

    final pLeftHip = rawPoints[23]?.point;
    final pRightHip = rawPoints[24]?.point;
    if (pLeftHip == null || pRightHip == null) return {};

    final midHip = Point3D(
      (pLeftHip.x + pRightHip.x) / 2.0,
      (pLeftHip.y + pRightHip.y) / 2.0,
      (pLeftHip.z + pRightHip.z) / 2.0,
    );

    final pLeftShoulder = rawPoints[11]?.point;
    final pRightShoulder = rawPoints[12]?.point;
    final midShoulder = (pLeftShoulder != null && pRightShoulder != null)
        ? Point3D(
            (pLeftShoulder.x + pRightShoulder.x) / 2.0,
            (pLeftShoulder.y + pRightShoulder.y) / 2.0,
            (pLeftShoulder.z + pRightShoulder.z) / 2.0,
          )
        : null;

    double torsoScale = (midShoulder != null) ? (midShoulder - midHip).norm : 1.0;
    if (torsoScale <= 0.001) torsoScale = 1.0;

    final Map<int, NormalizedLandmark> normalized = {};
    rawPoints.forEach((idx, lm) {
      final centered = (lm.point - midHip) / torsoScale;
      normalized[idx] = NormalizedLandmark(centered, lm.visibility);
    });

    return normalized;
  }

  /// Extracts 8 major 3D joint vertex angles from normalized landmarks map.
  static Map<String, double> extractJointAnglesFromMap(Map<int, NormalizedLandmark> map) {
    Point3D? p(int idx) => map[idx]?.point;

    final Map<String, double> angles = {};

    // Left Elbow: Shoulder(11) -> Elbow(13) -> Wrist(15)
    if (p(11) != null && p(13) != null && p(15) != null) {
      angles['elbowLeft'] = calculate3DAngle(p(11)!, p(13)!, p(15)!);
    }

    // Right Elbow: Shoulder(12) -> Elbow(14) -> Wrist(16)
    if (p(12) != null && p(14) != null && p(16) != null) {
      angles['elbowRight'] = calculate3DAngle(p(12)!, p(14)!, p(16)!);
    }

    // Left Shoulder: Hip(23) -> Shoulder(11) -> Elbow(13)
    if (p(23) != null && p(11) != null && p(13) != null) {
      angles['shoulderLeft'] = calculate3DAngle(p(23)!, p(11)!, p(13)!);
    }

    // Right Shoulder: Hip(24) -> Shoulder(12) -> Elbow(14)
    if (p(24) != null && p(12) != null && p(14) != null) {
      angles['shoulderRight'] = calculate3DAngle(p(24)!, p(12)!, p(14)!);
    }

    // Left Hip: Shoulder(11) -> Hip(23) -> Knee(25)
    if (p(11) != null && p(23) != null && p(25) != null) {
      angles['hipLeft'] = calculate3DAngle(p(11)!, p(23)!, p(25)!);
    }

    // Right Hip: Shoulder(12) -> Hip(24) -> Knee(26)
    if (p(12) != null && p(24) != null && p(26) != null) {
      angles['hipRight'] = calculate3DAngle(p(12)!, p(24)!, p(26)!);
    }

    // Left Knee: Hip(23) -> Knee(25) -> Ankle(27)
    if (p(23) != null && p(25) != null && p(27) != null) {
      angles['kneeLeft'] = calculate3DAngle(p(23)!, p(25)!, p(27)!);
    }

    // Right Knee: Hip(24) -> Knee(26) -> Ankle(28)
    if (p(24) != null && p(26) != null && p(28) != null) {
      angles['kneeRight'] = calculate3DAngle(p(24)!, p(26)!, p(28)!);
    }

    return angles;
  }

  /// Calculates high-precision Object Keypoint Similarity (OKS) score in [0.0, 1.0].
  static double computeOKSScore(
    Map<int, NormalizedLandmark> userPoints,
    Map<int, NormalizedLandmark> targetPoints,
  ) {
    if (userPoints.isEmpty || targetPoints.isEmpty) return 0.0;

    double weightedSumExp = 0.0;
    double totalVisibilityWeight = 0.0;

    // Per-keypoint scale constant (upper body = 0.079, limbs = 0.089)
    const double k = 0.085;

    userPoints.forEach((idx, userLm) {
      final targetLm = targetPoints[idx];
      if (targetLm != null && userLm.visibility >= 0.3 && targetLm.visibility >= 0.3) {
        final double dist = (userLm.point - targetLm.point).norm;
        final double weight = userLm.visibility * targetLm.visibility;

        final double oksTerm = exp(-(dist * dist) / (2.0 * k * k));
        weightedSumExp += oksTerm * weight;
        totalVisibilityWeight += weight;
      }
    });

    if (totalVisibilityWeight <= 0.0) return 0.0;
    return (weightedSumExp / totalVisibilityWeight).clamp(0.0, 1.0);
  }

  /// Calculates dynamic real-time posture alignment percentage in [0.0, 100.0%]
  /// combining 60% Joint Angle Accuracy + 40% Scale-Invariant OKS Position Accuracy.
  static double computeAlignmentScore({
    required Pose livePose,
    required TargetPose targetPose,
  }) {
    final userMap = normalizeLivePose(livePose);
    final targetMap = normalizeTargetPose(targetPose);

    if (userMap.isEmpty || targetMap.isEmpty) {
      return 0.0;
    }

    // 1. Joint Angle Accuracy (60% weight)
    final userAngles = extractJointAnglesFromMap(userMap);
    final targetAngles = targetPose.targetJointAngles.isNotEmpty
        ? targetPose.targetJointAngles
        : extractJointAnglesFromMap(targetMap);

    double totalAngleError = 0.0;
    int evaluatedJoints = 0;

    targetAngles.forEach((jointName, targetAngle) {
      if (userAngles.containsKey(jointName)) {
        final double userAngle = userAngles[jointName]!;
        final double delta = (userAngle - targetAngle).abs();
        totalAngleError += delta;
        evaluatedJoints++;
      }
    });

    double angleScore = 0.0;
    if (evaluatedJoints > 0) {
      final double meanAngleError = totalAngleError / evaluatedJoints;
      // Map mean error [0°, 60°] to score [1.0, 0.0]
      angleScore = (1.0 - (meanAngleError / 60.0)).clamp(0.0, 1.0);
    }

    // 2. Scale-Invariant OKS Similarity (40% weight)
    final double oksScore = computeOKSScore(userMap, targetMap);

    // Hybrid Weighted Score
    final double hybridScore = (0.60 * angleScore + 0.40 * oksScore) * 100.0;
    return hybridScore.clamp(0.0, 100.0);
  }

  /// Returns angular deltas (userAngle - targetAngle) for evaluated joints.
  static Map<String, double> computeJointDeltas({
    required Pose livePose,
    required TargetPose targetPose,
  }) {
    final userMap = normalizeLivePose(livePose);
    final targetMap = normalizeTargetPose(targetPose);

    final userAngles = extractJointAnglesFromMap(userMap);
    final targetAngles = targetPose.targetJointAngles.isNotEmpty
        ? targetPose.targetJointAngles
        : extractJointAnglesFromMap(targetMap);

    final Map<String, double> deltas = {};

    targetAngles.forEach((jointName, targetAngle) {
      if (userAngles.containsKey(jointName)) {
        deltas[jointName] = userAngles[jointName]! - targetAngle;
      }
    });

    return deltas;
  }
}
