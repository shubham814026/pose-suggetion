import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/camera/presentation/camera_screen.dart';

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
      const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view_outlined, size: 64, color: AppTheme.accentViolet),
            SizedBox(height: 16),
            Text(
              'Pose Library Baseline (Phase 3 Ready)',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_outlined, size: 64, color: AppTheme.successGreen),
            SizedBox(height: 16),
            Text(
              'Settings Shell',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
