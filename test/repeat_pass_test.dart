import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/utils/repeat_pass.dart';

const double _lat = 25.033;
const double _mPerDegLat = 110574.0;
// One degree of longitude at the test latitude.
final double _mPerDegLng = 111320.0 * math.cos(_lat * math.pi / 180);

Float64List _track(List<List<double>> lngLat) {
  final Float64List packed = Float64List(lngLat.length * 2);
  for (var i = 0; i < lngLat.length; i++) {
    packed[i * 2] = lngLat[i][0];
    packed[i * 2 + 1] = lngLat[i][1];
  }
  return packed;
}

/// A straight leg north-east from [lng0], [lat0] covering [metresEast] and
/// [metresNorth], sampled every [step] metres.
List<List<double>> _leg(double lng0, double lat0, {required double metresEast, required double metresNorth, int samples = 40}) {
  return [
    for (var i = 0; i <= samples; i++)
      [lng0 + (metresEast * i / samples) / _mPerDegLng, lat0 + (metresNorth * i / samples) / _mPerDegLat],
  ];
}

void main() {
  group('the same road twice', () {
    test('driving out and back over the same street marks the return', () {
      final List<List<double>> out = _leg(121.5, _lat, metresEast: 400, metresNorth: 0);
      final List<List<double>> back = out.reversed.toList();
      final Uint8List flags = classifyRepeatPasses(_track([...out, ...back.skip(1)]));

      final int outFlags = flags.sublist(0, out.length).reduce((a, b) => a + b);
      final int backFlags = flags.sublist(out.length).reduce((a, b) => a + b);
      expect(outFlags, 0, reason: 'the first pass is first');
      expect(backFlags, greaterThan(back.length * 0.8), reason: 'the return trip is a repeat');
    });

    test('a track shorter than the sample gap is never a repeat of itself', () {
      final Float64List shortTrack = _track(_leg(121.5, _lat, metresEast: 60, metresNorth: 0, samples: 5));
      expect(classifyRepeatPasses(shortTrack).any((f) => f == 1), isFalse);
    });
  });

  group('a different road is not the same road', () {
    test('a parallel street 45 m away stays a first pass', () {
      final List<List<double>> first = _leg(121.5, _lat, metresEast: 400, metresNorth: 0);
      final List<List<double>> parallel = _leg(121.5, _lat + 45 / _mPerDegLat, metresEast: 400, metresNorth: 0, samples: 30);
      final Uint8List flags = classifyRepeatPasses(_track([...first, ...parallel]));
      expect(flags.sublist(first.length).any((f) => f == 1), isFalse);
    });

    test('an opposite carriageway 12 m away counts as the same road', () {
      final List<List<double>> first = _leg(121.5, _lat, metresEast: 400, metresNorth: 0);
      final List<List<double>> other = _leg(121.5, _lat + 12 / _mPerDegLat, metresEast: 400, metresNorth: 0, samples: 30);
      final Uint8List flags = classifyRepeatPasses(_track([...first, ...other]));
      expect(flags.sublist(first.length).any((f) => f == 1), isTrue);
    });
  });

  group('the classification does not depend on where it is used', () {
    test('the tolerance is metres, so the same street reads the same far north', () {
      // Same geometry at 60 degrees north: 45 m of separation must still be a
      // different street, even though a degree of longitude is half as wide.
      const double oslo = 59.91;
      final double mPerDegLngOslo = 111320.0 * 0.5015;
      final List<List<double>> first = [
        for (var i = 0; i <= 40; i++) [10.75 + (400 * i / 40) / mPerDegLngOslo, oslo],
      ];
      final List<List<double>> parallel = [
        for (var i = 0; i <= 30; i++) [10.75 + (400 * i / 30) / mPerDegLngOslo, oslo + 45 / _mPerDegLat],
      ];
      final Uint8List flags = classifyRepeatPasses(_track([...first, ...parallel]));
      expect(flags.sublist(first.length).any((f) => f == 1), isFalse);
    });

    test('the same geometry at the equator also stays a different street', () {
      const double equator = 0.0;
      final List<List<double>> first = [
        for (var i = 0; i <= 40; i++) [10.0 + (400 * i / 40) / 111320.0, equator],
      ];
      final List<List<double>> parallel = [
        for (var i = 0; i <= 30; i++) [10.0 + (400 * i / 30) / 111320.0, equator + 45 / _mPerDegLat],
      ];
      final Uint8List flags = classifyRepeatPasses(_track([...first, ...parallel]));
      expect(flags.sublist(first.length).any((f) => f == 1), isFalse);
    });
  });

  group('cost', () {
    test('one pass classifies a long track quickly enough to run at load', () {
      final List<List<double>> street = _leg(121.5, _lat, metresEast: 20000, metresNorth: 0, samples: 40000);
      final List<List<double>> returnLeg = street.reversed.toList();
      final Float64List track = _track([...street, ...returnLeg.skip(1)]);

      final Stopwatch watch = Stopwatch()..start();
      final Uint8List flags = classifyRepeatPasses(track);
      watch.stop();

      expect(flags.length, track.length ~/ 2);
      expect(watch.elapsedMilliseconds, lessThan(2000), reason: '80k points, once per track load');
    });
  });
}
