// A recorded out-and-back from a real tracker export, not a synthetic line.
//
// Positions(4) of the fleet export tracks one vehicle: it drives north along a
// road, works its way over a loop, and comes back south over the same road 1.4
// km later. The KML fixture is that slice of the recording, so it carries the
// sample spacing (about 50 m) and the GPS offsets of the original device. The
// 30 m tolerance and the 100 m travel gap decide this case in the field, and
// this test keeps them deciding it the same way.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/utils/repeat_pass.dart';

/// The outbound run, and the return run that retraces it, as indices into the
/// fixture. The outbound is abs 265..277 of the source recording, the return
/// abs 353..369.
const int outboundStart = 15;
const int outboundEnd = 27;
const int returnStart = 103;
const int returnEnd = 119;

Float64List _packKml(String text) {
  final RegExpMatch match = RegExp(r'<coordinates>([\s\S]*?)</coordinates>').firstMatch(text)!;
  final List<double> values = <double>[];
  for (final String token in match.group(1)!.trim().split(RegExp(r'\s+'))) {
    final List<String> parts = token.split(',');
    if (parts.length < 2) continue;
    values.add(double.parse(parts[0]));
    values.add(double.parse(parts[1]));
  }
  return Float64List.fromList(values);
}

void main() {
  test('a real tracker export marks the return leg, not the first pass', () {
    final Float64List track = _packKml(File('test/fixtures/repeat_pass_real_track.kml').readAsStringSync());
    expect(track.length ~/ 2, 130, reason: 'the fixture slice');

    final Uint8List flags = classifyRepeatPasses(track);

    final int outboundFlags = flags.sublist(outboundStart, outboundEnd + 1).where((int f) => f == 1).length;
    final int returnFlags = flags.sublist(returnStart, returnEnd + 1).where((int f) => f == 1).length;
    expect(outboundFlags, 0, reason: 'the first pass is first');
    expect(returnFlags, greaterThanOrEqualTo(returnEnd - returnStart), reason: 'the recorded return re-drives the road');
  });

  test('the same recorded leg read at 60 degrees north keeps its answer', () {
    // The classifier works in metres, so the same geometry must read the same
    // wherever the vehicle records it. 60N compresses a degree of longitude to
    // about half its width, which a bug in the metre conversion would expose.
    final Float64List original = _packKml(File('test/fixtures/repeat_pass_real_track.kml').readAsStringSync());
    final Float64List oslo = Float64List(original.length);
    const double centreLat = 25.03;
    // Metres per degree of longitude at the source latitude over the same at
    // 60N, so a source offset in metres keeps its length.
    final double scale = _cosine(centreLat) / _cosine(60);
    for (var i = 0; i < original.length ~/ 2; i++) {
      oslo[i * 2] = 10.75 + (original[i * 2] - 96.11) * scale;
      oslo[i * 2 + 1] = 59.9 + (original[i * 2 + 1] - 16.86);
    }
    final Uint8List flags = classifyRepeatPasses(oslo);
    expect(flags.sublist(returnStart, returnEnd + 1).where((int f) => f == 1).length, greaterThanOrEqualTo(returnEnd - returnStart));
  });
}

double _cosine(double degrees) {
  const double radiansPerDegree = 0.017453292519943295;
  final double x = degrees * radiansPerDegree;
  // Enough precision for a coordinate shift in a test, no import for two taps.
  var term = 1.0;
  var sum = 0.0;
  for (var k = 0; k < 6; k++) {
    sum += term;
    term *= -x * x / ((2 * k + 1) * (2 * k + 2));
  }
  return sum;
}
