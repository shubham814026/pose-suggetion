import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_suggestion_app/features/pose_library/models/target_pose.dart';
import 'package:pose_suggestion_app/features/suggestion_engine/models/joint_delta.dart';
import 'package:pose_suggestion_app/features/suggestion_engine/services/pose_comparison_engine.dart';

void main() {
  group('PoseComparisonEngine Unit Tests', () {
    final engine = PoseComparisonEngine();

    test('calculateAngle returns 90 degrees for right angle vectors', () {
      final p1 = PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 0.0, y: 1.0, z: 0.0, likelihood: 1.0);
      final mid = PoseLandmark(type: PoseLandmarkType.leftElbow, x: 0.0, y: 0.0, z: 0.0, likelihood: 1.0);
      final p2 = PoseLandmark(type: PoseLandmarkType.leftWrist, x: 1.0, y: 0.0, z: 0.0, likelihood: 1.0);

      final angle = PoseComparisonEngine.calculateAngle(p1, mid, p2);
      expect(angle.round(), equals(90));
    });

    test('calculateAngle returns 180 degrees for straight line vectors', () {
      final p1 = PoseLandmark(type: PoseLandmarkType.leftHip, x: 0.0, y: 0.0, z: 0.0, likelihood: 1.0);
      final mid = PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0.0, y: 0.5, z: 0.0, likelihood: 1.0);
      final p2 = PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0.0, y: 1.0, z: 0.0, likelihood: 1.0);

      final angle = PoseComparisonEngine.calculateAngle(p1, mid, p2);
      expect(angle.round(), equals(180));
    });

    test('calculateMatchScore returns 100% when deltas are zero', () {
      final deltas = [
        const JointDelta(
          jointName: 'left_elbow',
          liveAngleDegrees: 90.0,
          targetAngleDegrees: 90.0,
          deltaDegrees: 0.0,
          isWithinTolerance: true,
        ),
      ];

      final score = engine.calculateMatchScore(deltas);
      expect(score, equals(100.0));
    });

    test('comparePoses computes joint deltas accurately against target pose', () {
      final mockTargetPose = TargetPose(
        id: 'test_pose',
        name: 'Test Pose',
        category: 'Standing',
        tags: ['test'],
        description: 'Test description',
        targetAngles: {
          'left_elbow': 90.0,
          'right_elbow': 180.0,
        },
        keypoints: [],
      );

      final mockPose = Pose(
        landmarks: {
          PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 0.0, y: 1.0, z: 0.0, likelihood: 1.0),
          PoseLandmarkType.leftElbow: PoseLandmark(type: PoseLandmarkType.leftElbow, x: 0.0, y: 0.0, z: 0.0, likelihood: 1.0),
          PoseLandmarkType.leftWrist: PoseLandmark(type: PoseLandmarkType.leftWrist, x: 1.0, y: 0.0, z: 0.0, likelihood: 1.0),
          
          PoseLandmarkType.rightShoulder: PoseLandmark(type: PoseLandmarkType.rightShoulder, x: 1.0, y: 0.0, z: 0.0, likelihood: 1.0),
          PoseLandmarkType.rightElbow: PoseLandmark(type: PoseLandmarkType.rightElbow, x: 1.0, y: 0.5, z: 0.0, likelihood: 1.0),
          PoseLandmarkType.rightWrist: PoseLandmark(type: PoseLandmarkType.rightWrist, x: 1.0, y: 1.0, z: 0.0, likelihood: 1.0),
        },
      );

      final deltas = engine.comparePoses(livePose: mockPose, targetPose: mockTargetPose);

      expect(deltas.length, equals(2));
      final leftElbowDelta = deltas.firstWhere((d) => d.jointName == 'left_elbow');
      expect(leftElbowDelta.liveAngleDegrees.round(), equals(90));
      expect(leftElbowDelta.deltaDegrees.round(), equals(0));
      expect(leftElbowDelta.isWithinTolerance, isTrue);

      final score = engine.calculateMatchScore(deltas);
      expect(score, greaterThan(0.0));
    });
  });
}
