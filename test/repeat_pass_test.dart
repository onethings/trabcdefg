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

  // A tracker with a moving vehicle sends a position every few hundred metres,
  // not every few metres. The 200 m segment guard used to drop those segments,
  // so the return pass stayed in the first-pass colour on a real recording.
  group('a real tracker reports every few hundred metres', () {
    test('the return of a 300 m sampled out-and-back is a repeat', () {
      final List<List<double>> out = _leg(121.5, _lat, metresEast: 3000, metresNorth: 0, samples: 10);
      final List<List<double>> back = out.reversed.toList();
      final Uint8List flags = classifyRepeatPasses(_track([...out, ...back.skip(1)]));

      final int backFlags = flags.sublist(out.length).reduce((a, b) => a + b);
      expect(backFlags, greaterThan((back.length - 1) * 0.8), reason: 'the return trip is a repeat');
    });

    test('the return of a 500 m sampled out-and-back is a repeat', () {
      final List<List<double>> out = _leg(121.5, _lat, metresEast: 3000, metresNorth: 0, samples: 6);
      final List<List<double>> back = out.reversed.toList();
      final Uint8List flags = classifyRepeatPasses(_track([...out, ...back.skip(1)]));

      final int backFlags = flags.sublist(out.length).reduce((a, b) => a + b);
      expect(backFlags, greaterThan((back.length - 1) * 0.8), reason: 'the return trip is a repeat');
    });

    // 150 m is inside the old 200 m index guard, so this isolates the
    // sample-count gap: ten samples is 1.5 km of travel, not 100 m.
    test('the whole return is marked at 150 m spacing', () {
      final List<List<double>> out = _leg(121.5, _lat, metresEast: 3000, metresNorth: 0, samples: 20);
      final List<List<double>> back = out.reversed.toList();
      final Uint8List flags = classifyRepeatPasses(_track([...out, ...back.skip(1)]));

      final int backFlags = flags.sublist(out.length).reduce((a, b) => a + b);
      expect(backFlags, greaterThan((back.length - 1) * 0.8), reason: 'the return trip is a repeat');
    });

    test('a divided carriageway 20 m away is the same road at 250 m spacing', () {
      final List<List<double>> out = _leg(121.5, _lat, metresEast: 2500, metresNorth: 0, samples: 10);
      final List<List<double>> back = _leg(121.5, _lat + 20 / _mPerDegLat, metresEast: 2500, metresNorth: 0, samples: 10).reversed.toList();
      final Uint8List flags = classifyRepeatPasses(_track([...out, ...back.skip(1)]));

      final int backFlags = flags.sublist(out.length).reduce((a, b) => a + b);
      expect(backFlags, greaterThan((back.length - 1) * 0.5), reason: 'the other lane is the same road');
    });

    test('a loop along the same street marks every later pass', () {
      final List<List<double>> ab = _leg(121.5, _lat, metresEast: 2500, metresNorth: 0, samples: 10);
      final List<List<double>> ba = ab.reversed.toList();
      final List<List<double>> ac = _leg(121.5, _lat, metresEast: 1800, metresNorth: 0, samples: 7);
      final Uint8List flags = classifyRepeatPasses(_track([...ab, ...ba.skip(1), ...ac.skip(1)]));

      final int acFlags = flags.sublist(ab.length + ba.length - 1).reduce((a, b) => a + b);
      expect(acFlags, greaterThan((ac.length - 1) * 0.8), reason: 'the street was driven before');
    });

    test('a position without a fix is never a repeat and does not break the pass', () {
      final List<List<double>> out = _leg(121.5, _lat, metresEast: 1200, metresNorth: 0, samples: 12);
      final List<List<double>> back = out.reversed.toList();
      final List<List<double>> track = [...out, ...back.skip(1)];
      final int missing = track.length ~/ 2;
      track[missing] = [double.nan, double.nan];
      final Uint8List flags = classifyRepeatPasses(_track(track));

      expect(flags[missing], 0, reason: 'a missing fix is not a repeat');
      expect(flags.where((f) => f == 1).length, greaterThan(0), reason: 'the rest of the return is still marked');
    });
  });

  // A GPS fix that jumps away and back is a recording artifact, not a road.
  // The straight line between the jump's ends cuts across the map, and indexing
  // it colours every road that line crosses. The 2026-11 jammer exports show
  // this shape: a fix 4 km away, then a fix back, with ordinary steps either
  // side, so the old longer-neighbour rule let both chords into the index.
  group('a jump in the recording is not a road', () {
    test('the straight line of a jump out and back is not indexed', () {
      final List<List<double>> road = _leg(121.5, _lat, metresEast: 0, metresNorth: 2000, samples: 400);
      final List<double> far = road.last;
      final List<List<double>> spiked = <List<double>>[
        ...road,
        [far[0] + 3000 / _mPerDegLng, far[1]],
        far,
      ];
      // Later the vehicle drives the line the jump's chord crossed.
      final List<List<double>> crossed = <List<double>>[
        for (var i = 0; i <= 600; i++) [far[0] + (3000 * i / 600) / _mPerDegLng, far[1]],
      ];
      final Uint8List flags = classifyRepeatPasses(_track([...spiked, ...crossed.skip(1)]));
      final int firstFlagged = flags.sublist(spiked.length + 20).where((int f) => f == 1).length;
      expect(firstFlagged, 0, reason: 'a jump chord is not road geometry');
    });

    test('a genuinely sparse stretch is long on both sides and stays indexed', () {
      final List<List<double>> dense = _leg(121.5, _lat, metresEast: 0, metresNorth: 60, samples: 12);
      final List<List<double>> sparse = <List<double>>[
        for (var i = 0; i <= 6; i++) [dense.last[0], dense.last[1] + (600 * i / 6) / _mPerDegLat],
      ];
      final List<List<double>> back = sparse.reversed.toList();
      final Uint8List flags = classifyRepeatPasses(_track([...dense, ...sparse.skip(1), ...back.skip(1)]));
      final int backFlags = flags.sublist(dense.length + sparse.length - 1).where((int f) => f == 1).length;
      expect(backFlags, greaterThan((back.length - 1) * 0.8), reason: 'a sparse road is still a road');
    });

    test('a parked burst is not spacing evidence for the first step out', () {
      final List<List<double>> parked = <List<double>>[
        for (var i = 0; i < 20; i++) [121.5, _lat],
      ];
      final List<List<double>> out = _leg(121.5, _lat, metresEast: 400, metresNorth: 0, samples: 40);
      final List<List<double>> back = out.reversed.toList();
      final Uint8List flags = classifyRepeatPasses(_track([...parked, ...out.skip(1), ...back.skip(1)]));
      final int backFlags = flags.sublist(parked.length + out.length - 1).where((int f) => f == 1).length;
      expect(backFlags, greaterThan((back.length - 1) * 0.8), reason: 'the parked duplicate chords are not spacing evidence');
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
