import 'package:flutter/material.dart';

class AppTheme {
  // --- Apple Style Presets ---
  
  // Obsidian Black & Graphite
  static ThemeData obsidianTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A1A1A),
        primary: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: isDark ? const Color(0xFFBBBBBB) : const Color(0xFF666666),
        surface: isDark ? const Color(0xFF121212) : Colors.white,
        onSurface: isDark ? Colors.white : Colors.black,
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: isDark ? Colors.black : Colors.white,
          backgroundColor: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
        ),
      ),
      unselectedWidgetColor: isDark ? Colors.grey[600] : Colors.grey[400],
    );
  }

  // Deep Sea Blue & Midnight
  static ThemeData deepSeaTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0D1B2A),
        primary: isDark ? const Color(0xFF8ECAFE) : const Color(0xFF1B263B),
        onPrimary: isDark ? const Color(0xFF0D1B2A) : Colors.white,
        secondary: isDark ? const Color(0xFFA9D6E5) : const Color(0xFF415A77),
        surface: isDark ? const Color(0xFF0B132B) : const Color(0xFFE0E1DD),
        onSurface: isDark ? Colors.white : const Color(0xFF1B263B),
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFF0B132B) : Colors.white,
          backgroundColor: isDark ? const Color(0xFF8ECAFE) : const Color(0xFF1B263B),
        ),
      ),
      unselectedWidgetColor: isDark ? Colors.white38 : Colors.black38,
    );
  }

  // Mint Green & Forest Green
  static ThemeData mintTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD8F3DC),
        primary: isDark ? const Color(0xFF95D5B2) : const Color(0xFF52B788),
        onPrimary: isDark ? const Color(0xFF1B4332) : Colors.white,
        secondary: isDark ? const Color(0xFFD8F3DC) : const Color(0xFF2D6A4F),
        surface: isDark ? const Color(0xFF1B4332) : const Color(0xFFD8F3DC),
        onSurface: isDark ? Colors.white : const Color(0xFF1B4332),
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFF1B4332) : Colors.white,
          backgroundColor: isDark ? const Color(0xFF95D5B2) : const Color(0xFF52B788),
        ),
      ),
      unselectedWidgetColor: isDark ? Colors.white30 : Colors.black38,
    );
  }
}
