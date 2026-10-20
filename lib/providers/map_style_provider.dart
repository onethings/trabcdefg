import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMapType {
  liberty,
  bright, // OpenFreeMap Bright
  satellite, // Esri 衛星影像 + 道路／地名（混合，等同 Google Hybrid）
  dark,
  terrain,
  hybrid, // 同 satellite
}

class MapStyleProvider with ChangeNotifier {
  static const String _prefKey = 'preferred_map_type';

  AppMapType _mapType = AppMapType.bright;
  AppMapType get mapType => _mapType;

  // Style Strings/Assets
  static const String _streetStyle = "assets/styles/liberty.json";
  static const String _brightStyle = "assets/styles/liberty.json";
  static const String _darkStyle = "assets/styles/dark.json";
  static const String _terrainStyle = "assets/styles/fiord.json";

  /// 衛星模式採「混合」呈現：Esri 衛星影像當底圖，上面疊道路與地名
  /// （OpenMapTiles 向量圖層），效果等同 Google 混合地圖（Hybrid）。
  static const String _hybridStyle = "assets/styles/esri-hybrid.json";

  MapStyleProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final int? savedIndex = prefs.getInt(_prefKey);
    if (savedIndex != null && savedIndex < AppMapType.values.length) {
      _mapType = AppMapType.values[savedIndex];
      // Force only bright or satellite as requested by the user
      if (_mapType != AppMapType.bright && _mapType != AppMapType.satellite) {
        _mapType = AppMapType.bright;
      }
      notifyListeners();
    }
  }

  Future<void> setMapType(AppMapType type) async {
    if (_mapType == type) return;
    _mapType = type;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, type.index);
  }

  String getStyle(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;

    switch (_mapType) {
      case AppMapType.bright:
        return isDark ? _darkStyle : _brightStyle;
      case AppMapType.satellite:
      case AppMapType.hybrid:
        return _hybridStyle;
      case AppMapType.dark:
        return _darkStyle;
      case AppMapType.liberty:
        return _streetStyle;
      case AppMapType.terrain:
        return _terrainStyle;
    }
  }

  String get styleString => getStyle(Brightness.light);

  bool get isSatelliteMode => _mapType == AppMapType.satellite || _mapType == AppMapType.hybrid;

  void toggleMapType() {
    if (_mapType == AppMapType.bright) {
      setMapType(AppMapType.satellite);
    } else {
      setMapType(AppMapType.bright);
    }
  }
}
