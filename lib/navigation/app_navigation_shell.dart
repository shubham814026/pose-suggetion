import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/camera/presentation/camera_screen.dart';
import '../features/pose_library/models/target_pose.dart';
import '../features/pose_library/presentation/pose_library_screen.dart';
import '../features/pose_library/services/pose_library_service.dart';
import '../features/settings/presentation/settings_screen.dart';

class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({super.key});

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  int _currentIndex = 0;
  TargetPose? _selectedTargetPose;
  final PoseLibraryService _poseLibraryService = PoseLibraryService();

  @override
  void initState() {
    super.initState();
    _initDefaultPose();
  }

  Future<void> _initDefaultPose() async {
    final poses = await _poseLibraryService.loadTargetPoses();
    if (poses.isNotEmpty && mounted) {
      setState(() {
        _selectedTargetPose = poses.first;
      });
    }
  }

  void _onPoseSelected(TargetPose pose) {
    setState(() {
      _selectedTargetPose = pose;
      _currentIndex = 0; // Switch to camera screen after selecting pose
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CameraScreen(
        selectedTargetPose: _selectedTargetPose,
        onSelectPose: _onPoseSelected,
      ),
      PoseLibraryScreen(
        selectedPose: _selectedTargetPose,
        onSelectPose: _onPoseSelected,
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
            label: 'Camera Shell',
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
