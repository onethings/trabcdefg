import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  // --- iOS 系統色（官方 HIG 色票）---
  static const Color _iosBlue = Color(0xFF007AFF);

  /// 套用「iOS 風格」的全域設定（頁面轉場、系統色、扁平化細節）。
  /// 保留各 preset 的主色調，僅加上 iOS 的視覺行為，不影響主題切換。
  static ThemeData _iosify(ThemeData theme, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    // Separators（iOS 分隔線：亮色 #000 @12% / 暗色 #FFF @12%）
    final Color separator = isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000);
    return theme.copyWith(
      // iOS 頁面轉場：由右滑入 + 支援邊緣返回手勢（全平台一致）
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      // iOS 系統藍：文字游標 / 選取 / 選取把手
      textSelectionTheme: const TextSelectionThemeData(cursorColor: _iosBlue, selectionColor: Color(0x33007AFF), selectionHandleColor: _iosBlue),
      // iOS 不使用 Material 墨水漣漪
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      // 細、淡的 iOS 分隔線
      dividerTheme: DividerThemeData(color: separator, thickness: 0.5, space: 0),
    );
  }

  // --- iOS 原生風格主題（官方 HIG 系統色票）---
  static ThemeData iosTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    // Backgrounds（背景）
    final Color bgGrouped = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7); // Grouped Primary
    final Color bgBase = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF); // Base Primary
    // Elevated surfaces
    final Color surfaceElevated = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    // Labels（標籤）
    final Color labelPrimary = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    // Grays（灰階）
    final Color gray3 = isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC);
    final Color gray5 = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final Color gray6 = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    // System Colors（系統色）
    final Color systemBlue = isDark ? const Color(0xFF0091FF) : const Color(0xFF0088FF);
    final Color systemGreen = isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);
    final Color systemRed = isDark ? const Color(0xFFFF4245) : const Color(0xFFFF383C);
    final Color systemIndigo = isDark ? const Color(0xFF6D7CFF) : const Color(0xFF6155F5);

    return _iosify(
      ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: brightness,
          primary: systemBlue,
          onPrimary: Colors.white,
          secondary: systemIndigo,
          onSecondary: Colors.white,
          tertiary: systemGreen,
          onTertiary: Colors.white,
          error: systemRed,
          onError: Colors.white,
          surface: bgBase,
          onSurface: labelPrimary,
          surfaceContainerHighest: gray6,
          surfaceContainerHigh: gray5,
          outline: gray3,
          outlineVariant: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFC6C6C8),
          primaryContainer: systemBlue.withValues(alpha: 0.2),
          onPrimaryContainer: systemBlue,
          secondaryContainer: systemIndigo.withValues(alpha: 0.2),
          onSecondaryContainer: systemIndigo,
          errorContainer: systemRed.withValues(alpha: 0.2),
          onErrorContainer: systemRed,
        ),
        scaffoldBackgroundColor: bgGrouped,
        appBarTheme: AppBarTheme(centerTitle: true, elevation: 0, scrolledUnderElevation: 0, backgroundColor: bgGrouped, foregroundColor: labelPrimary, surfaceTintColor: Colors.transparent),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: systemBlue,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isDark ? const Color(0xFF3A3A3C) : const Color(0xFF2C2C2E),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        // SF Pro 字體階層（iOS HIG 字型階層）
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700), // LargeTitle
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700), // Title1
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700), // Title2
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700), // Title2 (AppBar)
          titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600), // Title3
          titleSmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w600), // Headline
          bodyLarge: TextStyle(fontSize: 17), // Body
          bodyMedium: TextStyle(fontSize: 16), // Callout
          bodySmall: TextStyle(fontSize: 13), // Footnote
          labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600), // Button
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500), // Caption1
          labelSmall: TextStyle(fontSize: 11), // Caption2
        ),
        // iOS Toggle（Controls：綠色軌道、白色圓鈕）
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? systemGreen : gray3),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.transparent : gray3),
        ),
      ),
      brightness,
    );
  }

  // --- Apple Style Presets ---

  // Obsidian Black & Graphite
  static ThemeData obsidianTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    return _iosify(
      ThemeData(
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
          style: ElevatedButton.styleFrom(foregroundColor: isDark ? Colors.black : Colors.white, backgroundColor: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333)),
        ),
        unselectedWidgetColor: isDark ? Colors.grey[600] : Colors.grey[400],
      ),
      brightness,
    );
  }

  // Deep Sea Blue & Midnight
  static ThemeData deepSeaTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    return _iosify(
      ThemeData(
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
          style: ElevatedButton.styleFrom(foregroundColor: isDark ? const Color(0xFF0B132B) : Colors.white, backgroundColor: isDark ? const Color(0xFF8ECAFE) : const Color(0xFF1B263B)),
        ),
        unselectedWidgetColor: isDark ? Colors.white38 : Colors.black38,
      ),
      brightness,
    );
  }

  // Mint Green & Forest Green
  static ThemeData mintTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    return _iosify(
      ThemeData(
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
          style: ElevatedButton.styleFrom(foregroundColor: isDark ? const Color(0xFF1B4332) : Colors.white, backgroundColor: isDark ? const Color(0xFF95D5B2) : const Color(0xFF52B788)),
        ),
        unselectedWidgetColor: isDark ? Colors.white30 : Colors.black38,
      ),
      brightness,
    );
  }
}
