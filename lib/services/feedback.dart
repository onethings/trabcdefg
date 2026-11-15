// lib/services/feedback.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Single entry point for user-facing feedback so every screen speaks the
/// same visual language.
class FeedbackService {
  /// Fallback messenger for call sites without a BuildContext (providers).
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static const double _kCupertinoTabBarHeight = 50;

  static EdgeInsets _marginFor(BuildContext? context) {
    final BuildContext? ctx = context ?? messengerKey.currentContext;
    final double safe = (ctx != null ? MediaQuery.maybeOf(ctx) : null)?.padding.bottom ?? 0;
    final bool insideTabs = ctx != null && ctx.findAncestorWidgetOfExactType<CupertinoTabScaffold>() != null;
    return EdgeInsets.fromLTRB(16, 0, 16, safe + (insideTabs ? _kCupertinoTabBarHeight : 0) + 8);
  }

  static void success(String message, {BuildContext? context}) => _show(context, message, Icons.check_circle_rounded, const Color(0xFF34C759));

  static void error(String message, {BuildContext? context}) => _show(context, message, Icons.error_outline_rounded, const Color(0xFFFF3B30));

  static void info(String message, {BuildContext? context}) => _show(context, message, Icons.info_outline_rounded, Colors.white70);

  static void _show(BuildContext? context, String message, IconData icon, Color accent) {
    final state = (context != null ? ScaffoldMessenger.maybeOf(context) : null) ?? messengerKey.currentState;
    if (state == null) return;

    state.hideCurrentSnackBar();
    state.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: _marginFor(context),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
