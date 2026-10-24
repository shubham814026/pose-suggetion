import 'package:flutter_test/flutter_test.dart';
import 'package:pose_suggestion_app/features/pose_library/data/models/target_pose.dart';
import 'package:pose_suggestion_app/features/pose_recommendation/services/context_frame_scheduler.dart';
import 'package:pose_suggestion_app/features/pose_recommendation/services/pose_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TargetPose Data Model Tests', () {
    test('TargetPose serializes and deserializes action tags & silhouette correctly', () {
      final poseJson = {
        'id': 'test_pose_001',
        'name': 'Graduation Pose',
        'category': 'Graduation & Achievement',
        'description': 'Test description',
        'difficulty': 'Easy',
        'keypoints': [
          {'x': 0.5, 'y': 0.2, 'z': 0.0, 'visibility': 0.99},
          {'x': 0.52, 'y': 0.22, 'z': 0.0, 'visibility': 0.99},
        ],
        'targetJointAngles': {'elbowRight': 90.0},
        'actionTags': [
          {
            'landmarkIndex': 16,
            'label': 'Raise Right Arm',
            'arrow': '↗',
            'bodyPart': 'right_arm'
          }
        ],
        'silhouetteContour': [
          [0.4, 0.2],
          [0.6, 0.2],
          [0.5, 0.8]
        ],
        'embedding': List.filled(64, 0.1)
      };

      final pose = TargetPose.fromJson(poseJson);
      expect(pose.id, equals('test_pose_001'));
      expect(pose.actionTags.length, equals(1));
      expect(pose.actionTags.first.label, equals('Raise Right Arm'));
      expect(pose.actionTags.first.arrow, equals('↗'));
      expect(pose.silhouetteContour.length, equals(3));
      expect(pose.embedding.length, equals(64));
    });
  });

  group('PoseRecommendationService Tests', () {
    test('buildContextVector creates exact 80-d conditioning tensor', () {
      final service = PoseRecommendationService();
      final sceneVec = List.filled(64, 0.25);

      final contextVec = service.buildContextVector(
        sceneVector: sceneVec,
        propIndex: 3,
        peopleCount: 2,
        isFrontCamera: true,
      );

      expect(contextVec.length, equals(80));
      expect(contextVec[0], equals(0.25));
      expect(contextVec[64], equals(0.2)); // people_count_norm = 2 / 10.0
      expect(contextVec[66], equals(1.0)); // is_duo
      expect(contextVec[70], equals(1.0)); // is_front_camera
    });

    test('computeCosineSimilarity calculates accurate normalized dot product', () {
      final service = PoseRecommendationService();
      final vecA = [1.0, 0.0, 0.0];
      final vecB = [1.0, 0.0, 0.0];
      final vecC = [0.0, 1.0, 0.0];

      expect(service.computeCosineSimilarity(vecA, vecB), closeTo(1.0, 0.001));
      expect(service.computeCosineSimilarity(vecA, vecC), closeTo(0.0, 0.001));
    });

    test('calculateDynamicMatchPercentage computes mathematically-grounded scores', () {
      final service = PoseRecommendationService();
      final sceneVec = List.filled(64, 0.3);
      final testPose = TargetPose(
        id: 'pose_solo_test',
        name: 'Solo Sunset Stride',
        category: 'Aesthetic & Sunset',
        description: 'Test',
        difficulty: 'Easy',
        keypoints: [],
        targetJointAngles: {},
        actionTags: [],
        silhouetteContour: [],
        embedding: List.filled(64, 0.3),
      );

      // 0 people -> Empty Scene Staging score (capped realistically, never 99%)
      final scoreEmpty = service.calculateDynamicMatchPercentage(
        sceneVector: sceneVec,
        pose: testPose,
        peopleCount: 0,
        detectedStance: StanceType.standing,
      );
      expect(scoreEmpty, inInclusiveRange(60.0, 84.0));

      // 1 person -> Solo match score
      final scoreSolo = service.calculateDynamicMatchPercentage(
        sceneVector: sceneVec,
        pose: testPose,
        peopleCount: 1,
        detectedStance: StanceType.standing,
      );
      expect(scoreSolo, inInclusiveRange(74.0, 96.0));
      expect(scoreSolo, greaterThan(scoreEmpty));
    });

    test('runNeuralRecommendationInference zero-person gate returns empty', () {
      final service = PoseRecommendationService();
      final result = service.runNeuralRecommendationInference(
        contextVector: List.filled(80, 0.0),
        candidatePoses: [
          TargetPose(
            id: 'p1',
            name: 'Pose 1',
            category: 'Standing & Streetwear',
            description: '',
            difficulty: 'Easy',
            keypoints: const [],
            targetJointAngles: const {},
            actionTags: const [],
            silhouetteContour: const [],
            embedding: List.filled(64, 0.5),
          ),
        ],
        peopleCount: 0,
      );

      expect(result.recommendedPoses.isEmpty, isTrue);
      expect(result.predictedCategory, equals('No Person Detected'));
    });

    test('buildContextVector sets selfie composition and lens mode', () {
      final service = PoseRecommendationService();
      final ctx = service.buildContextVector(
        sceneVector: List.filled(64, 0.1),
        peopleCount: 1,
        isFrontCamera: true,
        isSelfieComposition: true,
        shoulderWidthNorm: 0.35,
        isSitting: false,
        isStanding: false,
        isLegsVisible: false,
      );

      expect(ctx[64], equals(0.1)); // people_count_norm
      expect(ctx[65], equals(1.0)); // is_solo
      expect(ctx[70], equals(1.0)); // is_front_camera
      expect(ctx[71], equals(1.0)); // is_selfie_composition
      expect(ctx[72], equals(0.35)); // shoulder_width_norm
      expect(ctx[76], equals(0.0)); // is_legs_visible = false
    });
  });
}

