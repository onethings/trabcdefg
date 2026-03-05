import 'package:flutter/material.dart';

class AppTheme {
  // --- Apple Style Presets ---
  
  // Obsidian Black & Graphite
  static ThemeData obsidianTheme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A1A1A),
      primary: const Color(0xFF333333),
      secondary: const Color(0xFF666666),
      surface: brightness == Brightness.dark ? const Color(0xFF121212) : Colors.white,
      brightness: brightness,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  );

  // Deep Sea Blue & Midnight
  static ThemeData deepSeaTheme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0D1B2A),
      primary: const Color(0xFF1B263B),
      secondary: const Color(0xFF415A77),
      surface: brightness == Brightness.dark ? const Color(0xFF0B132B) : const Color(0xFFE0E1DD),
      brightness: brightness,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  );

  // Mint Green & Forest Green
  static ThemeData mintTheme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD8F3DC),
      primary: const Color(0xFF52B788),
      secondary: const Color(0xFF2D6A4F),
      surface: brightness == Brightness.dark ? const Color(0xFF1B4332) : const Color(0xFFD8F3DC),
      brightness: brightness,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  );
}
