import 'package:flutter/material.dart';
import 'package:trabcdefg/storage/settings_database_helper.dart';

class SettingsProvider with ChangeNotifier {
  static const String _fontSizeKey = 'font_size_scale';
  static const String _markerSizeKey = 'marker_size_scale';
  static const String _simpleModeKey = 'simple_mode';
  static const String _simpleModePrevFontKey = 'simple_mode_prev_font_scale';
  static const String _simpleModePrevMarkerKey = 'simple_mode_prev_marker_scale';

  // 簡易模式搭配的字級與圖標預設，值與設定頁的大級選項一致。
  static const double simpleModeFontScale = 1.4;
  static const double simpleModeMarkerScale = 2.0;

  double _fontSizeScale = 1.0;
  double _markerSizeScale = 1.0;
  bool _simpleMode = false;

  double get fontSizeScale => _fontSizeScale;
  double get markerSizeScale => _markerSizeScale;
  bool get simpleMode => _simpleMode;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final fontScale = await SettingsDatabaseHelper.getSetting(_fontSizeKey);
    final markerScale = await SettingsDatabaseHelper.getSetting(_markerSizeKey);
    final simpleMode = await SettingsDatabaseHelper.getFlag(_simpleModeKey);

    if (fontScale != null) _fontSizeScale = fontScale;
    if (markerScale != null) _markerSizeScale = markerScale;
    if (simpleMode != null) _simpleMode = simpleMode;

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

  Future<void> setSimpleMode(bool enabled) async {
    if (_simpleMode == enabled) return;
    _simpleMode = enabled;
    if (enabled) {
      // 先記住使用者原本的字級與圖標大小，關閉時原樣還原。
      await SettingsDatabaseHelper.saveSetting(_simpleModePrevFontKey, _fontSizeScale);
      await SettingsDatabaseHelper.saveSetting(_simpleModePrevMarkerKey, _markerSizeScale);
      _fontSizeScale = simpleModeFontScale;
      _markerSizeScale = simpleModeMarkerScale;
    } else {
      final prevFont = await SettingsDatabaseHelper.getSetting(_simpleModePrevFontKey);
      final prevMarker = await SettingsDatabaseHelper.getSetting(_simpleModePrevMarkerKey);
      _fontSizeScale = prevFont ?? 1.0;
      _markerSizeScale = prevMarker ?? 1.0;
    }
    notifyListeners();
    await SettingsDatabaseHelper.saveFlag(_simpleModeKey, _simpleMode);
    await SettingsDatabaseHelper.saveSetting(_fontSizeKey, _fontSizeScale);
    await SettingsDatabaseHelper.saveSetting(_markerSizeKey, _markerSizeScale);
  }
}
