// Classifies a later pass when it comes close to a segment of the earlier
// recorded route. Every decision is point-to-segment distance in metres: the
// metre grid only narrows the candidates, the minimum gap is travel distance
// rather than a sample count, and a long chord is split into one-cell pieces so
// a recording with sparse samples is still indexed. A position without a fix is
// skipped instead of bending the geometry.
import 'dart:math' as math;
import 'dart:typed_data';

/// Spatial bucket size. A larger bucket makes the lookup tolerant of GPS drift
/// while the exact distance test below prevents the bucket size widening the
/// actual repeat threshold.
const double defaultRepeatCellMeters = 40;

/// Maximum distance from a previously travelled segment to count as a repeat.
const double defaultRepeatToleranceMeters = 30;

/// A segment must end at least this many metres of travel before the current
/// point. This excludes the immediately adjacent part of the same pass without
/// assuming how often the tracker reports.
const double defaultMinGapMeters = 100;

/// A chord this long between consecutive samples is a recording gap, not road
/// geometry, so it is left out of the index.
const double _maxIndexedSegmentMeters = 10000;

/// A chord this many times longer than the shorter plausible chord beside it is
/// a recording gap or a GPS jump. A lost fix leaves one long jump between two
/// ordinary steps, and a jammed fix leaves a jump out and back: comparing with
/// the shorter side catches both halves. A genuinely sparse stretch is long on
/// both sides, so it stays indexed.
const double _gapRatio = 10;

/// Chords shorter than this are standing noise, not spacing evidence. Parked
/// positions repeat the same coordinate, and treating that zero-length step as
/// the shorter side would throw away the first ordinary step away from the
/// parking spot. Kept just above zero so a slow crawl of a few metres still
/// counts as a real step beside a jump.
const double _minSpacingEvidenceMeters = 1;

/// Returns one flag per point. A point is repeated when it is within
/// [toleranceMeters] of a segment that ended at least [minGapMeters] of travel
/// earlier. [lngLatPairs] is longitude/latitude interleaved; a point or a
/// segment with a non-finite coordinate is skipped.
///
/// Earlier route segments are cut into pieces about one cell long, and each
/// piece is inserted into every metre-grid bucket its bounding box touches, so
/// a later point finds a road even when its GPS sample is offset from the old
/// sample. The pieces lie on the chord, so the distance they measure is the
/// point-to-chord distance; their only job is bounding how much of the grid one
/// long segment covers.
Uint8List classifyRepeatPasses(
  Float64List lngLatPairs, {
  double cellMeters = defaultRepeatCellMeters,
  double toleranceMeters = defaultRepeatToleranceMeters,
  double minGapMeters = defaultMinGapMeters,
}) {
  final int count = lngLatPairs.length ~/ 2;
  final Uint8List flags = Uint8List(count);
  if (count < 2 || cellMeters <= 0 || toleranceMeters < 0 || minGapMeters < 0) return flags;
  final Uint8List candidatesByPoint = Uint8List(count);

  // One position without a fix would otherwise spread NaN through the grid and
  // throw away the classification of the whole track.
  double latitudeSum = 0;
  var latitudeCount = 0;
  for (var i = 0; i < count; i++) {
    final double lat = lngLatPairs[i * 2 + 1];
    if (!lat.isFinite) continue;
    latitudeSum += lat;
    latitudeCount++;
  }
  final double centreLatitude = latitudeCount == 0 ? 0 : latitudeSum / latitudeCount;
  final double metresPerDegreeLng = _metresPerDegreeLongitude(centreLatitude);

  // Cumulative travel, so the minimum gap is a distance the tracker's reporting
  // interval cannot stretch. A step to or from a position without a fix adds
  // nothing, which keeps the series monotonic.
  final Float64List travelled = Float64List(count);
  for (var i = 1; i < count; i++) {
    final double lng1 = lngLatPairs[(i - 1) * 2];
    final double lat1 = lngLatPairs[(i - 1) * 2 + 1];
    final double lng2 = lngLatPairs[i * 2];
    final double lat2 = lngLatPairs[i * 2 + 1];
    travelled[i] = travelled[i - 1] + (lng1.isFinite && lat1.isFinite && lng2.isFinite && lat2.isFinite ? _metresBetween(lng1, lat1, lng2, lat2) : 0);
  }

  int cellX(double lng) => (lng * metresPerDegreeLng / cellMeters).floor();
  int cellY(double lat) => (lat * _metresPerDegreeLat / cellMeters).floor();
  int key(int x, int y) => x * 1000003 + y;

  // Four doubles per piece: startLng, startLat, endLng, endLat.
  final List<double> pieces = <double>[];

  // A bucket holds piece indices, not segment start indices.
  final Map<int, List<int>> buckets = <int, List<int>>{};

  double chordMeters(int at) {
    if (at < 0 || at + 1 >= count) return 0;
    final double lng1 = lngLatPairs[at * 2];
    final double lat1 = lngLatPairs[at * 2 + 1];
    final double lng2 = lngLatPairs[(at + 1) * 2];
    final double lat2 = lngLatPairs[(at + 1) * 2 + 1];
    // An immeasurable neighbour switches the gap test off rather than making it
    // fire on every segment beside a position without a fix.
    if (!lng1.isFinite || !lat1.isFinite || !lng2.isFinite || !lat2.isFinite) return double.infinity;
    return _metresBetween(lng1, lat1, lng2, lat2);
  }

  // The shorter of the two chords that carry spacing evidence. A jump is
  // preceded or followed by an ordinary step, so the shorter side is the
  // yardstick; a real sparse stretch is long on both sides and stays indexed.
  double shortestPlausibleNeighbour(int start) {
    var shortest = double.infinity;
    for (final int k in <int>[start - 1, start + 1]) {
      final double chord = chordMeters(k);
      if (!chord.isFinite || chord < _minSpacingEvidenceMeters) continue;
      if (chord < shortest) shortest = chord;
    }
    return shortest.isFinite ? shortest : 0;
  }

  void indexSegment(int start) {
    final double lng1 = lngLatPairs[start * 2];
    final double lat1 = lngLatPairs[start * 2 + 1];
    final double lng2 = lngLatPairs[(start + 1) * 2];
    final double lat2 = lngLatPairs[(start + 1) * 2 + 1];
    if (!lng1.isFinite || !lat1.isFinite || !lng2.isFinite || !lat2.isFinite) return;

    final double lengthMeters = _metresBetween(lng1, lat1, lng2, lat2);
    if (lengthMeters > _maxIndexedSegmentMeters) return;
    final double plausibleNeighbour = shortestPlausibleNeighbour(start);
    if (plausibleNeighbour > 0 && lengthMeters > _gapRatio * plausibleNeighbour) return;

    // Splitting replaces the old "skip any segment over 200 m" guard and the old
    // 256-cell bounding-box guard: pieces cap the buckets one long chord
    // touches, so a sparse recording is indexed instead of dropped.
    final int piecesCount = math.max(1, (lengthMeters / cellMeters).ceil());
    for (var k = 0; k < piecesCount; k++) {
      final double t0 = k / piecesCount;
      final double t1 = (k + 1) / piecesCount;
      final double startLng = lng1 + (lng2 - lng1) * t0;
      final double startLat = lat1 + (lat2 - lat1) * t0;
      final double endLng = lng1 + (lng2 - lng1) * t1;
      final double endLat = lat1 + (lat2 - lat1) * t1;
      final int piece = pieces.length ~/ 4;
      pieces.addAll(<double>[startLng, startLat, endLng, endLat]);

      final int minX = cellX(math.min(startLng, endLng));
      final int maxX = cellX(math.max(startLng, endLng));
      final int minY = cellY(math.min(startLat, endLat));
      final int maxY = cellY(math.max(startLat, endLat));
      for (var x = minX; x <= maxX; x++) {
        for (var y = minY; y <= maxY; y++) {
          (buckets[key(x, y)] ??= <int>[]).add(piece);
        }
      }
    }
  }

  int nextEnd = 1;
  for (var i = 0; i < count; i++) {
    // Index every segment whose end is at least minGapMeters of travel behind
    // this point. The window only moves forward, so each segment is indexed once.
    final double limit = travelled[i] - minGapMeters;
    while (nextEnd < count && travelled[nextEnd] <= limit) {
      indexSegment(nextEnd - 1);
      nextEnd++;
    }

    final double lng = lngLatPairs[i * 2];
    final double lat = lngLatPairs[i * 2 + 1];
    if (!lng.isFinite || !lat.isFinite) {
      candidatesByPoint[i] = 0;
      continue;
    }
    final int cx = cellX(lng);
    final int cy = cellY(lat);
    bool repeat = false;
    final Set<int> checkedPieces = <int>{};

    // With 40 m cells and a 30 m threshold, a 3x3 probe covers every piece that
    // can be within tolerance. The exact distance check remains 30 m.
    for (var dx = -1; dx <= 1 && !repeat; dx++) {
      for (var dy = -1; dy <= 1 && !repeat; dy++) {
        final List<int>? candidates = buckets[key(cx + dx, cy + dy)];
        if (candidates == null) continue;
        for (final int piece in candidates) {
          if (!checkedPieces.add(piece)) continue;
          final double distance = _pointToSegmentMeters(lng, lat, pieces[piece * 4], pieces[piece * 4 + 1], pieces[piece * 4 + 2], pieces[piece * 4 + 3], centreLatitude);
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
