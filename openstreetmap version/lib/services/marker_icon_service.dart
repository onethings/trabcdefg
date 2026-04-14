import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

class MarkerIconService {
  final Set<String> loadedIcons;

  MarkerIconService({required this.loadedIcons});

  Future<void> _ensureIconLoadedInternal(
    maplibre.MapLibreMapController? mapController,
    String iconKey,
  ) async {
    if (mapController == null || loadedIcons.contains(iconKey)) return;

    try {
      final String assetPath = 'assets/images/$iconKey.png';
      final ByteData bytes = await rootBundle.load(assetPath);
      final Uint8List list = bytes.buffer.asUint8List();

      await mapController!.addImage(iconKey, list);
      loadedIcons.add(iconKey);

      // Small delay to ensure the engine registers the new sprite
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      debugPrint("❌ Failed to load icon '$iconKey': $e");
      if (iconKey != 'marker_default_unknown') {
        await _ensureIconLoadedInternal(mapController, 'marker_default_unknown');
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
    String customLabelId,
  ) async {
    if (mapController == null || loadedIcons.contains(customLabelId)) return;

    try {
      // 1. 準備文字繪製器 (TextPainter)
      // 使用更清晰的字體與間距，確保可讀性
      final textPainter = TextPainter(
        text: TextSpan(
          text: plate,
          style: const TextStyle(
            color: Colors.black,
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
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4); // 增加陰影模糊度
      canvas.drawRRect(
        RRect.fromLTRBR(2, 2, boxWidth + 2, boxHeight + 2, const Radius.circular(8)),
        shadowPaint,
      );

      // 繪製白色窄背景
      final bgPaint = Paint()..color = Colors.white;
      final borderPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0; // 稍微加粗邊框

      final rRect = RRect.fromLTRBR(0, 0, boxWidth, boxHeight, const Radius.circular(8));
      canvas.drawRRect(rRect, bgPaint);
      canvas.drawRRect(rRect, borderPaint); // 加入細黑邊框增加對比

      // 繪製文字
      textPainter.paint(canvas, const Offset(horizontalPadding, verticalPadding));

      // 4. 轉換為圖片格式
      final picture = recorder.endRecording();
      // 我們在畫布周圍預留一點空間給陰影
      final img = await picture.toImage(
        (boxWidth + 8).toInt(),
        (boxHeight + 8).toInt(),
      );
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes != null && mapController != null) {
        await mapController!.addImage(
          customLabelId,
          pngBytes.buffer.asUint8List(),
        );
        loadedIcons.add(customLabelId);
      }
    } catch (e) {
      debugPrint("❌ 生成標籤標記錯誤 ($customLabelId): $e");
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
}
