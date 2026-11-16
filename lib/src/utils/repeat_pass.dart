// Which points of a track the vehicle had already driven.
//
// The played line colours a second pass over the same road differently from the
// first. That is a property of the whole track, not of the moment being drawn, so
// it is classified once per track and read per point afterwards. Classifying
// inside the playback loop made one push cost a pass over everything played so
// far, which grows to a quadratic total and also made the colour of a stretch
// depend on how far the playback had got.
//
// The grid is a metre grid. A fixed number of degrees is not a fixed distance:
// 0.0002 degrees of longitude is 20 m at the latitude of Taiwan and 11 m at the
// latitude of Oslo, so a degree grid silently changes its tolerance with place.
// Neighbouring cells are only a lookup accelerator here; the decision is made on
// real distance, which keeps the tolerance from growing by a whole cell on every
// side and claiming a parallel road as the same one.

import 'dart:math' as math;
import 'dart:typed_data';

/// Grid cell, in metres. Small enough that a bucket holds few points, large
/// enough that the nine-cell probe still covers the tolerance.
const double defaultRepeatCellMeters = 20;

/// How close two points must be to count as the same piece of road. Roughly a
/// road width plus GPS noise.
const double defaultRepeatToleranceMeters = 20;

/// Points this close together in the track are the same sample of the same
/// street, not a return to it. Without this every point would repeat the one
/// before it.
const int defaultMinIndexGap = 10;

/// Flags for each point of [lngLatPairs], 1 where the vehicle had already been
/// within [toleranceMeters] of that spot at least [minIndexGap] points earlier.
///
/// [lngLatPairs] holds longitude, latitude, longitude, latitude, and so on.
Uint8List classifyRepeatPasses(
  Float64List lngLatPairs, {
  double cellMeters = defaultRepeatCellMeters,
  double toleranceMeters = defaultRepeatToleranceMeters,
  int minIndexGap = defaultMinIndexGap,
}) {
  final int count = lngLatPairs.length ~/ 2;
  final Uint8List flags = Uint8List(count);
  if (count == 0) return flags;

  double latitudeSum = 0;
  for (var i = 0; i < count; i++) {
    latitudeSum += lngLatPairs[i * 2 + 1];
  }
  final double centreLatitude = latitudeSum / count;
  final double metresPerDegreeLng = _metresPerDegreeLongitude(centreLatitude);

  int cellKeyAt(double lng, double lat) {
    final int cellX = (lng * metresPerDegreeLng / cellMeters).round();
    final int cellY = (lat * _metresPerDegreeLat / cellMeters).round();
    return cellX * 1000003 + cellY;
  }

  final Map<int, List<int>> buckets = <int, List<int>>{};

  for (var i = 0; i < count; i++) {
    final double lng = lngLatPairs[i * 2];
    final double lat = lngLatPairs[i * 2 + 1];
    final int cellX = (lng * metresPerDegreeLng / cellMeters).round();
    final int cellY = (lat * _metresPerDegreeLat / cellMeters).round();

    bool repeat = false;
    for (var dx = -1; dx <= 1 && !repeat; dx++) {
      for (var dy = -1; dy <= 1 && !repeat; dy++) {
        final List<int>? bucket = buckets[(cellX + dx) * 1000003 + (cellY + dy)];
        if (bucket == null) continue;
        for (final int j in bucket) {
          if (i - j < minIndexGap) continue;
          if (_metresBetween(lng, lat, lngLatPairs[j * 2], lngLatPairs[j * 2 + 1]) <= toleranceMeters) {
            repeat = true;
            break;
          }
        }
      }
    }

    flags[i] = repeat ? 1 : 0;
    (buckets[cellKeyAt(lng, lat)] ??= <int>[]).add(i);
  }

  return flags;
}

const double _metresPerDegreeLat = 110574.0;

double _metresPerDegreeLongitude(double latitude) => 111320.0 * math.cos(latitude * math.pi / 180);

/// Great-circle distance in metres.
double _metresBetween(double lng1, double lat1, double lng2, double lat2) {
  const double radiansPerDegree = 0.017453292519943295;
  final double dLat = (lat2 - lat1) * radiansPerDegree;
  final double dLng = (lng2 - lng1) * radiansPerDegree;
  final double a = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1 * radiansPerDegree) * math.cos(lat2 * radiansPerDegree) * math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371000 * math.asin(math.sqrt(a));
}
