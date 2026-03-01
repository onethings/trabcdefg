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

  Future<void> ensureCustomIconLoaded(
    maplibre.MapLibreMapController? mapController,
    String baseIconKey,
    String plate,
    String customIconId,
  ) async {
    if (mapController == null || loadedIcons.contains(customIconId)) return;

    try {
      // 1. 加載原始圖標
      final ByteData data = await rootBundle.load(
        'assets/images/$baseIconKey.png',
      );
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image markerImage = fi.image;

      // 2. 準備文字繪製器 (TextPainter)
      final textPainter = TextPainter(
        text: TextSpan(
          text: plate,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 8.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();

      // 3. 建立畫布並繪製
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      final double canvasWidth = markerImage.width > textPainter.width
          ? markerImage.width.toDouble()
          : textPainter.width;
      final double canvasHeight = markerImage.height + textPainter.height + 10;

      final double markerX = (canvasWidth - markerImage.width) / 2;
      canvas.drawImage(markerImage, Offset(markerX, 0), paint);

      final double textX = (canvasWidth - textPainter.width) / 2;
      textPainter.paint(
        canvas,
        Offset(textX, markerImage.height.toDouble() + 5),
      );

      // 4. 轉換為圖片格式
      final picture = recorder.endRecording();
      final img = await picture.toImage(
        canvasWidth.toInt(),
        canvasHeight.toInt(),
      );
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes != null && mapController != null) {
        await mapController!.addImage(
          customIconId,
          pngBytes.buffer.asUint8List(),
        );
        loadedIcons.add(customIconId);
      }
    } catch (e) {
      debugPrint("❌ 合成圖標錯誤 ($customIconId): $e");
    }
  }
}
