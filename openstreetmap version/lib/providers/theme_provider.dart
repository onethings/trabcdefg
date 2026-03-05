import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/theme/app_theme.dart';

enum AppThemePreset { obsidian, deepSea, mint }

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _presetKey = 'theme_preset';
  
  ThemeMode _themeMode = ThemeMode.system;
  AppThemePreset _activePreset = AppThemePreset.obsidian;

  ThemeMode get themeMode => _themeMode;
  AppThemePreset get activePreset => _activePreset;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Mode
    final String? themeStr = prefs.getString(_themeKey);
    if (themeStr != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == themeStr,
        orElse: () => ThemeMode.system,
      );
    }
    
    // Load Preset
    final String? presetStr = prefs.getString(_presetKey);
    if (presetStr != null) {
      _activePreset = AppThemePreset.values.firstWhere(
        (e) => e.toString() == presetStr,
        orElse: () => AppThemePreset.obsidian,
      );
    }
    notifyListeners();
  }

  ThemeData getTheme(Brightness brightness) {
    switch (_activePreset) {
      case AppThemePreset.obsidian:
        return AppTheme.obsidianTheme(brightness);
      case AppThemePreset.deepSea:
        return AppTheme.deepSeaTheme(brightness);
      case AppThemePreset.mint:
        return AppTheme.mintTheme(brightness);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  Future<void> setPreset(AppThemePreset preset) async {
    if (_activePreset == preset) return;
    _activePreset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, preset.toString());
  }
}
