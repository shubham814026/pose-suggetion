import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_suggestion_app/features/photo_analysis/models/photo_analysis_result.dart';
import 'package:pose_suggestion_app/features/pose_library/data/models/target_pose.dart';
import 'package:pose_suggestion_app/features/pose_library/utils/silhouette_contour_generator.dart';
import 'package:pose_suggestion_app/features/pose_recommendation/services/context_frame_scheduler.dart';
import 'package:pose_suggestion_app/features/pose_recommendation/services/pose_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoContextAnalyzer Multi-Modal & Dynamic AI Tests', () {
    late PoseRecommendationService recommender;

    setUp(() {
      recommender = PoseRecommendationService();
    });

    test('buildContextVector produces valid 80-d tensor with one-hot encodings', () {
      final sceneVec = List<double>.filled(64, 0.15);
      final contextVec = recommender.buildContextVector(
        sceneVector: sceneVec,
        propIndex: 1,
        peopleCount: 2,
        isFrontCamera: false,
      );

      expect(contextVec.length, equals(80));
      expect(contextVec[64 + 1], equals(1.0)); // propIndex=1
      expect(contextVec[74 + 1], equals(1.0)); // peopleCount=2 -> index 1
      expect(contextVec[79], equals(0.0)); // back camera
    });

    test('getTopRecommendations respects peopleCount filter and returns topK items', () {
      final poses = [
        TargetPose(
          id: 'pose_solo_1',
          name: 'Beach Sunset Solo',
          category: 'Aesthetic & Sunset',
          description: 'Solo pose',
          difficulty: 'Easy',
          keypoints: [],
          targetJointAngles: {},
          actionTags: [],
          silhouetteContour: [],
          embedding: List.filled(64, 0.5),
        ),
        TargetPose(
          id: 'pose_couple_1',
          name: 'Couple Romantic Embrace',
          category: 'Couples & Duo',
          description: 'Couple pose',
          difficulty: 'Medium',
          keypoints: [],
          targetJointAngles: {},
          actionTags: [],
          silhouetteContour: [],
          embedding: List.filled(64, 0.5),
        ),
        TargetPose(
          id: 'pose_group_1',
          name: 'Group Celebration',
          category: 'Group & Family',
          description: 'Group pose',
          difficulty: 'Easy',
          keypoints: [],
          targetJointAngles: {},
          actionTags: [],
          silhouetteContour: [],
          embedding: List.filled(64, 0.5),
        ),
      ];

      final sceneVec = List<double>.filled(64, 0.5);

      // Solo test: peopleCount = 1
      final soloRecs = recommender.getTopRecommendations(
        allPoses: poses,
        sceneVector: sceneVec,
        peopleCount: 1,
        isSitting: false,
        topK: 5,
      );
      expect(soloRecs.any((p) => p.id == 'pose_couple_1'), isFalse);
      expect(soloRecs.any((p) => p.id == 'pose_group_1'), isFalse);
      expect(soloRecs.first.id, equals('pose_solo_1'));

      // Couple test: peopleCount = 2
      final coupleRecs = recommender.getTopRecommendations(
        allPoses: poses,
        sceneVector: sceneVec,
        peopleCount: 2,
        isSitting: false,
        topK: 5,
      );
      expect(coupleRecs.first.id, equals('pose_couple_1'));
    });

    test('SilhouetteContourGenerator generates valid dynamic body path from keypoints', () {
      final keypoints = List.generate(
        33,
        (i) => TargetKeypoint(x: 0.5, y: (i / 33.0), z: 0.0, visibility: 0.99),
      );

      final path = SilhouetteContourGenerator.generateDynamicBodyPath(
        keypoints: keypoints,
        canvasSize: const Size(300, 600),
        isFrontCamera: false,
      );

      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0.0));
      expect(bounds.height, greaterThan(0.0));
    });

    test('PhotoAnalysisResult data model contains correct multi-modal properties', () {
      final result = PhotoAnalysisResult(
        imagePath: '/path/to/sunset.jpg',
        lightingType: LightingType.goldenHourSunset,
        lightingName: 'Golden Hour / Sunset',
        lightingEmoji: '🌅',
        sceneType: SceneType.beach,
        sceneName: 'Beach & Coastal',
        sceneEmoji: '🏖️',
        peopleCount: 0,
        stanceType: StanceType.standing,
        occasionVibe: 'Empty Sunset Scene (Ready for Subject)',
        detectedPoses: [],
        contextVector: List.filled(80, 0.1),
        sceneVector: List.filled(64, 0.1),
        recommendedPoses: [],
        averageLuminance: 120.0,
        colorTemperatureK: 3500.0,
      );

      expect(result.lightingType, equals(LightingType.goldenHourSunset));
      expect(result.sceneType, equals(SceneType.beach));
      expect(result.lightingEmoji, equals('🌅'));
      expect(result.peopleCount, equals(0));
      expect(result.occasionVibe, contains('Empty'));
    });

    test('generateDynamicPoseRecommendations produces 5 non-null target poses', () {
      final ctx = List<double>.filled(80, 0.1);
      final poses = recommender.generateDynamicPoseRecommendations(
        baseContextVector: ctx,
        sceneName: 'Beach',
        lightingName: 'Golden Hour',
        peopleCount: 1,
        count: 5,
      );

      expect(poses.length, equals(5));
      for (final p in poses) {
        expect(p.keypoints.length, equals(33));
        expect(p.name.isNotEmpty, isTrue);
      }
    });
  });
}
