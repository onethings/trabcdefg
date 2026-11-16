// lib/storage/map_view_memory.dart
import 'package:shared_preferences/shared_preferences.dart';

/// 地圖視角記憶（Map View Memory）：關掉 App 再打開時，回到「上次看的那台車 +
/// 當時的 zoom」，並讓每台車各自記得自己的 zoom。
///
/// 兩層資料，但只有一個寫入點 [record]，所以兩層永遠一致：
/// - 全域 resume 點：`mapview.last_device_id` / `mapview.last_zoom`
///   誰是「上次那台車」只有這一份答案，重開 App 只認這一份。
/// - 每台車的 zoom：`mapview.zoom.<deviceId>`
///   換車時回到該車上次的視角；它是 resume 點的另一個投影，不是獨立真相。
///
/// 不要在這裡之外寫這些 key，也不要把 `selectedDeviceId` 當成這份記憶來用：
/// 那個 key 由報告、行車軌跡、裝置清單共用，任何一頁選車都會把它改掉。
class MapViewMemory {
  const MapViewMemory._();

  static const String lastDeviceKey = 'mapview.last_device_id';
  static const String lastZoomKey = 'mapview.last_zoom';
  static const String vehicleZoomPrefix = 'mapview.zoom.';

  /// 上次的車與 zoom；沒有紀錄時為 null。
  static ({int? deviceId, double? zoom}) read(SharedPreferences prefs) =>
      (deviceId: prefs.getInt(lastDeviceKey), zoom: prefs.getDouble(lastZoomKey));

  /// 某台車自己上次的 zoom；沒看過這台車時為 null。
  static double? zoomFor(SharedPreferences prefs, int deviceId) => prefs.getDouble('$vehicleZoomPrefix$deviceId');

  /// 一次寫入就同時更新全域 resume 點與該車的 zoom。
  static Future<void> record(SharedPreferences prefs, {required int deviceId, required double zoom}) async {
    await prefs.setInt(lastDeviceKey, deviceId);
    await prefs.setDouble(lastZoomKey, zoom);
    await prefs.setDouble('$vehicleZoomPrefix$deviceId', zoom);
  }
}
