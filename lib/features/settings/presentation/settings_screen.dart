import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Settings & Help'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'PREFERENCES',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Card(
              child: SwitchListTile(
                value: true,
                onChanged: (val) {},
                title: const Text(
                  'Voice Suggestions (TTS)',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
                subtitle: const Text(
                  'Spoken positioning feedback during capture',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                activeColor: AppTheme.primaryCyan,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                value: true,
                onChanged: (val) {},
                title: const Text(
                  'Target Pose Stencil Overlay',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
                subtitle: const Text(
                  'Render target pose skeleton over live camera preview',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                activeColor: AppTheme.primaryCyan,
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'SYSTEM & PRIVACY',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.shield_outlined, color: AppTheme.successGreen),
                title: Text(
                  '100% On-Device AI',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  'All pose matching and camera processing runs locally. Zero cloud data transfer.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
