import 'package:flutter/material.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PreferencesService _prefs = PreferencesService();
  bool _voiceEnabled = true;
  Color _stencilColor = const Color(0xFF06B6D4);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final voice = await _prefs.getVoiceEnabled();
    final color = await _prefs.getStencilColor();
    if (mounted) {
      setState(() {
        _voiceEnabled = voice;
        _stencilColor = color;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D16),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Settings & AI Pipeline',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // On-device AI Specs Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryCyan.withAlpha(100)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.memory, color: AppTheme.primaryCyan, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Strictly On-Device Execution',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Model: ContextPoseNet (100 Epochs, 97.6% Tag Acc)\n'
                  '• Dataset: 12,001 Verified Poses (20+ Categories)\n'
                  '• Multi-Tier Scheduler: 30 FPS Keypoints, 2 FPS Stance, 0.5 FPS Scene\n'
                  '• Zero Cloud Dependency: 100% Privacy Protected',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Guidance Preferences
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Directional Voice Guidance', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Spoken real-time limb adjustment cues', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  value: _voiceEnabled,
                  activeThumbColor: AppTheme.primaryCyan,
                  onChanged: (val) async {
                    setState(() {
                      _voiceEnabled = val;
                    });
                    await _prefs.saveVoiceEnabled(val);
                  },
                ),
                const Divider(height: 1, color: Colors.white12),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reference HUD Accent Color', style: TextStyle(color: Colors.white, fontSize: 14)),
                            SizedBox(height: 2),
                            Text('Custom accent border tone', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _stencilColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
