import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/camera/presentation/camera_screen.dart';
import '../features/pose_library/presentation/pose_library_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({super.key});

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const CameraScreen(),
      PoseLibraryScreen(
        onSelectPose: (_) {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt, color: AppTheme.primaryCyan),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view, color: AppTheme.primaryCyan),
            label: 'Pose Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings, color: AppTheme.primaryCyan),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
