// test/map_view_memory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/storage/map_view_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('record 之後，全域 resume 點與該車 zoom 一起就位', () async {
    final prefs = await SharedPreferences.getInstance();
    await MapViewMemory.record(prefs, deviceId: 7, zoom: 18);

    final memory = MapViewMemory.read(prefs);
    expect(memory.deviceId, 7);
    expect(memory.zoom, 18.0);
    expect(MapViewMemory.zoomFor(prefs, 7), 18.0);
  });

  test('兩台車各記各的 zoom，全域只跟著最後看的那台', () async {
    final prefs = await SharedPreferences.getInstance();
    await MapViewMemory.record(prefs, deviceId: 7, zoom: 18);
    await MapViewMemory.record(prefs, deviceId: 9, zoom: 12);

    final memory = MapViewMemory.read(prefs);
    expect(memory.deviceId, 9, reason: '重開 App 要回到最後看的那台');
    expect(memory.zoom, 12.0);
    expect(MapViewMemory.zoomFor(prefs, 7), 18.0, reason: 'A 車的 zoom 不該被 B 車覆蓋');
    expect(MapViewMemory.zoomFor(prefs, 9), 12.0);
  });

  test('沒看過的車回 null，不會借用別台車的 zoom', () async {
    final prefs = await SharedPreferences.getInstance();
    await MapViewMemory.record(prefs, deviceId: 7, zoom: 18);

    expect(MapViewMemory.zoomFor(prefs, 9), isNull);
  });

  test('沒有任何紀錄時 read 兩個欄位都是空的', () async {
    final prefs = await SharedPreferences.getInstance();

    final memory = MapViewMemory.read(prefs);
    expect(memory.deviceId, isNull);
    expect(memory.zoom, isNull);
  });

  test('只寫 mapview.* 的 key，不碰共用的 selectedDeviceId', () async {
    final prefs = await SharedPreferences.getInstance();
    await MapViewMemory.record(prefs, deviceId: 7, zoom: 18);

    expect(prefs.getKeys().every((key) => key.startsWith('mapview.')), isTrue);
    expect(prefs.getInt('selectedDeviceId'), isNull);
  });
}
