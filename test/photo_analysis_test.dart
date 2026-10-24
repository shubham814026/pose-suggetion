import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pose_suggestion_app/features/photo_analysis/models/photo_analysis_result.dart';
import 'package:pose_suggestion_app/features/photo_analysis/presentation/photo_analysis_screen.dart';
import 'package:pose_suggestion_app/features/pose_library/data/models/target_pose.dart';
import 'package:pose_suggestion_app/features/pose_library/presentation/widgets/smart_pose_carousel.dart';
import 'package:pose_suggestion_app/features/pose_library/services/pose_library_service.dart';
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
      expect(contextVec[64], equals(0.2)); // people_count_norm (2 / 10.0)
      expect(contextVec[66], equals(1.0)); // is_duo
      expect(contextVec[70], equals(0.0)); // back camera
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

    test('Zero-person gate: 0 people returns empty recommendations and No Person Detected', () {
      final ctx = recommender.buildContextVector(
        sceneVector: List.filled(64, 0.1),
        propIndex: 4,
        peopleCount: 0,
      );
      // No people grouping tokens active in 65..69
      expect(ctx[64], equals(0.0));
      expect(ctx[65], equals(0.0));
      expect(ctx[66], equals(0.0));
      expect(ctx[67], equals(0.0));
      expect(ctx[68], equals(0.0));
      expect(ctx[69], equals(0.0));

      final testPoses = [
        TargetPose(
          id: 'p1',
          name: 'Solo Streetwear',
          category: 'Standing & Streetwear',
          description: '',
          difficulty: 'Easy',
          keypoints: [],
          targetJointAngles: {},
          actionTags: [],
          silhouetteContour: [],
          embedding: List.filled(64, 0.1),
        ),
      ];

      final res = recommender.runNeuralRecommendationInference(
        contextVector: ctx,
        candidatePoses: testPoses,
        peopleCount: 0,
      );

      expect(res.recommendedPoses.isEmpty, isTrue);
      expect(res.predictedCategory, equals('No Person Detected'));
      expect(recommender.filterPosesByPeopleCount(testPoses, 0).isEmpty, isTrue);
    });

    test('Multi-person tier filtering distinguishes 1, 2, 3, 5, 10 people accurately', () {
      final poses = [
        TargetPose(
          id: 'solo_1',
          name: 'Solo Fashion',
          category: 'Solo Female Fashion',
          description: '',
          difficulty: 'Easy',
          keypoints: [],
          targetJointAngles: {},
          actionTags: [],
          silhouetteContour: [],
          embedding: List.filled(64, 0.1),
        ),
        TargetPose(
          id: 'duo_1',
          name: 'Romantic Sunset Walk',
          category: 'Couple & Duo Poses',
          description: '',
          difficulty: 'Easy',
          keypoints: [],
          targetJointAngles: {},
          actionTags: [],
          silhouetteContour: [],
          embedding: List.filled(64, 0.1),
        ),
        TargetPose(
          id: 'trio_1',
          name: 'Three Friends Sitting',
          category: 'Trio (3 People) Poses',
          description: '',
          difficulty: 'Easy',
          keypoints: [],
          targetJointAngles: {},
          actionTags: [],
          silhouetteContour: [],
          embedding: List.filled(64, 0.1),
        ),
        TargetPose(
          id: 'group_4_6',
          name: 'Squad Goals 5 People',
          category: 'Small Groups (4 to 6 People)',
          description: '',
          difficulty: 'Easy',
          keypoints: [],
          targetJointAngles: {},
          actionTags: [],
          silhouetteContour: [],
          embedding: List.filled(64, 0.1),
        ),
        TargetPose(
          id: 'group_7_plus',
          name: 'Big Family Reunion 10 People',
          category: 'Large Groups & Family (7+ People)',
          description: '',
          difficulty: 'Easy',
          keypoints: [],
          targetJointAngles: {},
          actionTags: [],
          silhouetteContour: [],
          embedding: List.filled(64, 0.1),
        ),
      ];

      // 1 Person: Solo only
      final solo = recommender.filterPosesByPeopleCount(poses, 1);
      expect(solo.length, equals(1));
      expect(solo.first.id, equals('solo_1'));

      // 2 People: Duo / Couple
      final duo = recommender.filterPosesByPeopleCount(poses, 2);
      expect(duo.length, equals(1));
      expect(duo.first.id, equals('duo_1'));

      // 3 People: Trio
      final trio = recommender.filterPosesByPeopleCount(poses, 3);
      expect(trio.length, equals(1));
      expect(trio.first.id, equals('trio_1'));

      // 5 People: Small Group
      final group5 = recommender.filterPosesByPeopleCount(poses, 5);
      expect(group5.length, equals(1));
      expect(group5.first.id, equals('group_4_6'));

      // 10 People: Large Group & Family
      final group10 = recommender.filterPosesByPeopleCount(poses, 10);
      expect(group10.length, equals(1));
      expect(group10.first.id, equals('group_7_plus'));
    });

    testWidgets('PhotoAnalysisScreen shows No Person Detected empty state when 0 people in photo', (tester) async {
      final analysis = PhotoAnalysisResult(
        imagePath: '/tmp/test_empty.jpg',
        lightingType: LightingType.daylight,
        lightingName: 'Natural Daylight',
        lightingEmoji: '☀️',
        sceneType: SceneType.indoorLiving,
        sceneName: 'Home, Cozy & Balcony',
        sceneEmoji: '🏡',
        peopleCount: 0,
        stanceType: StanceType.unknown,
        occasionVibe: 'Empty Scene (No Person Detected)',
        detectedPoses: const [],
        contextVector: List.filled(80, 0.0),
        sceneVector: List.filled(64, 0.0),
        aiSynthesizedPose: null,
        recommendedPoses: const [],
        averageLuminance: 120.0,
        colorTemperatureK: 5500.0,
      );

      final poseLibrary = PoseLibraryService();
      final recommender = PoseRecommendationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: poseLibrary),
            Provider.value(value: recommender),
          ],
          child: MaterialApp(
            home: PhotoAnalysisScreen(analysis: analysis),
          ),
        ),
      );

      await tester.pump();

      // Verify "No Person Detected in Photo" message
      expect(find.text('No Person Detected in Photo'), findsOneWidget);
      expect(find.text('Retake Photo'), findsOneWidget);
      // Verify no pose suggestion cards are rendered
      expect(find.text('3 Suggested Photos (Will Look Better)'), findsNothing);
      expect(find.text('Use as Reference Guide'), findsNothing);
    });

    testWidgets('SmartPoseCarousel shows No Person in View banner when peopleCount is 0', (tester) async {
      final poseLibrary = PoseLibraryService();
      final recommender = PoseRecommendationService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: poseLibrary),
            Provider.value(value: recommender),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SmartPoseCarousel(peopleCount: 0),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No Person Detected'), findsOneWidget);
      expect(find.text('No Person in View • Point camera at people'), findsOneWidget);
      expect(find.text('12k Poses'), findsOneWidget);
      // Verify no target pose was auto-selected
      expect(poseLibrary.activeTargetPose, isNull);
    });
  });
}
