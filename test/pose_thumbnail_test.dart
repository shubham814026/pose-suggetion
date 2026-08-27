import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pose_suggestion_app/features/pose_library/data/models/target_pose.dart';
import 'package:pose_suggestion_app/features/pose_library/services/pose_library_service.dart';
import 'package:pose_suggestion_app/features/pose_library/presentation/widgets/pose_thumbnail_card.dart';
import 'package:pose_suggestion_app/features/pose_library/presentation/widgets/smart_pose_carousel.dart';
import 'package:pose_suggestion_app/features/pose_recommendation/services/pose_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPose = TargetPose(
    id: 'test_pose_01',
    name: 'Beach Sunset Pose',
    category: 'Beach & Coastal',
    description: 'Relaxed beach walk silhouette',
    difficulty: 'Easy',
    keypoints: const [
      TargetKeypoint(x: 0.5, y: 0.2, z: 0.0, visibility: 0.99),
      TargetKeypoint(x: 0.5, y: 0.4, z: 0.0, visibility: 0.99),
    ],
    targetJointAngles: const {},
    actionTags: const [
      InSituActionTag(landmarkIndex: 16, label: 'Raise Arm', arrow: '↗', bodyPart: 'right_arm'),
    ],
    silhouetteContour: const [
      [0.4, 0.2],
      [0.6, 0.2],
      [0.5, 0.8],
    ],
    embedding: List.filled(64, 0.2),
  );

  group('PoseThumbnailCard Widget Tests', () {
    testWidgets('Renders thumbnail card with title and match percentage badge', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PoseThumbnailCard(
              pose: testPose,
              isSelected: false,
              matchScore: 95,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Beach Sunset Pose'), findsOneWidget);
      expect(find.text('✨ 95%'), findsOneWidget);

      await tester.tap(find.byType(PoseThumbnailCard));
      expect(tapped, isTrue);
    });
  });

  group('SmartPoseCarousel Widget Tests', () {
    testWidgets('Renders carousel and responds to pose selection', (WidgetTester tester) async {
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
              body: SmartPoseCarousel(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(SmartPoseCarousel), findsOneWidget);
    });
  });
}
