import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/pose_library/services/pose_library_service.dart';
import 'features/pose_recommendation/services/context_frame_scheduler.dart';
import 'features/pose_recommendation/services/pose_recommendation_service.dart';
import 'navigation/app_navigation_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PoseSuggestionApp());
}

class PoseSuggestionApp extends StatelessWidget {
  const PoseSuggestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PoseLibraryService()..loadPoseLibrary(),
        ),
        Provider(
          create: (_) => PoseRecommendationService()..initialize(),
        ),
        ChangeNotifierProxyProvider<PoseRecommendationService, ContextFrameScheduler>(
          create: (context) => ContextFrameScheduler(
            recommender: Provider.of<PoseRecommendationService>(context, listen: false),
          ),
          update: (_, recommender, scheduler) =>
              scheduler ?? ContextFrameScheduler(recommender: recommender),
        ),
      ],
      child: MaterialApp(
        title: 'AI Pose Suggestion',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppNavigationShell(),
      ),
    );
  }
}
