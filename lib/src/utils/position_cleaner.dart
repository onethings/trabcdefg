// lib/src/utils/position_cleaner.dart
//
// Cleans raw position lists before they are rendered or replayed.
//
// Devices that were offline (or lost network) upload their buffered records in
// one batch. Those batches arrive unordered and may contain duplicated records,
// positions without a GPS fix and GPS spikes, which made the replayed track
// jump forwards and then backwards. This utility turns such a raw list into a
// monotonic, physically plausible track.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class PositionCleaner {
  const PositionCleaner._();

  /// Implied speed above which two consecutive points cannot belong to the same
  /// vehicle (km/h). Used to detect spikes, it does not clamp real speed.
  static const double defaultMaxSpeedKmh = 200;

  /// A back-and-forth shorter than this is treated as "standing still" noise
  /// once the heading reverses (meters).
  static const double defaultJitterRadiusMeters = 15;

  /// Heading reversal (degrees) that marks a [defaultJitterRadiusMeters] sized
  /// back-and-forth as GPS jitter instead of real movement.
  static const double defaultJitterAngleDegrees = 150;

  /// The moment the position was actually recorded by the device.
  ///
  /// `fixTime` is the GPS fix time and the only reliable ordering key for
  /// backfilled data. `deviceTime`/`serverTime` are fallbacks because some old
  /// servers leave fields empty.
  static DateTime? recordingTime(api.Position position) => position.fixTime ?? position.deviceTime ?? position.serverTime;

  /// The moment the server stored the record. Used to pick the freshest copy
  /// when a backfilled batch repeats the same timestamp.
  static DateTime? storedTime(api.Position position) => position.serverTime ?? position.fixTime ?? position.deviceTime;

  /// Returns a cleaned copy of [raw] (the input list is never modified):
  ///
  /// 1. records without coordinates or without any timestamp are dropped;
  /// 2. `valid == false` records (reported without a GPS fix) are dropped,
  ///    unless that would leave fewer than two points;
  /// 3. the track is sorted ascending by recording time so the timeline is
  ///    monotonic — this alone removes the "goes backwards" effect;
  /// 4. records sharing the same recording time are deduplicated, keeping the
  ///    copy the server stored last;
  /// 5. GPS spikes are removed: a point that requires an impossible speed both
  ///    to reach and to leave while its neighbours are close together (the
  ///    classic "fly away and come back" of backfilled data), plus tiny
  ///    heading-reversal jitter.
  static List<api.Position> clean(
    List<api.Position> raw, {
    bool dropInvalid = true,
    bool deduplicate = true,
    bool removeOutliers = true,
    double maxSpeedKmh = defaultMaxSpeedKmh,
    double jitterRadiusMeters = defaultJitterRadiusMeters,
    double jitterAngleDegrees = defaultJitterAngleDegrees,
  }) {
    // 1. Keep only records we can both draw and place on a timeline.
    var track = <_TimedPosition>[];
    for (final position in raw) {
      if (position.latitude == null || position.longitude == null) continue;
      final time = recordingTime(position);
      if (time == null) continue;
      track.add(_TimedPosition(position, time));
    }
    if (track.length < 2) return track.map((entry) => entry.position).toList();

    // 2. `valid == false` means the device reported without a GPS fix. Keep
    //    them when they are all we have so the track does not vanish.
    if (dropInvalid) {
      final validOnly = track.where((entry) => entry.position.valid != false).toList();
      if (validOnly.length >= 2) track = validOnly;
    }

    // 3. Backfilled batches are unordered — sort by the time the position was
    //    recorded, never by the time the server received it.
    track.sort((a, b) => a.time.compareTo(b.time));

    // 4. Collapse duplicated recording times, keeping the freshest copy.
    if (deduplicate) {
      final unique = <int, _TimedPosition>{};
      for (final entry in track) {
        final key = entry.time.millisecondsSinceEpoch;
        final existing = unique[key];
        if (existing == null || entry.storedAt.isAfter(existing.storedAt)) {
          unique[key] = entry;
        }
      }
      // Keys were inserted in ascending time order, so the values stay sorted.
      track = unique.values.toList();
    }

    // 5. Drop the points the vehicle cannot physically have visited.
    if (removeOutliers && track.length >= 3) {
      track = _removeOutliers(track, maxSpeedKmh, jitterRadiusMeters, jitterAngleDegrees);
    }

    return track.map((entry) => entry.position).toList();
  }

  // 新增：Douglas-Peucker 抽稀降噪演算法
  static List<api.Position> douglasPeucker(List<api.Position> points, {required double tolerance}) {
    if (points.length < 3) return points;

    double maxDistance = 0.0;
    int index = 0;

    final start = points.first;
    final end = points.last;

    // 計算中間每個點到首尾連線的垂直距離，找出距離最遠的點
    for (int i = 1; i < points.length - 1; i++) {
      double distance = _perpendicularDistance(points[i], start, end);
      if (distance > maxDistance) {
        index = i;
        maxDistance = distance;
      }
    }

    // 如果最大距離大於容差，則遞歸進行分段抽稀
    if (maxDistance > tolerance) {
      final List<api.Position> left = douglasPeucker(points.sublist(0, index + 1), tolerance: tolerance);
      final List<api.Position> right = douglasPeucker(points.sublist(index, points.length), tolerance: tolerance);

      // 合併前後兩段結果（去除重複的中間點）
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      // 若小於容差，直接捨棄中間來回晃動的噪點，只保留首尾
      return [start, end];
    }
  }

  /// 把「兩次取樣隔太遠、只能畫成直線」的路段補成實際道路幾何。
  ///
  /// 用的是 Valhalla 的 `/route`：兩個錨點之間請它算一條路。不用 `trace_route`
  /// 的 map matching 有兩個原因——只有兩個輸入點時它做的其實就是 routing，而它
  /// 預設的 breakage distance 是 10 km，超過直接 400
  /// （`Exceeded breakage distance for all pairs: 10000 meters`），偏偏實測資料
  /// 裡最刺眼的直線正是 10～13 km 那幾條。
  ///
  /// 只補相鄰兩點距離落在 [minGapMeters] 與 [maxGapMeters] 之間的段落：密集取樣
  /// 的路段本來就沿著路走，重送只會讓伺服器把真實取樣重畫一遍；更好的做法是讓
  /// 缺口自己留在那裡，也不要猜一條我們證明不了的路線。
  ///
  /// 一天有幾百個缺口，公開伺服器一秒只吃得下一兩個請求，所以缺口由長排到短：
  /// 同樣的預算先補掉最刺眼的那幾條直線。每一段都是獨立請求，任何一段失敗都只
  /// 退回那一段的直線，不影響其他段；總耗時超過 [totalBudget] 就停止再送。
  ///
  /// 沒有補到任何路段時原封不動回傳 [simplified]（同一個實例），呼叫端可以用
  /// `identical` 判斷結果有沒有變，決定要不要重寫快取。
  ///
  /// [routeUrl] 例如 `https://valhalla1.openstreetmap.de/route` 或自架主機；
  /// 傳空字串等於完全關閉。 [client] 只給測試注入用。
  static Future<List<api.Position>> fillStraightGaps(
    List<api.Position> simplified, {
    required String routeUrl,
    double minGapMeters = 250,
    double maxGapMeters = 20000,
    String costing = 'auto',
    Duration timeout = const Duration(seconds: 8),
    Duration totalBudget = const Duration(seconds: 20),
    int maxRequests = 40,
    http.Client? client,
  }) async {
    if (simplified.length < 2 || routeUrl.isEmpty) return simplified;

    final candidates = <({int index, double meters})>[];
    for (var i = 0; i < simplified.length - 1; i++) {
      final meters = _distanceBetweenPositions(simplified[i], simplified[i + 1]);
      if (meters < minGapMeters || meters > maxGapMeters) continue;
      candidates.add((index: i, meters: meters));
    }
    if (candidates.isEmpty) return simplified;
    candidates.sort((a, b) => b.meters.compareTo(a.meters));
    final selected = <int>{for (final gap in candidates.take(maxRequests)) gap.index};

    final httpClient = client ?? http.Client();
    final startedAt = DateTime.now();
    List<api.Position>? output;
    var requests = 0;
    var gaveUpEarly = false;

    try {
      for (var i = 0; i < simplified.length - 1; i++) {
        final from = simplified[i];
        final to = simplified[i + 1];

        // Once the track is being rebuilt every untouched vertex has to be copied
        // over; only the chords that actually got rerouted may be replaced.
        if (output != null && !identical(output.last, from)) output.add(from);
        if (!selected.contains(i)) continue;

        if (DateTime.now().difference(startedAt) > totalBudget) {
          gaveUpEarly = true;
          continue;
        }
        requests++;

        final List<api.Position> routed;
        try {
          routed = await _routeBetween(from, to, routeUrl: routeUrl, costing: costing, timeout: timeout, client: httpClient);
        } catch (error) {
          developer.log('Gap routing failed for ${from.latitude},${from.longitude}: $error', name: 'PositionCleaner');
          continue;
        }
        if (routed.isEmpty) continue;

        output ??= simplified.sublist(0, i + 1);
        output
          ..addAll(routed)
          ..add(to);
      }
    } finally {
      if (client == null) httpClient.close();
    }

    if (output == null) {
      if (gaveUpEarly) {
        developer.log('Gap routing budget reached, ${simplified.length} points left as drawn', name: 'PositionCleaner');
      }
      return simplified;
    }
    if (gaveUpEarly || selected.length > requests) {
      developer.log('Filled $requests of ${selected.length} ranked gaps (budget reached)', name: 'PositionCleaner');
    }
    // The track has to end on the real last sample, not on routed geometry.
    if (!identical(output.last, simplified.last)) output.add(simplified.last);
    return output;
  }

  /// 向 Valhalla 要 [from] 到 [to] 之間的道路幾何。
  ///
  /// 回傳的點不含兩個錨點本身：錨點保留自己真正的取樣時間，補出來的中間點則
  /// 依沿路累積距離把時間線性內插回兩個錨點之間，播放的時間軸仍然是單調的。
  static Future<List<api.Position>> _routeBetween(
    api.Position from,
    api.Position to, {
    required String routeUrl,
    required String costing,
    required Duration timeout,
    required http.Client client,
  }) async {
    final response = await client
        .post(
          Uri.parse(routeUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            // `radius` 是這個點最多可以吸到多遠的路：郊區的取樣可能離路十幾公尺。
            'locations': [_routeLocation(from), _routeLocation(to)],
            'costing': costing,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      developer.log('Gap routing HTTP ${response.statusCode}: ${response.body}', name: 'PositionCleaner');
      return const [];
    }

    final decoded = <List<double>>[];
    final trip = (jsonDecode(response.body) as Map<String, dynamic>)['trip'];
    final legs = trip is Map ? trip['legs'] : null;
    if (legs is List) {
      for (final leg in legs) {
        final shape = leg is Map ? leg['shape'] : null;
        if (shape is String) decoded.addAll(_decodePolyline(shape, 6));
      }
    }
    // Fewer than three vertices means the server only echoed the two anchors.
    if (decoded.length < 3) return const [];

    final cumulative = _cumulativeMeters(decoded);
    final totalMeters = cumulative.last;
    final startTime = recordingTime(from);
    final endTime = recordingTime(to);
    final anchorSpeed = (from.speed ?? to.speed)?.toDouble();
    // Anchors without a speed would make every spliced point disappear from the
    // playback track, which filters on `speed > 0`, so derive one from the gap.
    final knots = anchorSpeed != null && anchorSpeed > 0 ? anchorSpeed : _impliedKnots(totalMeters, startTime, endTime);

    final positions = <api.Position>[];
    for (var i = 1; i < decoded.length - 1; i++) {
      final fraction = totalMeters <= 0 ? 0.0 : cumulative[i] / totalMeters;
      final time = startTime == null || endTime == null ? null : startTime.add(endTime.difference(startTime) * fraction);
      positions.add(
        api.Position(
          deviceId: from.deviceId,
          latitude: decoded[i][0],
          longitude: decoded[i][1],
          fixTime: time,
          deviceTime: time,
          speed: knots,
          valid: true,
        ),
      );
    }
    return positions;
  }

  /// 一筆 `/route` 的 location。`radius` 讓郊區那幾個離路有點遠的取樣仍然找得到
  /// 最近的路，不然 Valhalla 會回 `No path could be found`。
  static Map<String, Object> _routeLocation(api.Position position) => <String, Object>{
    'lat': position.latitude!.toDouble(),
    'lon': position.longitude!.toDouble(),
    'radius': 60,
  };

  /// Polyline 解碼，回傳 `[lat, lon]` 成對的座標（Valhalla 預設 precision 6，
  /// 而且跟 Google 一樣是先緯度後經度）。
  ///
  /// 截斷的輸入會停在最後一組完整的座標，不會為了半個點丟掉整段。
  static List<List<double>> _decodePolyline(String encoded, int precision) {
    final points = <List<double>>[];
    final factor = pow(10, precision).toDouble();
    final len = encoded.length;
    var index = 0;
    var lat = 0;
    var lon = 0;

    while (index < len) {
      var shift = 0, result = 0, b = 0x20;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < len);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      if (index >= len) break;

      shift = 0;
      result = 0;
      b = 0x20;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < len);
      lon += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add([lat / factor, lon / factor]);
    }
    return points;
  }

  /// 沿著 [latLon] 走一趟的累積距離（公尺），第一項固定為 0，長度與輸入相同。
  static List<double> _cumulativeMeters(List<List<double>> latLon) {
    final cumulative = <double>[0];
    for (var i = 1; i < latLon.length; i++) {
      final previous = latLon[i - 1];
      final current = latLon[i];
      cumulative.add(cumulative[i - 1] + _haversineMeters(previous[0], previous[1], current[0], current[1]));
    }
    return cumulative;
  }

  /// 補出來的點要用的速度（節）：錨點沒帶速度時，用補完的路長與時間差推一個，
  /// 否則這些點會被播放時的 `speed > 0` 濾掉，地圖上就看不到補出來的路。
  static double _impliedKnots(double meters, DateTime? from, DateTime? to) {
    if (from == null || to == null) return 0;
    final seconds = to.difference(from).inMilliseconds / 1000.0;
    if (seconds <= 0) return 0;
    return (meters / seconds) * 3.6 / 1.852;
  }

  static double _distanceBetweenPositions(api.Position a, api.Position b) => _haversineMeters(a.latitude!.toDouble(), a.longitude!.toDouble(), b.latitude!.toDouble(), b.longitude!.toDouble());

  static double _haversineMeters(double lat1Deg, double lon1Deg, double lat2Deg, double lon2Deg) {
    const earthRadius = 6371000.0;
    final lat1 = _toRadians(lat1Deg);
    final lat2 = _toRadians(lat2Deg);
    final deltaLat = _toRadians(lat2Deg - lat1Deg);
    final deltaLon = _toRadians(lon2Deg - lon1Deg);
    final h = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    return 2 * earthRadius * asin(min(1.0, sqrt(h)));
  }

  // 計算點到直線距離的數學輔助函式
  static double _perpendicularDistance(api.Position p, api.Position start, api.Position end) {
    final double x = p.longitude?.toDouble() ?? 0.0;
    final double y = p.latitude?.toDouble() ?? 0.0;
    final double x1 = start.longitude?.toDouble() ?? 0.0;
    final double y1 = start.latitude?.toDouble() ?? 0.0;
    final double x2 = end.longitude?.toDouble() ?? 0.0;
    final double y2 = end.latitude?.toDouble() ?? 0.0;

    final double numerator = ((y2 - y1) * x - (x2 - x1) * y + x2 * y1 - y2 * x1).abs();
    final double denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2));

    if (denominator == 0.0) {
      return sqrt(pow(x - x1, 2) + pow(y - y1, 2));
    }
    return numerator / denominator;
  }

  static List<_TimedPosition> _removeOutliers(List<_TimedPosition> track, double maxSpeedKmh, double jitterRadiusMeters, double jitterAngleDegrees) {
    final result = <_TimedPosition>[track.first];

    for (var i = 1; i < track.length - 1; i++) {
      final previous = result.last;
      final current = track[i];
      final next = track[i + 1];

      // A spike needs an impossible speed on both legs while the surrounding
      // points stay plausible: out and straight back in.
      final inSpeed = _impliedSpeedKmh(previous, current);
      final outSpeed = _impliedSpeedKmh(current, next);
      final directSpeed = _impliedSpeedKmh(previous, next);
      if (inSpeed > maxSpeedKmh && outSpeed > maxSpeedKmh && directSpeed <= maxSpeedKmh) {
        continue;
      }

      // Standing-still jitter: a tiny move followed by a hard heading reversal.
      if (_isJitter(previous, current, next, jitterRadiusMeters, jitterAngleDegrees)) {
        continue;
      }

      result.add(current);
    }

    // The first and last points are always kept: they anchor the track and a
    // spike at either end cannot be proven with only one leg.
    result.add(track.last);
    return result;
  }

  static bool _isJitter(_TimedPosition previous, _TimedPosition current, _TimedPosition next, double radiusMeters, double angleDegrees) {
    if (_distanceMeters(previous, current) > radiusMeters) return false;
    if (_distanceMeters(current, next) > radiusMeters) return false;

    final inbound = _bearingDegrees(previous, current);
    final outbound = _bearingDegrees(current, next);
    var reversal = (outbound - inbound).abs() % 360;
    if (reversal > 180) reversal = 360 - reversal;
    return reversal >= angleDegrees;
  }

  /// Speed (km/h) implied by getting from [a] to [b] in the time between them.
  static double _impliedSpeedKmh(_TimedPosition a, _TimedPosition b) {
    final seconds = b.time.difference(a.time).inMilliseconds / 1000.0;
    if (seconds <= 0) return 0; // Same instant: nothing to judge.
    // Sub-second spacing is treated as one second, so two reports inside the
    // same second are not mistaken for an impossible jump.
    final hours = (seconds < 1 ? 1.0 : seconds) / 3600.0;
    return _distanceMeters(a, b) / 1000.0 / hours;
  }

  static double _distanceMeters(_TimedPosition a, _TimedPosition b) => _haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);

  static double _bearingDegrees(_TimedPosition a, _TimedPosition b) {
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final deltaLon = _toRadians(b.longitude - a.longitude);
    final y = sin(deltaLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon);
    return (_toDegrees(atan2(y, x)) + 360) % 360;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  static double _toDegrees(double radians) => radians * 180 / pi;
}

/// A position paired with its recording and storage timestamps, so the sorting
/// and filtering passes never have to re-parse them.
class _TimedPosition {
  _TimedPosition(this.position, this.time) : storedAt = PositionCleaner.storedTime(position) ?? time;

  final api.Position position;

  /// Recording time (`fixTime`), used for ordering and speed checks.
  final DateTime time;

  /// Server storage time (`serverTime`), used to keep the freshest duplicate.
  final DateTime storedAt;

  double get latitude => position.latitude!.toDouble();

  double get longitude => position.longitude!.toDouble();
}
