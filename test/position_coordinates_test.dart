import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/position_coordinates.dart';

void main() {
  group('hasValidPositionCoordinates', () {
    test('accepts valid coordinates on the equator and prime meridian', () {
      expect(hasValidPositionCoordinates(api.Position(latitude: 0.0, longitude: 0.0)), isTrue);
    });

    test('accepts the geographic coordinate boundaries', () {
      expect(hasValidPositionCoordinates(api.Position(latitude: 90.0, longitude: 180.0)), isTrue);
      expect(hasValidPositionCoordinates(api.Position(latitude: -90.0, longitude: -180.0)), isTrue);
    });

    test('rejects missing and out-of-range coordinates', () {
      expect(hasValidPositionCoordinates(null), isFalse);
      expect(hasValidPositionCoordinates(api.Position(latitude: 0.0)), isFalse);
      expect(hasValidPositionCoordinates(api.Position(latitude: 90.1, longitude: 0.0)), isFalse);
      expect(hasValidPositionCoordinates(api.Position(latitude: 0.0, longitude: 180.1)), isFalse);
    });
  });
}
