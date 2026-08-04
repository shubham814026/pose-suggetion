import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String keyStencilColor = 'stencil_color_hex';
  static const String keyVoiceEnabled = 'voice_guidance_enabled';

  static const String defaultColorHex = '0xFF06B6D4'; // Cyan

  /// Save stencil outline color choice to SharedPreferences
  Future<void> saveStencilColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final hexString = '0x${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    await prefs.setString(keyStencilColor, hexString);
  }

  /// Get persisted stencil outline color
  Future<Color> getStencilColor() async {
    final prefs = await SharedPreferences.getInstance();
    final hexString = prefs.getString(keyStencilColor) ?? defaultColorHex;
    try {
      final value = int.parse(hexString);
      return Color(value);
    } catch (_) {
      return const Color(0xFF06B6D4);
    }
  }

  /// Save voice guidance preference
  Future<void> saveVoiceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyVoiceEnabled, enabled);
  }

  /// Get voice guidance preference (default true)
  Future<bool> getVoiceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyVoiceEnabled) ?? true;
  }
}
