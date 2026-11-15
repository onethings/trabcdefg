import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/utils/played_prefix.dart';

// A track whose point i sits at longitude i, so a vertex records its own index.
List<double> trackPoint(int index) => [index.toDouble(), 0];

List<double> indicesOf(PlayedPrefix prefix) => prefix.vertices.map((v) => v[0]).toList();

void main() {
  group('played prefix', () {
    test('a walk that fits the budget keeps every point of the line', () {
      final prefix = PlayedPrefix(maxVertices: 64);
      prefix.advanceTo(40, trackPoint);
      expect(indicesOf(prefix), List.generate(41, (i) => i.toDouble()));
    });

    test('the vertex count never passes the budget however long the track', () {
      for (final int pointCount in [500, 5000, 20000]) {
        final prefix = PlayedPrefix(maxVertices: 300);
        for (var i = 0; i <= pointCount; i++) {
          prefix.advanceTo(i, trackPoint);
        }
        expect(prefix.vertices.length, lessThanOrEqualTo(300));
        // Still a walk from the first point to the last one, only coarser.
        expect(prefix.vertices.first[0], 0);
        expect(prefix.vertices.last[0], greaterThan(pointCount - 2 * 300));
      }
    });

    test('a fractional walk that jumps far in one step stays bounded', () {
      final prefix = PlayedPrefix(maxVertices: 100);
      prefix.advanceTo(9000, trackPoint);
      expect(prefix.vertices.length, lessThanOrEqualTo(100));
      expect(prefix.vertices.first[0], 0);
    });

    test('dragging back draws the same line as playing to that point', () {
      final played = PlayedPrefix(maxVertices: 80);
      for (var i = 0; i <= 400; i++) {
        played.advanceTo(i, trackPoint);
      }
      final walked = PlayedPrefix(maxVertices: 80);
      for (var i = 0; i <= 60; i++) {
        walked.advanceTo(i, trackPoint);
      }
      played.advanceTo(60, trackPoint);
      expect(indicesOf(played), indicesOf(walked));
    });

    test('points stay in track order with no repeats', () {
      final prefix = PlayedPrefix(maxVertices: 50);
      for (var i = 0; i <= 777; i += 3) {
        prefix.advanceTo(i, trackPoint);
      }
      final indices = indicesOf(prefix);
      expect(indices, orderedEquals(([...indices]..sort())));
      expect(indices.toSet().length, indices.length);
    });
  });
}
