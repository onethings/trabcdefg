// Plain-Dart harness for the repeat-pass classifier. Runs without Flutter so the
// classification and its cost can be measured on the bare Dart VM.
//
//   dart scripts/repeat_pass_probe.dart

import 'dart:typed_data';

import '../lib/src/utils/repeat_pass.dart';

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

  // 5. cost on realistic and dense tracks
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
    print('TIME  $name: ${watch.elapsedMilliseconds} ms, repeat on return=${repeat}/${backward.length - 1}');
    if (watch.elapsedMilliseconds > 3000) failures++;
  }

  print(failures == 0 ? 'ALL PASS' : '$failures FAILURES');
}
