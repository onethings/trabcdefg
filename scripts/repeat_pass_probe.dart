// Plain-Dart harness for the repeat-pass classifier. Runs without Flutter so the
// classification and its cost can be measured on the bare Dart VM.
//
// A real tracker reports a position every few hundred metres while the vehicle
// moves, not every few metres. The first checks use dense synthetic tracks; the
// sparse ones use the spacing of a real recording, because a classifier that
// only works on dense samples is what left the history screen partly purple.
//
//   dart scripts/repeat_pass_probe.dart

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:trabcdefg/src/utils/repeat_pass.dart';

const double lat0 = 25.033;
const double mPerDegLat = 110574.0;
final double mPerDegLng = 111320.0 * _cosDeg(lat0);

double _cosDeg(double degrees) {
  const double r = 0.017453292519943295;
  final double x = degrees * r;
  return 1 - x * x / 2 + x * x * x * x / 24 - x * x * x * x * x * x / 720;
}

Float64List pack(List<List<double>> lngLat) {
  final Float64List out = Float64List(lngLat.length * 2);
  for (var i = 0; i < lngLat.length; i++) {
    out[i * 2] = lngLat[i][0];
    out[i * 2 + 1] = lngLat[i][1];
  }
  return out;
}

List<List<double>> leg(double lng, double lat, {required double east, required double north, double stepMetres = 5, double mPerLng = 0, int? samples}) {
  final double perLng = mPerLng == 0 ? mPerDegLng : mPerLng;
  final int n = samples ?? (east / stepMetres).ceil();
  return [
    for (var i = 0; i <= n; i++) [lng + (east * i / n) / perLng, lat + (north * i / n) / mPerDegLat],
  ];
}

int countFlags(Uint8List f, int from, [int? to]) {
  final int end = to ?? f.length;
  var c = 0;
  for (var i = from; i < end; i++) {
    if (f[i] == 1) c++;
  }
  return c;
}

void check(String label, bool ok, String detail) {
  print('${ok ? 'PASS' : 'FAIL'}  $label  $detail');
  if (!ok) failures++;
}

var failures = 0;

/// Mirrors the classifier's default; kept local so the harness still compiles
/// against the sample-count version it has to fail on.
const double probeMinGapMeters = 100;

/// The same contract computed the slow, obvious way: every candidate segment is
/// tested, nothing is bucketed or split into pieces. A grid or piece fault then
/// shows up as a flag difference instead of a plausible-looking line. The rules
/// themselves (metre gap, recording-gap guard) are restated here deliberately,
/// so a change to them has to be made in both places.
const double _probeMaxIndexedSegmentMeters = 10000;
const double _probeGapRatio = 10;
const double _probeMinSpacingEvidenceMeters = 1;

Uint8List referenceFlags(Float64List lngLatPairs, {double cellMeters = defaultRepeatCellMeters, double toleranceMeters = defaultRepeatToleranceMeters, double minGapMeters = probeMinGapMeters}) {
  final int count = lngLatPairs.length ~/ 2;
  final Uint8List candidates = Uint8List(count);
  if (count < 2) return candidates;

  double latitudeSum = 0;
  var latitudeCount = 0;
  for (var i = 0; i < count; i++) {
    final double lat = lngLatPairs[i * 2 + 1];
    if (!lat.isFinite) continue;
    latitudeSum += lat;
    latitudeCount++;
  }
  final double centreLatitude = latitudeCount == 0 ? 0 : latitudeSum / latitudeCount;

  double chordMeters(int at) {
    if (at < 0 || at + 1 >= count) return 0;
    if (!_finiteAt(lngLatPairs, at) || !_finiteAt(lngLatPairs, at + 1)) return double.infinity;
    return _metresBetween(lngLatPairs, at, at + 1);
  }

  // Mirrors the shipped shortest-plausible-neighbour rule: the shorter chord
  // with spacing evidence is the yardstick for a jump.
  double shortestPlausibleNeighbour(int start) {
    var shortest = double.infinity;
    for (final int k in <int>[start - 1, start + 1]) {
      final double chord = chordMeters(k);
      if (!chord.isFinite || chord < _probeMinSpacingEvidenceMeters) continue;
      if (chord < shortest) shortest = chord;
    }
    return shortest.isFinite ? shortest : 0;
  }

  final List<double> travelled = List<double>.filled(count, 0);
  for (var i = 1; i < count; i++) {
    travelled[i] = travelled[i - 1] + (_finiteAt(lngLatPairs, i - 1) && _finiteAt(lngLatPairs, i) ? _metresBetween(lngLatPairs, i - 1, i) : 0);
  }

  for (var i = 0; i < count; i++) {
    if (!_finiteAt(lngLatPairs, i)) continue;
    for (var start = 0; start + 1 < count; start++) {
      if (travelled[start + 1] > travelled[i] - minGapMeters) break;
      if (!_finiteAt(lngLatPairs, start) || !_finiteAt(lngLatPairs, start + 1)) continue;
      final double lengthMeters = _metresBetween(lngLatPairs, start, start + 1);
      if (lengthMeters > _probeMaxIndexedSegmentMeters) continue;
      final double plausibleNeighbour = shortestPlausibleNeighbour(start);
      if (plausibleNeighbour > 0 && lengthMeters > _probeGapRatio * plausibleNeighbour) continue;
      if (_pointToSegment(lngLatPairs, i, start, start + 1, centreLatitude) <= toleranceMeters) {
        candidates[i] = 1;
        break;
      }
    }
  }

  final Uint8List flags = Uint8List(count);
  for (var i = 0; i < count; i++) {
    if (candidates[i] == 0) continue;
    final bool neighbour = (i > 0 && candidates[i - 1] == 1) || (i + 1 < count && candidates[i + 1] == 1);
    if (neighbour) flags[i] = 1;
  }
  return flags;
}

bool _finiteAt(Float64List pairs, int i) => pairs[i * 2].isFinite && pairs[i * 2 + 1].isFinite;

double _metresBetween(Float64List pairs, int a, int b) {
  const double radiansPerDegree = 0.017453292519943295;
  final double dLat = (pairs[b * 2 + 1] - pairs[a * 2 + 1]) * radiansPerDegree;
  final double dLng = (pairs[b * 2] - pairs[a * 2]) * radiansPerDegree;
  final double h = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(pairs[a * 2 + 1] * radiansPerDegree) * math.cos(pairs[b * 2 + 1] * radiansPerDegree) * math.sin(dLng / 2) * math.sin(dLng / 2);
  if (h.isNaN) return 0;
  return 2 * 6371000 * math.asin(math.sqrt(h));
}

double _pointToSegment(Float64List pairs, int point, int start, int end, double referenceLatitude) {
  final double mx = 111320.0 * math.cos(referenceLatitude * math.pi / 180);
  final double px = (pairs[point * 2] - pairs[start * 2]) * mx;
  final double py = (pairs[point * 2 + 1] - pairs[start * 2 + 1]) * mPerDegLat;
  final double ex = (pairs[end * 2] - pairs[start * 2]) * mx;
  final double ey = (pairs[end * 2 + 1] - pairs[start * 2 + 1]) * mPerDegLat;
  final double lengthSquared = ex * ex + ey * ey;
  if (lengthSquared == 0) return math.sqrt(px * px + py * py);
  final double t = ((px * ex + py * ey) / lengthSquared).clamp(0.0, 1.0).toDouble();
  final double dx = px - t * ex;
  final double dy = py - t * ey;
  return math.sqrt(dx * dx + dy * dy);
}

/// A random walk that revisits its own street: every step picks a heading, and
/// occasionally it walks back over the last few steps instead. Steps span
/// [minStepMeters, maxStepMeters], so the same check covers a dense recording
/// and the few-hundred-metre spacing of a real tracker.
List<List<double>> randomTrack(math.Random rng, {int steps = 120, int returns = 6, double minStepMeters = 20, double maxStepMeters = 300}) {
  final List<List<double>> points = <List<double>>[
    [121.5, lat0],
  ];
  double heading = rng.nextDouble() * 2 * math.pi;
  for (var s = 0; s < steps; s++) {
    if (returns > 0 && points.length >= 3 && rng.nextDouble() < 0.03) {
      returns--;
      final int span = math.min(6, points.length - 2);
      final int from = points.length - 1 - span;
      for (var k = 0; k <= span; k++) {
        points.add([points[from + k][0], points[from + k][1]]);
      }
      continue;
    }
    heading += (rng.nextDouble() - 0.5) * 0.9;
    final double step = minStepMeters + rng.nextDouble() * (maxStepMeters - minStepMeters);
    final List<double> last = points.last;
    points.add([last[0] + math.cos(heading) * step / mPerDegLng, last[1] + math.sin(heading) * step / mPerDegLat]);
  }
  return points;
}

/// Differential check: the fast classifier and the reference must flag exactly
/// the same points, including on tracks with positions that have no fix.
void differentialChecks() {
  final math.Random rng = math.Random(11);
  var compared = 0;
  var mismatches = 0;
  for (var t = 0; t < 80; t++) {
    // The first half walks in dense steps, the second half in the steps a
    // tracker actually reports while the vehicle moves.
    final List<List<double>> track = t < 40 ? randomTrack(rng) : randomTrack(rng, steps: 60, minStepMeters: 200, maxStepMeters: 600);
    if (t.isEven) {
      track[3 + t % 5] = [double.nan, double.nan];
    }
    final Float64List packed = pack(track);
    late final Uint8List fast;
    try {
      fast = classifyRepeatPasses(packed);
    } catch (error) {
      mismatches++;
      print('THROW track=$t $error');
      continue;
    }
    final Uint8List slow = referenceFlags(packed);
    for (var i = 0; i < fast.length; i++) {
      compared++;
      if (fast[i] != slow[i]) {
        mismatches++;
        print('MISMATCH track=$t point=$i fast=${fast[i]} reference=${slow[i]}');
      }
    }
  }
  check('random tracks agree with the reference classifier', mismatches == 0, '$compared flags, $mismatches mismatches (a throw counts as a mismatch)');
}

void main() {
  // 1. out and back on the same street
  final out = leg(121.5, lat0, east: 400, north: 0, stepMetres: 5);
  final back = out.reversed.toList();
  final flagsOutBack = classifyRepeatPasses(pack([...out, ...back.skip(1)]));
  final outRepeat = countFlags(flagsOutBack, 0, out.length);
  final backRepeat = countFlags(flagsOutBack, out.length);
  final backTotal = back.length - 1;
  check('out and back: first pass clean', outRepeat == 0, 'repeat=$outRepeat of ${out.length}');
  check('out and back: return trip repeats', backRepeat > backTotal * 0.8, 'repeat=$backRepeat of $backTotal');

  // 2. parallel street 45 m away must stay first pass, at three latitudes
  for (final entry in [
    ['taipei 25N', lat0, mPerDegLng],
    ['oslo 60N', 59.91, 111320.0 * 0.5015],
    ['equator', 0.0, 111320.0],
  ]) {
    final String name = entry[0] as String;
    final double lat = entry[1] as double;
    final double perLng = entry[2] as double;
    final a = leg(121.5, lat, east: 400, north: 0, stepMetres: 5, mPerLng: perLng);
    final b = leg(121.5, lat + 45 / mPerDegLat, east: 400, north: 0, stepMetres: 5, mPerLng: perLng);
    final f = classifyRepeatPasses(pack([...a, ...b]));
    final repeat = countFlags(f, a.length);
    check('parallel 45m is a different street ($name)', repeat == 0, 'repeat=$repeat of ${b.length}');
  }

  // 3. opposite carriageway 12 m away counts as the same road
  final a3 = leg(121.5, lat0, east: 400, north: 0, stepMetres: 5);
  final b3 = leg(121.5, lat0 + 12 / mPerDegLat, east: 400, north: 0, stepMetres: 5);
  final f3 = classifyRepeatPasses(pack([...a3, ...b3]));
  final r3 = countFlags(f3, a3.length);
  check('opposite carriageway 12m counts as the same road', r3 > b3.length * 0.5, 'repeat=$r3 of ${b3.length}');

  // 4. short track never repeats itself
  final short = leg(121.5, lat0, east: 60, north: 0, stepMetres: 5);
  final f4 = classifyRepeatPasses(pack(short));
  check('short track never repeats itself', countFlags(f4, 0) == 0, 'points=${short.length}');

  // 5. sparse samples, the way a real tracker reports while moving. The
  //    return pass must still read as a repeat at any of these spacings.
  for (final strided in [
    ['300 m samples', 300.0],
    ['500 m samples', 500.0],
  ]) {
    final String name = strided[0] as String;
    final double step = strided[1] as double;
    final o = leg(121.5, lat0, east: 3000, north: 0, stepMetres: step);
    final b = o.reversed.toList();
    final f = classifyRepeatPasses(pack([...o, ...b.skip(1)]));
    final total = b.length - 1;
    final repeat = countFlags(f, o.length);
    check('out and back with $name marks the return', repeat > total * 0.8, 'repeat=$repeat of $total');
  }

  // 150 m samples are inside the old 200 m index guard, so this isolates the
  // sample-count gap: 10 samples is 1.5 km of travel, not 100 m.
  {
    final o = leg(121.5, lat0, east: 3000, north: 0, stepMetres: 150);
    final b = o.reversed.toList();
    final f = classifyRepeatPasses(pack([...o, ...b.skip(1)]));
    final total = b.length - 1;
    final repeat = countFlags(f, o.length);
    check('150 m samples: the whole return is marked', repeat > total * 0.8, 'repeat=$repeat of $total');
  }

  // 6. a divided carriageway driven the other way, with sparse samples
  {
    final o = leg(121.5, lat0, east: 2500, north: 0, stepMetres: 250);
    final b = leg(121.5, lat0 + 20 / mPerDegLat, east: 2500, north: 0, stepMetres: 250).reversed.toList();
    final f = classifyRepeatPasses(pack([...o, ...b.skip(1)]));
    final repeat = countFlags(f, o.length);
    check('divided carriageway, 250 m samples', repeat > (b.length - 1) * 0.5, 'repeat=$repeat of ${b.length - 1}');
  }

  // 7. a loop that comes back along the same street: A -> B -> A -> C
  {
    final ab = leg(121.5, lat0, east: 2500, north: 0, stepMetres: 250);
    final ba = ab.reversed.toList();
    final ac = leg(121.5, lat0, east: 1800, north: 0, stepMetres: 250);
    final f = classifyRepeatPasses(pack([...ab, ...ba.skip(1), ...ac.skip(1)]));
    final start = ab.length + ba.length - 1;
    final repeat = countFlags(f, start);
    final total = ac.length - 1;
    check('loop A->B->A->C marks the A->C leg', repeat > total * 0.8, 'repeat=$repeat of $total');
  }

  // 8. the same classification as a slow reference on random tracks
  differentialChecks();

  // 9. cost on realistic and dense tracks
  for (final spec in [
    ['20k points, 5 m apart (100 km out and back)', 20000, 5.0],
    ['80k points, 0.5 m apart (dense)', 80000, 0.5],
  ]) {
    final String name = spec[0] as String;
    final int n = spec[1] as int;
    final double step = spec[2] as double;
    final forward = leg(121.5, lat0, east: n * step / 2, north: 0, stepMetres: step, samples: n ~/ 2);
    final backward = forward.reversed.toList();
    final Float64List track = pack([...forward, ...backward.skip(1)]);
    final watch = Stopwatch()..start();
    final flags = classifyRepeatPasses(track);
    watch.stop();
    final repeat = countFlags(flags, forward.length);
    print('TIME  $name: ${watch.elapsedMilliseconds} ms, repeat on return=$repeat/${backward.length - 1}');
    if (watch.elapsedMilliseconds > 3000) failures++;
  }

  print(failures == 0 ? 'ALL PASS' : '$failures FAILURES');
}
