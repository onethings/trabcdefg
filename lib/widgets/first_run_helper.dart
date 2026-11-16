// lib/widgets/first_run_helper.dart
import 'package:flutter/material.dart';

/// 導覽的一步：照亮哪個元件、說哪句話。
class FirstRunHelperStep {
  const FirstRunHelperStep({required this.targetKey, required this.title, required this.body});

  /// 被聚光燈框住的元件。找不到（尚未佈局）時卡片置中、不畫框。
  final GlobalKey targetKey;
  final String title;
  final String body;
}

/// 第一次打開 App 的導覽，像遊戲開場：畫面調暗，一次只照亮一個元件，
/// 點任何地方往前一步，也可以跳過。
///
/// 文案由呼叫端傳入，這裡不認識任何翻譯 key。
class FirstRunHelperOverlay extends StatefulWidget {
  const FirstRunHelperOverlay({
    super.key,
    required this.steps,
    required this.nextLabel,
    required this.doneLabel,
    required this.skipLabel,
    required this.counterLabel,
    required this.onFinished,
  });

  final List<FirstRunHelperStep> steps;
  final String nextLabel;
  final String doneLabel;
  final String skipLabel;

  /// 例如 `(current, total) => '1 / 10'`。
  final String Function(int current, int total) counterLabel;
  final VoidCallback onFinished;

  @override
  State<FirstRunHelperOverlay> createState() => _FirstRunHelperOverlayState();
}

class _FirstRunHelperOverlayState extends State<FirstRunHelperOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _fade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  bool get _isLast => _index >= widget.steps.length - 1;

  void _advance() {
    if (_isLast) {
      widget.onFinished();
      return;
    }
    setState(() => _index++);
  }

  /// 目標元件的畫面座標；還沒佈局時為 null。
  Rect? _targetRect() {
    final RenderObject? renderObject = widget.steps[_index].targetKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final RenderBox? self = context.findRenderObject() as RenderBox?;
    final Offset origin = self == null ? Offset.zero : self.localToGlobal(Offset.zero);
    return (renderObject.localToGlobal(Offset.zero) & renderObject.size).shift(-origin);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final FirstRunHelperStep step = widget.steps[_index];
    final Rect? target = _targetRect();

    // 目標在上半部就把卡片放底部，反之放頂部：不必量卡片高度也不會壓到目標。
    final bool cardAtBottom = target == null || target.center.dy < media.size.height * 0.5;

    return FadeTransition(
      opacity: _fade,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _advance,
              child: CustomPaint(
                painter: _SpotlightPainter(
                  rect: target,
                  scrim: Colors.black.withValues(alpha: 0.74),
                  ring: theme.colorScheme.primary,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: cardAtBottom ? null : media.padding.top + 20,
            bottom: cardAtBottom ? media.padding.bottom + 20 : null,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Semantics(
                  liveRegion: true,
                  child: Material(
                    color: theme.colorScheme.surface,
                    elevation: 12,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  widget.counterLabel(_index + 1, widget.steps.length),
                                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Spacer(),
                              TextButton(onPressed: widget.onFinished, child: Text(widget.skipLabel)),
                            ],
                          ),
                          Text(step.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(step.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton(
                              onPressed: _advance,
                              child: Text(_isLast ? widget.doneLabel : widget.nextLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 把整片畫面塗暗，只留目標那一塊透出來，並描一圈主色亮邊。
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.rect, required this.scrim, required this.ring});

  final Rect? rect;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final Path screen = Path()..addRect(Offset.zero & size);
    final Rect? target = rect;

    if (target == null) {
      canvas.drawPath(screen, Paint()..color = scrim);
      return;
    }

    final RRect hole = RRect.fromRectAndRadius(target.inflate(8), const Radius.circular(16));
    final Path cut = Path.combine(PathOperation.difference, screen, Path()..addRRect(hole));
    canvas.drawPath(cut, Paint()..color = scrim);
    canvas.drawRRect(hole, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = ring);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.rect != rect || oldDelegate.scrim != scrim || oldDelegate.ring != ring;
}
