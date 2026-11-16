import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/utils/camera_follow.dart';

// A visible area of 10 by 10 degrees, south west corner at the origin.
const double south = 0;
const double west = 0;
const double north = 10;
const double east = 10;

bool at(double latitude, double longitude, {double band = defaultEdgeBandFraction}) =>
    isInEdgeZone(latitude: latitude, longitude: longitude, south: south, west: west, north: north, east: east, band: band);

void main() {
  group('camera follow dead zone', () {
    test('the middle of the screen holds still', () {
      expect(at(5, 5), isFalse);
      expect(at(4, 6), isFalse);
      expect(at(6, 4), isFalse);
    });

    test('each edge counts once the marker reaches the band', () {
      expect(at(7, 5), isTrue, reason: 'near the top');
      expect(at(3, 5), isTrue, reason: 'near the bottom');
      expect(at(5, 7), isTrue, reason: 'near the right');
      expect(at(5, 3), isTrue, reason: 'near the left');
    });

    test('a marker outside the visible area always counts', () {
      expect(at(11, 5), isTrue);
      expect(at(-1, 5), isTrue);
      expect(at(5, 11), isTrue);
      expect(at(5, -1), isTrue);
    });

    test('the default band starts exactly 35% in from each edge', () {
      // 10 degrees tall, so the band starts at 6.5 and 3.5. This pins the
      // fraction the bottom playback panel needs, not just the shape of the test.
      expect(at(6.5, 5), isFalse);
      expect(at(6.51, 5), isTrue);
      expect(at(3.5, 5), isFalse);
      expect(at(3.49, 5), isTrue);
    });

    test('a band of zero only counts outside the visible area', () {
      expect(at(7, 5, band: 0), isFalse);
      expect(at(11, 5, band: 0), isTrue);
    });

    test('a band of half leaves only the exact centre still', () {
      expect(at(5, 5, band: 0.5), isFalse);
      expect(at(5.5, 5, band: 0.5), isTrue);
    });
  });
}
