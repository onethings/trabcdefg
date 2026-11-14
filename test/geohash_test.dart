// Pins the in-repo geohash to the values the app shipped with while the
// offline address service used package:dart_geohash. The golden strings and
// decoded centres were captured from that package before it was removed, so a
// regression here means the address cache keys or region lookups moved.
import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/utils/geohash.dart';

void main() {
  final hasher = GeoHasher();

  // [longitude, latitude, precision, expected hash, expected decoded lon, expected decoded lat]
  const fixtures = <List<dynamic>>[
    [96.1951, 16.8409, 9, 'w4urucz1k', 96.19510889053345, 16.840903759002686],
    [96.1951, 16.8409, 7, 'w4urucz', 96.19560241699219, 16.841354370117188],
    [-180.0, -90.0, 9, '000000000', -179.99997854232788, -89.99997854232788],
    [180.0, 90.0, 9, 'zzzzzzzzz', 179.99997854232788, 89.99997854232788],
    [0.0, 0.0, 9, 's00000000', 0.000021457672119140625, 0.000021457672119140625],
    [0.0, 0.0, 5, 's0000', 0.02197265625, 0.02197265625],
    [-122.4194, 37.7749, 8, '9q8yyk8y', -122.41945266723633, 37.774858474731445],
    [139.6917, 35.6895, 6, 'xn774c', 139.6966552734375, 35.69183349609375],
    [151.2093, -33.8688, 4, 'r3gx', 151.34765625, -33.837890625],
    [2.3522, 48.8566, 9, 'u09tvw0f6', 2.3522114753723145, 48.856608867645264],
    [-0.1276, 51.5074, 7, 'gcpvj0e', -0.1270294189453125, 51.50733947753906],
    [179.9999, 0.0, 9, 'xbpbpbpbj', 179.9998927116394, 0.000021457672119140625],
    [-179.9999, 0.0, 9, '800000004', -179.9998927116394, 0.000021457672119140625],
  ];

  test('encode reproduces the shipped hashes', () {
    for (final fixture in fixtures) {
      final lon = fixture[0] as double;
      final lat = fixture[1] as double;
      final precision = fixture[2] as int;
      final expected = fixture[3] as String;
      expect(hasher.encode(lon, lat, precision: precision), expected, reason: 'encode($lon, $lat, precision: $precision)');
    }
  });

  test('decode returns the shipped cell centres', () {
    for (final fixture in fixtures) {
      final hash = fixture[3] as String;
      final decoded = hasher.decode(hash);
      expect(decoded[0], fixture[4] as double, reason: 'decode($hash) longitude');
      expect(decoded[1], fixture[5] as double, reason: 'decode($hash) latitude');
    }
  });

  test('encode then decode lands inside the requested cell', () {
    // A 9-character cell is roughly 4.8m, so the centre stays within that of
    // the input. This catches a bit order flip that the fixtures might miss.
    for (final fixture in fixtures) {
      final lon = fixture[0] as double;
      final lat = fixture[1] as double;
      final precision = fixture[2] as int;
      final hash = hasher.encode(lon, lat, precision: precision);
      final decoded = hasher.decode(hash);

      final cellSize = <int, double>{4: 39.0, 5: 4.9, 6: 1.2, 7: 0.15, 8: 0.019, 9: 0.0048}[precision]!;
      expect((decoded[0] - lon).abs(), lessThan(cellSize), reason: 'longitude drift at precision $precision');
      expect((decoded[1] - lat).abs(), lessThan(cellSize), reason: 'latitude drift at precision $precision');
    }
  });

  test('decode rejects malformed hashes', () {
    expect(() => hasher.decode(''), throwsArgumentError);
    expect(() => hasher.decode('abc!def'), throwsArgumentError);
    expect(() => hasher.decode('ABC'), throwsArgumentError);
    expect(() => hasher.decode('abc il'), throwsArgumentError);
  });

  test('encode rejects coordinates off the globe', () {
    expect(() => hasher.encode(180.1, 0), throwsRangeError);
    expect(() => hasher.encode(-180.1, 0), throwsRangeError);
    expect(() => hasher.encode(0, 90.1), throwsRangeError);
    expect(() => hasher.encode(0, -90.1), throwsRangeError);
    expect(() => hasher.encode(0, 0, precision: 0), throwsRangeError);
  });
}
