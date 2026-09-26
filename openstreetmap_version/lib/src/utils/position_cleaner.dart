// lib/src/utils/position_cleaner.dart
//
// Cleans raw position lists before they are rendered or replayed.
//
// Devices that were offline (or lost network) upload their buffered records in
// one batch. Those batches arrive unordered and may contain duplicated records,
// positions without a GPS fix and GPS spikes, which made the replayed track
// jump forwards and then backwards. This utility turns such a raw list into a
// monotonic, physically plausible track.

import 'dart:math';

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

  static double _distanceMeters(_TimedPosition a, _TimedPosition b) {
    const earthRadius = 6371000.0;
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final deltaLat = _toRadians(b.latitude - a.latitude);
    final deltaLon = _toRadians(b.longitude - a.longitude);
    final h = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    return 2 * earthRadius * asin(min(1.0, sqrt(h)));
  }

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
