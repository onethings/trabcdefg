import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Frostier glass for surfaces that sit over the map: the backdrop is busy, so
/// the tint stays high enough for body text to stay legible in both themes.
LiquidGlassSettings mapGlassSettings(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return LiquidGlassSettings(
    blur: 24,
    frost: 0.6,
    thickness: 12,
    saturation: 1.2,
    glassColor: isDark ? const Color(0x8C1C1C1E) : const Color(0x9AFFFFFF),
    bodyMode: GlassBodyMode.clear,
    platformViewMode: PlatformViewGlassMode.fallbackColor,
    platformViewFallbackColor: isDark ? const Color(0xE61C1C1E) : const Color(0xF2FFFFFF),
  );
}
