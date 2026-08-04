import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_navigation_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PoseSuggestionApp());
}

class PoseSuggestionApp extends StatelessWidget {
  const PoseSuggestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Pose Suggestion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppNavigationShell(),
    );
  }
}
