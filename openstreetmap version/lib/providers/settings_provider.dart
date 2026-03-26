import 'package:flutter/material.dart';
import 'package:trabcdefg/storage/settings_database_helper.dart';

class SettingsProvider with ChangeNotifier {
  static const String _fontSizeKey = 'font_size_scale';
  static const String _markerSizeKey = 'marker_size_scale';

  double _fontSizeScale = 1.0;
  double _markerSizeScale = 1.0;

  double get fontSizeScale => _fontSizeScale;
  double get markerSizeScale => _markerSizeScale;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final fontScale = await SettingsDatabaseHelper.getSetting(_fontSizeKey);
    final markerScale = await SettingsDatabaseHelper.getSetting(_markerSizeKey);
    
    if (fontScale != null) _fontSizeScale = fontScale;
    if (markerScale != null) _markerSizeScale = markerScale;
    
    notifyListeners();
  }

  Future<void> setFontSizeScale(double scale) async {
    if (_fontSizeScale == scale) return;
    _fontSizeScale = scale;
    notifyListeners();
    await SettingsDatabaseHelper.saveSetting(_fontSizeKey, scale);
  }

  Future<void> setMarkerSizeScale(double scale) async {
    if (_markerSizeScale == scale) return;
    _markerSizeScale = scale;
    notifyListeners();
    await SettingsDatabaseHelper.saveSetting(_markerSizeKey, scale);
  }
}
