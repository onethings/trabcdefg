import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/settings_provider.dart';

/// 簡易模式開啟時隱藏進階控制項。
///
/// 元件名稱就是規則：包起來的元件只會在正常模式出現。用在 build 內。
class AdvancedOnly extends StatelessWidget {
  final Widget child;

  const AdvancedOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) => isSimpleMode(context) ? const SizedBox.shrink() : child;
}

/// 簡易模式旗標。只在 build 內呼叫（依賴 provider 的變更通知來重建）。
bool isSimpleMode(BuildContext context) => context.watch<SettingsProvider>().simpleMode;
