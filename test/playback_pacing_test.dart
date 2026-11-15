import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/utils/playback_pacing.dart';

/// Runs a playback at [fps] and returns how long the whole track took.
double playThroughSeconds({required int pointCount, required double speed, required int fps}) {
  final double maxPosition = (pointCount - 1).toDouble();
  final double step = 1 / fps;
  var position = 0.0;
  var elapsed = 0.0;
  while (position < maxPosition && elapsed < 100000) {
    position = advancePlaybackPosition(position: position, maxPosition: maxPosition, speed: speed, deltaSeconds: step);
    elapsed += step;
  }
  return elapsed;
}

void main() {
  group('playback pace', () {
    test('a track plays in base/speed wall seconds however many points it holds', () {
      final double sparse = playThroughSeconds(pointCount: 60, speed: 1, fps: 60);
      final double dense = playThroughSeconds(pointCount: 3000, speed: 1, fps: 60);
      expect(sparse, closeTo(basePlaybackSeconds, 1));
      expect(dense, closeTo(basePlaybackSeconds, 1));
    });

    test('a fast vehicle track plays no quicker than a slow one', () {
      // Points recorded 5 s apart imply a slow vehicle, 60 s apart a fast one;
      // the track duration must not depend on that spacing.
      final double slow = playThroughSeconds(pointCount: 200, speed: 5, fps: 60);
      final double fast = playThroughSeconds(pointCount: 20, speed: 5, fps: 60);
      expect(slow, closeTo(fast, 1));
    });

    test('the device refresh rate does not change the pace', () {
      final double at60 = playThroughSeconds(pointCount: 500, speed: 10, fps: 60);
      final double at120 = playThroughSeconds(pointCount: 500, speed: 10, fps: 120);
      expect(at120, closeTo(at60, 1));
      expect(at60, closeTo(playbackDurationSeconds(10), 1));
    });

    test('position stops at the end of the track and ignores empty deltas', () {
      expect(advancePlaybackPosition(position: 99, maxPosition: 100, speed: 20, deltaSeconds: 5), 100);
      expect(advancePlaybackPosition(position: 42, maxPosition: 100, speed: 1, deltaSeconds: 0), 42);
      expect(advancePlaybackPosition(position: 42, maxPosition: 0, speed: 1, deltaSeconds: 0.1), 42);
    });
  });
}
