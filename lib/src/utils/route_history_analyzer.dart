import 'dart:math';

import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/position_cleaner.dart';

/// 由本機軌跡推算出的行程。
class AnalyzedTrip {
  final double distanceMeters;
  final int durationMs;
  final double maxSpeedKmh;
  final double averageSpeedKmh;
  final DateTime startTime;
  final DateTime endTime;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;

  const AnalyzedTrip({
    required this.distanceMeters,
    required this.durationMs,
    required this.maxSpeedKmh,
    required this.averageSpeedKmh,
    required this.startTime,
    required this.endTime,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
  });
}

/// 由本機軌跡推算出的停留。
class AnalyzedStop {
  final double latitude;
  final double longitude;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMs;

  const AnalyzedStop({required this.latitude, required this.longitude, required this.startTime, required this.endTime, required this.durationMs});
}

class RouteHistoryAnalysis {
  final List<AnalyzedTrip> trips;
  final List<AnalyzedStop> stops;

  const RouteHistoryAnalysis({required this.trips, required this.stops});

  bool get isEmpty => trips.isEmpty && stops.isEmpty;
}

/// 將軌跡點切分為行程與停留，供行程頁／停留頁在沒有報表 API 資料時使用。
class RouteHistoryAnalyzer {
  /// 低於此速度視為靜止（km/h）。
  static const double movingThresholdKmh = 3.0;

  /// 最短停留時間，短於此值的靜止段落視為行程的一部分。
  static const int minStopMinutes = 5;

  /// 最短行程時長／距離，用來濾除零星移動。
  static const int minTripSeconds = 60;
  static const double minTripMeters = 100;

  /// 超過此時間的資料斷檔會切斷行程與停留。
  static const int maxGapMinutes = 30;

  static RouteHistoryAnalysis analyze(List<api.Position> positions) {
    final points = _preparePoints(positions);
    if (points.length < 2) {
      return const RouteHistoryAnalysis(trips: [], stops: []);
    }

    final runs = _buildRuns(points);
    final stops = _buildStops(points, runs);
    final trips = _buildTrips(points, runs, stops.map((entry) => entry.runIndex).toSet());

    return RouteHistoryAnalysis(trips: trips, stops: stops.map((entry) => entry.stop).toList());
  }

  static List<_Point> _preparePoints(List<api.Position> positions) {
    final points = <_Point>[];
    for (final position in positions) {
      final time = PositionCleaner.recordingTime(position);
      final lat = position.latitude?.toDouble();
      final lon = position.longitude?.toDouble();
      if (time == null || lat == null || lon == null) continue;
      points.add(_Point(time, lat, lon, (position.speed?.toDouble() ?? 0) * 1.852));
    }
    points.sort((a, b) => a.time.compareTo(b.time));

    // 裝置完全不回報速度時，改用位移推算，避免整段軌跡被判為靜止。
    if (points.isNotEmpty && points.every((point) => point.speedKmh <= 0)) {
      for (var i = 1; i < points.length; i++) {
        final seconds = points[i].time.difference(points[i - 1].time).inSeconds;
        if (seconds <= 0) continue;
        points[i].speedKmh = _distanceMeters(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon) / seconds * 3.6;
      }
    }
    return points;
  }

  static List<_Run> _buildRuns(List<_Point> points) {
    final runs = <_Run>[];
    var start = 0;
    var startsAfterGap = false;

    for (var i = 1; i < points.length; i++) {
      final gapSeconds = points[i].time.difference(points[i - 1].time).inSeconds;
      final hasGap = gapSeconds > maxGapMinutes * 60;
      final kindChanged = points[i].moving != points[i - 1].moving;
      if (hasGap || kindChanged) {
        runs.add(_Run(start, i - 1, points[start].moving, startsAfterGap));
        start = i;
        startsAfterGap = hasGap;
      }
    }
    runs.add(_Run(start, points.length - 1, points[start].moving, startsAfterGap));
    return runs;
  }

  static List<_StopRun> _buildStops(List<_Point> points, List<_Run> runs) {
    final stops = <_StopRun>[];
    for (var index = 0; index < runs.length; index++) {
      final run = runs[index];
      if (run.moving) continue;

      final DateTime startTime = index > 0 ? points[runs[index - 1].end].time : points[run.start].time;
      final DateTime endTime = index + 1 < runs.length ? points[runs[index + 1].start].time : points[run.end].time;
      final int durationMs = endTime.difference(startTime).inMilliseconds;
      if (durationMs < minStopMinutes * 60 * 1000) continue;

      var latSum = 0.0;
      var lonSum = 0.0;
      for (var i = run.start; i <= run.end; i++) {
        latSum += points[i].lat;
        lonSum += points[i].lon;
      }
      final count = run.end - run.start + 1;

      stops.add(
        _StopRun(
          runIndex: index,
          stop: AnalyzedStop(latitude: latSum / count, longitude: lonSum / count, startTime: startTime, endTime: endTime, durationMs: durationMs),
        ),
      );
    }
    return stops;
  }

  static List<AnalyzedTrip> _buildTrips(List<_Point> points, List<_Run> runs, Set<int> stopRunIndexes) {
    final trips = <AnalyzedTrip>[];
    var buffer = <_Point>[];

    void flush() {
      if (buffer.length >= 2) {
        var distance = 0.0;
        var maxSpeed = 0.0;
        for (var i = 0; i < buffer.length; i++) {
          if (buffer[i].speedKmh > maxSpeed) maxSpeed = buffer[i].speedKmh;
          if (i > 0) {
            distance += _distanceMeters(buffer[i - 1].lat, buffer[i - 1].lon, buffer[i].lat, buffer[i].lon);
          }
        }
        final int durationMs = buffer.last.time.difference(buffer.first.time).inMilliseconds;
        if (distance >= minTripMeters && durationMs >= minTripSeconds * 1000) {
          final seconds = durationMs / 1000;
          trips.add(
            AnalyzedTrip(
              distanceMeters: distance,
              durationMs: durationMs,
              maxSpeedKmh: maxSpeed,
              averageSpeedKmh: seconds > 0 ? distance / seconds * 3.6 : 0,
              startTime: buffer.first.time,
              endTime: buffer.last.time,
              startLat: buffer.first.lat,
              startLon: buffer.first.lon,
              endLat: buffer.last.lat,
              endLon: buffer.last.lon,
            ),
          );
        }
      }
      buffer = <_Point>[];
    }

    for (var index = 0; index < runs.length; index++) {
      final run = runs[index];
      if (run.startsAfterGap) flush();
      if (run.moving) {
        for (var i = run.start; i <= run.end; i++) {
          buffer.add(points[i]);
        }
      } else if (stopRunIndexes.contains(index)) {
        flush();
      }
    }
    flush();

    return trips;
  }

  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLon = (lon2 - lon1) * pi / 180;
    final double a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * earthRadius * asin(min(1, sqrt(a)));
  }
}

class _Point {
  final DateTime time;
  final double lat;
  final double lon;
  double speedKmh;

  _Point(this.time, this.lat, this.lon, this.speedKmh);

  bool get moving => speedKmh > RouteHistoryAnalyzer.movingThresholdKmh;
}

class _Run {
  final int start;
  final int end;
  final bool moving;
  final bool startsAfterGap;

  _Run(this.start, this.end, this.moving, this.startsAfterGap);
}

class _StopRun {
  final int runIndex;
  final AnalyzedStop stop;

  _StopRun({required this.runIndex, required this.stop});
}
