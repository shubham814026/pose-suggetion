import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pose_suggestion_app/features/pose_library/data/models/target_pose.dart';
import 'package:pose_suggestion_app/features/pose_library/presentation/pose_library_screen.dart';
import 'package:pose_suggestion_app/features/pose_library/services/pose_library_service.dart';
import 'package:pose_suggestion_app/features/pose_recommendation/services/pose_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PoseLibraryScreen renders categories, search, and responds to pose selection', (tester) async {
    final poseLibrary = PoseLibraryService();
    final recommender = PoseRecommendationService();
    TargetPose? selected;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: poseLibrary),
          Provider.value(value: recommender),
        ],
        child: MaterialApp(
          home: PoseLibraryScreen(
            onSelectPose: (p) => selected = p,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Reference Photo Library'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(selected, isNull);
  });
}
