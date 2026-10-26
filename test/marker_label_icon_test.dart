import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/services/marker_icon_service.dart';

Future<ui.Image> _decodePng(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

/// 取樣標籤左側留白處的像素，避免取到文字或圓角。
Future<Color> _backgroundPixel(ui.Image image) async {
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final Uint8List bytes = data.buffer.asUint8List();
  final int offset = ((image.height ~/ 2) * image.width + 6) * 4;
  return Color.fromARGB(bytes[offset + 3], bytes[offset], bytes[offset + 1], bytes[offset + 2]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MarkerIconService service = MarkerIconService(loadedIcons: <String>{});

  test('未選中的車牌標籤維持白底', () async {
    final Uint8List? png = await service.buildLabelPng('ABC-123');
    expect(png, isNotNull);

    final Color background = await _backgroundPixel(await _decodePng(png!));
    expect(background.r * 255, greaterThan(245));
    expect(background.g * 255, greaterThan(245));
    expect(background.b * 255, greaterThan(245));
  });

  test('選中的車牌標籤改為藍底', () async {
    final Uint8List? png = await service.buildLabelPng('ABC-123', isSelected: true);
    expect(png, isNotNull);

    final Color background = await _backgroundPixel(await _decodePng(png!));
    expect(background.b * 255, greaterThan(200));
    expect(background.r * 255, lessThan(60));
    expect(background.g * 255, inInclusiveRange(90, 160));
  });
}
