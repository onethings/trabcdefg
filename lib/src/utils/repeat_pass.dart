// Classifies a later pass when it comes close to a segment of the earlier
// recorded route. The spatial grid only narrows the candidate segments; the
// final decision always uses point-to-segment distance in metres.
import 'dart:math' as math;
import 'dart:typed_data';

/// Spatial bucket size. A larger bucket makes the lookup tolerant of GPS drift
/// while the exact distance test below prevents the bucket size widening the
/// actual repeat threshold.
const double defaultRepeatCellMeters = 40;

/// Maximum distance from a previously travelled segment to count as a repeat.
const double defaultRepeatToleranceMeters = 30;

/// A segment must end at least this many samples before the current point.
/// This excludes the immediately adjacent part of the same pass.
const int defaultMinIndexGap = 10;

/// Returns one flag per point. A point is repeated when it is within
/// [toleranceMeters] of a segment that ended at least [minIndexGap] samples
/// earlier. [lngLatPairs] is longitude/latitude interleaved.
///
/// Earlier route segments are indexed in metre-grid buckets. Each segment is
/// inserted into every bucket touched by its bounding box, so a later point
/// can find a road even when its GPS sample is offset from the old sample.
Uint8List classifyRepeatPasses(Float64List lngLatPairs, {double cellMeters = defaultRepeatCellMeters, double toleranceMeters = defaultRepeatToleranceMeters, int minIndexGap = defaultMinIndexGap}) {
  final int count = lngLatPairs.length ~/ 2;
  final Uint8List flags = Uint8List(count);
  if (count < 2 || cellMeters <= 0 || toleranceMeters < 0) return flags;
  final Uint8List candidatesByPoint = Uint8List(count);

  double latitudeSum = 0;
  for (var i = 0; i < count; i++) {
    latitudeSum += lngLatPairs[i * 2 + 1];
  }
  final double centreLatitude = latitudeSum / count;
  final double metresPerDegreeLng = _metresPerDegreeLongitude(centreLatitude);

  int cellX(double lng) => (lng * metresPerDegreeLng / cellMeters).floor();
  int cellY(double lat) => (lat * _metresPerDegreeLat / cellMeters).floor();
  int key(int x, int y) => x * 1000003 + y;

  // Bucket entries contain the start index of an earlier segment (j -> j+1).
  final Map<int, List<int>> buckets = <int, List<int>>{};

  void indexSegment(int start) {
    final double lng1 = lngLatPairs[start * 2];
    final double lat1 = lngLatPairs[start * 2 + 1];
    final double lng2 = lngLatPairs[(start + 1) * 2];
    final double lat2 = lngLatPairs[(start + 1) * 2 + 1];

    // Do not connect across large recording gaps; those are not reliable road
    // geometry and could otherwise index a huge rectangular area.
    if (_metresBetween(lng1, lat1, lng2, lat2) > 200) return;

    final int minX = cellX(math.min(lng1, lng2));
    final int maxX = cellX(math.max(lng1, lng2));
    final int minY = cellY(math.min(lat1, lat2));
    final int maxY = cellY(math.max(lat1, lat2));
    // A normal GPS segment touches only a handful of cells. Guard against
    // malformed coordinates creating an unbounded indexing operation.
    if ((maxX - minX + 1) * (maxY - minY + 1) > 256) return;
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        (buckets[key(x, y)] ??= <int>[]).add(start);
      }
    }
  }

  int nextSegmentEnd = 1;
  for (var i = 0; i < count; i++) {
    // Only index segments whose end is far enough behind the current point.
    final int latestEligibleEnd = i - minIndexGap;
    while (nextSegmentEnd <= latestEligibleEnd) {
      indexSegment(nextSegmentEnd - 1);
      nextSegmentEnd++;
    }

    final double lng = lngLatPairs[i * 2];
    final double lat = lngLatPairs[i * 2 + 1];
    final int cx = cellX(lng);
    final int cy = cellY(lat);
    bool repeat = false;
    final Set<int> checkedSegments = <int>{};

    // With 40 m cells and a 30 m threshold, a 3x3 probe covers every segment
    // that can be within tolerance. The exact distance check remains 30 m.
    for (var dx = -1; dx <= 1 && !repeat; dx++) {
      for (var dy = -1; dy <= 1 && !repeat; dy++) {
        final List<int>? candidates = buckets[key(cx + dx, cy + dy)];
        if (candidates == null) continue;
        for (final int start in candidates) {
          if (!checkedSegments.add(start)) continue;
          final double distance = _pointToSegmentMeters(lng, lat, lngLatPairs[start * 2], lngLatPairs[start * 2 + 1], lngLatPairs[(start + 1) * 2], lngLatPairs[(start + 1) * 2 + 1], centreLatitude);
          if (distance <= toleranceMeters) {
            repeat = true;
            break;
          }
        }
      }
    }
    candidatesByPoint[i] = repeat ? 1 : 0;
  }

  // Require two neighbouring samples to agree. This suppresses isolated GPS
  // spikes that briefly pass near an old road without actually following it.
  for (var i = 0; i < count; i++) {
    if (candidatesByPoint[i] == 0) continue;
    final bool hasRepeatNeighbour = (i > 0 && candidatesByPoint[i - 1] == 1) || (i + 1 < count && candidatesByPoint[i + 1] == 1);
    if (hasRepeatNeighbour) flags[i] = 1;
  }
  return flags;
}

const double _metresPerDegreeLat = 110574.0;
double _metresPerDegreeLongitude(double latitude) => 111320.0 * math.cos(latitude * math.pi / 180);

/// Local equirectangular point-to-segment distance, suitable for short road
/// segments and metre-scale thresholds.
double _pointToSegmentMeters(double pointLng, double pointLat, double startLng, double startLat, double endLng, double endLat, double referenceLatitude) {
  final double mx = _metresPerDegreeLongitude(referenceLatitude);
  final double px = (pointLng - startLng) * mx;
  final double py = (pointLat - startLat) * _metresPerDegreeLat;
  final double sx = 0;
  final double sy = 0;
  final double ex = (endLng - startLng) * mx;
  final double ey = (endLat - startLat) * _metresPerDegreeLat;
  final double dx = ex - sx;
  final double dy = ey - sy;
  final double lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return math.sqrt(px * px + py * py);
  final double t = ((px * dx + py * dy) / lengthSquared).clamp(0.0, 1.0).toDouble();
  final double nearestX = sx + t * dx;
  final double nearestY = sy + t * dy;
  final double diffX = px - nearestX;
  final double diffY = py - nearestY;
  return math.sqrt(diffX * diffX + diffY * diffY);
}

/// Great-circle distance in metres.
double _metresBetween(double lng1, double lat1, double lng2, double lat2) {
  const double radiansPerDegree = 0.017453292519943295;
  final double dLat = (lat2 - lat1) * radiansPerDegree;
  final double dLng = (lng2 - lng1) * radiansPerDegree;
  final double a = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1 * radiansPerDegree) * math.cos(lat2 * radiansPerDegree) * math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371000 * math.asin(math.sqrt(a));
}
