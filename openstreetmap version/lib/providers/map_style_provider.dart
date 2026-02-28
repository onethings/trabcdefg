import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMapType {
  liberty,
  bright, // OpenFreeMap Bright
  satellite, // ArcGIS Satellite
  dark,
  terrain,
  hybrid,
}

class MapStyleProvider with ChangeNotifier {
  static const String _prefKey = 'preferred_map_type';
  
  AppMapType _mapType = AppMapType.bright;
  AppMapType get mapType => _mapType;

  // Style Strings/Assets
  static const String _streetStyle = "assets/styles/liberty.json";
  static const String _brightStyle = "assets/styles/aws-standard.json";
  static const String _darkStyle = "assets/styles/dark.json";
  static const String _terrainStyle = "assets/styles/fiord.json";
  static const String _hybridStyle = "assets/styles/positron.json";
  static const String _satelliteStyle = "assets/styles/aws-hybrid.json";

  MapStyleProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final int? savedIndex = prefs.getInt(_prefKey);
    if (savedIndex != null && savedIndex < AppMapType.values.length) {
      _mapType = AppMapType.values[savedIndex];
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

  String get styleString {
    switch (_mapType) {
      case AppMapType.liberty:
        return _streetStyle;
      case AppMapType.bright:
        return _brightStyle;
      case AppMapType.dark:
        return _darkStyle;
      case AppMapType.terrain:
        return _terrainStyle;
      case AppMapType.satellite:
        return _satelliteStyle;
      case AppMapType.hybrid:
        return _hybridStyle;
    }
  }

  bool get isSatelliteMode => _mapType == AppMapType.satellite;

  void toggleMapType() {
    if (_mapType == AppMapType.bright) {
      setMapType(AppMapType.satellite);
    } else {
      setMapType(AppMapType.bright);
    }
  }
}
