import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pose_suggestion_app/features/camera/presentation/camera_screen.dart';
import 'package:pose_suggestion_app/features/pose_library/data/models/target_pose.dart';
import 'package:pose_suggestion_app/features/pose_library/presentation/widgets/pose_image_view.dart';
import 'package:pose_suggestion_app/features/pose_library/presentation/widgets/smart_pose_carousel.dart';
import 'package:pose_suggestion_app/features/pose_library/presentation/widgets/target_pose_stencil_painter.dart';
import 'package:pose_suggestion_app/features/pose_library/services/pose_library_service.dart';
import 'package:pose_suggestion_app/features/pose_recommendation/services/pose_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CameraScreen renders SmartPoseCarousel and floating Reference Guide without camera stencils', (tester) async {
    final poseLibrary = PoseLibraryService();
    final recommender = PoseRecommendationService();

    final testPose = TargetPose(
      id: 'test_pose_rec_1',
      name: 'Model Fashion Pose',
      category: 'Solo Female Fashion',
      description: 'Test posture',
      difficulty: 'Easy',
      keypoints: List.generate(
        33,
        (i) => TargetKeypoint(x: 0.5, y: 0.1 + (i / 40.0), z: 0.0, visibility: 0.99),
      ),
      targetJointAngles: {},
      actionTags: [
        const InSituActionTag(landmarkIndex: 16, label: 'Raise Hand', arrow: '↗', bodyPart: 'arm'),
      ],
      silhouetteContour: [
        [0.4, 0.2],
        [0.6, 0.2],
        [0.5, 0.8],
      ],
      embedding: List.filled(64, 0.2),
    );

    poseLibrary.setCustomActivePose(testPose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: poseLibrary),
          Provider.value(value: recommender),
        ],
        child: const MaterialApp(
          home: CameraScreen(isPermissionGrantedForTesting: true),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify SmartPoseCarousel is present on the Camera screen
    expect(find.byType(SmartPoseCarousel), findsOneWidget);

    // Verify NO TargetPoseStencilPainter is rendered over the camera viewfinder (User requirement: no stencil)
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is TargetPoseStencilPainter,
      ),
      findsNothing,
    );

    // Verify PoseImageView is rendered (in the floating Reference Guide card and carousel)
    expect(find.byType(PoseImageView), findsWidgets);

    // Verify active pose name is displayed
    expect(find.text('Ref: Model Fashion Pose'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });
}
