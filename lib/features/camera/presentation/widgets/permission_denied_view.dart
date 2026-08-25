import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_theme.dart';

class PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRequestPermission;

  const PermissionDeniedView({
    super.key,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryCyan.withAlpha(76), width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: AppTheme.primaryCyan,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Camera Access Required',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'To recommend photography poses in real-time, the app requires camera access. No photo data is sent to external servers.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: onRequestPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Grant Camera Permission',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text(
                  'Open System Settings',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
