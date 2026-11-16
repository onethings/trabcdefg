import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

class MarkerIconService {
  /// 選中車輛的車牌背景色（iOS 系統藍），用以區別未選中的車輛。
  static const Color selectedLabelBackground = Color(0xFF007AFF);

  final Set<String> loadedIcons;

  /// 各圖示的剪影凸包（相對圖示中心、貼圖像素座標，y 向下）。
  /// 車牌靠它貼在剪影下方，不會被圖示擋住，也不會離太遠。
  final Map<String, List<Offset>> _outlineHulls = {};

  MarkerIconService({required this.loadedIcons});

  /// 車輛剪影在指定航向（度，順時針）下，相對圖示中心向下的最大延伸（貼圖像素）。
  double iconBottomExtent(String iconKey, double courseDegrees) {
    final List<Offset>? hull = _outlineHulls[iconKey];
    if (hull == null || hull.isEmpty) return 16.0;
    final double a = courseDegrees * math.pi / 180.0;
    final double sinA = math.sin(a);
    final double cosA = math.cos(a);
    double maxBottom = 0;
    for (final Offset p in hull) {
      final double y = p.dx * sinA + p.dy * cosA;
      if (y > maxBottom) maxBottom = y;
    }
    return maxBottom;
  }

  Future<void> _ensureIconLoadedInternal(
    maplibre.MapLibreMapController? mapController,
    String iconKey,
  ) async {
    if (mapController == null || loadedIcons.contains(iconKey)) return;

    try {
      final String assetPath = 'assets/images/$iconKey.png';
      final ByteData bytes = await rootBundle.load(assetPath);
      final Uint8List list = bytes.buffer.asUint8List();

      await mapController.addImage(iconKey, list);
      loadedIcons.add(iconKey);
      if (!_outlineHulls.containsKey(iconKey)) {
        _outlineHulls[iconKey] = await _computeOutlineHull(list);
      }
    } catch (e) {
      debugPrint("❌ Failed to load icon '$iconKey': $e");
      if (iconKey != 'marker_default_unknown') {
        await _ensureIconLoadedInternal(
          mapController,
          'marker_default_unknown',
        );
      }
    }
  }

  Future<void> ensureIconLoaded(
    maplibre.MapLibreMapController? mapController,
    String iconKey,
  ) async {
    await _ensureIconLoadedInternal(mapController, iconKey);
  }

  Future<void> ensureLabelIconLoaded(
    maplibre.MapLibreMapController? mapController,
    String plate,
    String customLabelId, {
    bool isSelected = false,
  }) async {
    if (mapController == null || loadedIcons.contains(customLabelId)) return;

    try {
      final Uint8List? pngBytes = await buildLabelPng(
        plate,
        isSelected: isSelected,
      );
      if (pngBytes != null) {
        await mapController.addImage(customLabelId, pngBytes);
        loadedIcons.add(customLabelId);
      }
    } catch (e) {
      debugPrint("❌ 生成標籤標記錯誤 ($customLabelId): $e");
    }
  }

  /// 產生車牌標籤圖片：[isSelected] 為 true 時使用藍底白字，否則白底黑字。
  Future<Uint8List?> buildLabelPng(
    String plate, {
    bool isSelected = false,
  }) async {
    // 1. 準備文字繪製器 (TextPainter)
    // 使用更清晰的字體與間距，確保可讀性
    final textPainter = TextPainter(
      text: TextSpan(
        text: plate,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontSize: 18.0, // 加大字體 (從 14 -> 18)
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    // 2. 計算背景尺寸 (窄背景)
    const double horizontalPadding = 10.0; // 增加左右邊距
    const double verticalPadding = 4.0; // 增加上下邊距
    final double boxWidth = textPainter.width + (horizontalPadding * 2);
    final double boxHeight = textPainter.height + (verticalPadding * 2);

    // 3. 建立畫布並繪製
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 繪製陰影 (讓標籤更立體)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4); // 增加陰影模糊度
    canvas.drawRRect(
      RRect.fromLTRBR(
        2,
        2,
        boxWidth + 2,
        boxHeight + 2,
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    // 繪製車牌背景（選中：藍底白字；未選中：白底黑字）
    final bgPaint = Paint()
      ..color = isSelected ? selectedLabelBackground : Colors.white;
    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0; // 稍微加粗邊框

    final rRect = RRect.fromLTRBR(
      0,
      0,
      boxWidth,
      boxHeight,
      const Radius.circular(8),
    );
    canvas.drawRRect(rRect, bgPaint);
    canvas.drawRRect(rRect, borderPaint); // 加入細黑邊框增加對比

    // 繪製文字
    textPainter.paint(canvas, const Offset(horizontalPadding, verticalPadding));

    // 4. 轉換為圖片格式
    final picture = recorder.endRecording();
    ui.Image? img;
    try {
      // 我們在畫布周圍預留一點空間給陰影
      img = await picture.toImage(
        (boxWidth + 8).toInt(),
        (boxHeight + 8).toInt(),
      );
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return pngBytes?.buffer.asUint8List();
    } finally {
      // toByteData 已拷貝出 PNG 位元組，native 的 Image 與 Picture 留著只會等 finalizer
      img?.dispose();
      picture.dispose();
    }
  }

  // 保留舊的方法以防其他地方引用，但標註為不建議使用
  Future<void> ensureCustomIconLoaded(
    maplibre.MapLibreMapController? mapController,
    String baseIconKey,
    String plate,
    String customIconId,
  ) async {
    // 為了向下相容，這裡暫時導入基礎圖標加文字的舊邏輯
    // 但新的 MapScreen 應該改用 ensureIconLoaded + ensureLabelIconLoaded
    await ensureIconLoaded(mapController, baseIconKey);
    await ensureLabelIconLoaded(mapController, plate, customIconId);
  }

  /// 解碼貼圖、取不透明像素的凸包（座標相對圖片中心，貼圖像素、y 向下）。
  /// 車牌位置靠這份輪廓算剪影下緣，不需要人工維護常數。
  Future<List<Offset>> _computeOutlineHull(Uint8List pngBytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(pngBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      image = frame.image;
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return const <Offset>[];

      final int width = image.width;
      final int height = image.height;
      final double centerX = width / 2.0;
      final double centerY = height / 2.0;
      final List<Offset> points = <Offset>[];
      for (int y = 0; y < height; y++) {
        final int rowOffset = y * width * 4;
        for (int x = 0; x < width; x++) {
          if (data.getUint8(rowOffset + x * 4 + 3) > 16) {
            points.add(Offset(x + 0.5 - centerX, y + 0.5 - centerY));
          }
        }
      }
      return _convexHull(points);
    } catch (e) {
      debugPrint('❌ Failed to measure icon outline: $e');
      return const <Offset>[];
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  /// Andrew 的單調鏈演算法。
  static List<Offset> _convexHull(List<Offset> points) {
    if (points.length <= 3) return points;
    final List<Offset> sorted = List<Offset>.of(points)
      ..sort((Offset a, Offset b) => a.dx == b.dx ? a.dy.compareTo(b.dy) : a.dx.compareTo(b.dx));

    double cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

    final List<Offset> lower = <Offset>[];
    for (final Offset p in sorted) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final List<Offset> upper = <Offset>[];
    for (final Offset p in sorted.reversed) {
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    lower.removeLast();
    upper.removeLast();
    return <Offset>[...lower, ...upper];
  }
}
