import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/utils/playback_view.dart';

const double _taipeiLatitude = 25.03;

void main() {
  group('the follow view is a ground span, not a zoom number', () {
    test('the span opens up with the playback speed and stops at the top', () {
      expect(spanMetersForSpeed(1), closeTo(baseFollowSpanMeters, 0.001));
      expect(spanMetersForSpeed(5), greaterThan(spanMetersForSpeed(1)));
      expect(spanMetersForSpeed(10), greaterThan(spanMetersForSpeed(5)));
      expect(spanMetersForSpeed(20), greaterThan(spanMetersForSpeed(10)));
      expect(spanMetersForSpeed(20), lessThan(baseFollowSpanMeters * 3.5), reason: '20x is a chase camera, not a country view');
      expect(spanMetersForSpeed(100), closeTo(spanMetersForSpeed(20), 0.001), reason: 'the speed list is clamped');
    });

    test('a zoom derived from a span really shows that span', () {
      for (final double span in [400.0, 1500.0, 4200.0]) {
        final double zoom = zoomForSpan(spanMeters: span, latitude: _taipeiLatitude, viewportHeightPx: 800);
        final double covered = metersPerPixel(latitude: _taipeiLatitude, zoom: zoom) * 800;
        expect(covered, closeTo(span, span * 0.01));
      }
    });

    test('the same span needs a higher zoom nearer the equator', () {
      final double equator = zoomForSpan(spanMeters: 1500, latitude: 0, viewportHeightPx: 800);
      final double north = zoomForSpan(spanMeters: 1500, latitude: 60, viewportHeightPx: 800);
      expect(north, lessThan(equator), reason: 'mercator stretches a degree near the poles');
    });

    test('a taller screen needs a higher zoom for the same ground span', () {
      final double shortScreen = zoomForSpan(spanMeters: 1500, latitude: _taipeiLatitude, viewportHeightPx: 600);
      final double tallScreen = zoomForSpan(spanMeters: 1500, latitude: _taipeiLatitude, viewportHeightPx: 900);
      expect(tallScreen, greaterThan(shortScreen));
    });

    test('follow zoom pulls back at high speed and comes back in at 1x', () {
      final double slow = followZoom(speed: 1, latitude: _taipeiLatitude, viewportHeightPx: 800);
      final double fast = followZoom(speed: 20, latitude: _taipeiLatitude, viewportHeightPx: 800);
      expect(fast, lessThan(slow - 1), reason: 'a speed change has to be visible');
      expect(fast, greaterThan(minFollowZoom));
    });

    test('the user offset shifts the derived zoom and stays in range', () {
      final double base = followZoom(speed: 1, latitude: _taipeiLatitude, viewportHeightPx: 800);
      expect(followZoom(speed: 1, latitude: _taipeiLatitude, viewportHeightPx: 800, userOffsetLog2: 1), closeTo(base + 1, 0.001));
      expect(followZoom(speed: 1, latitude: _taipeiLatitude, viewportHeightPx: 800, userOffsetLog2: -99), minFollowZoom);
      expect(followZoom(speed: 1, latitude: _taipeiLatitude, viewportHeightPx: 800, userOffsetLog2: 99), maxFollowZoom);
    });
  });

  group('learning what the user likes', () {
    test('zooming in once moves the remembered offset toward that wish', () {
      final double learned = settleFollowOffset(currentOffset: 0, userZoom: 16, derivedZoom: 14.5);
      expect(learned, greaterThan(0));
      expect(learned, closeTo(0.6, 0.001));
    });

    test('zooming out once moves it the other way', () {
      expect(settleFollowOffset(currentOffset: 0, userZoom: 13, derivedZoom: 14.5), closeTo(-0.6, 0.001));
    });

    test('repeating the same gesture keeps pulling the offset to it', () {
      double offset = 0;
      for (var i = 0; i < 12; i++) {
        offset = settleFollowOffset(currentOffset: offset, userZoom: 16, derivedZoom: 14.5);
      }
      expect(offset, closeTo(1.5, 0.01));
    });

    test('one wild peek cannot set the whole future', () {
      double offset = 0;
      for (var i = 0; i < 40; i++) {
        offset = settleFollowOffset(currentOffset: offset, userZoom: 19, derivedZoom: 10);
      }
      expect(offset, lessThanOrEqualTo(maxUserOffsetLog2));
    });
  });

  group('the user zoom has a freeze window', () {
    test('no gesture yet means the app may derive', () {
      expect(isInsideZoomFreeze(nowMs: 5000, lastUserZoomAtMs: 0), isFalse);
    });

    test('a gesture a moment ago holds the app off', () {
      expect(isInsideZoomFreeze(nowMs: 6000, lastUserZoomAtMs: 5000), isTrue);
      expect(isInsideZoomFreeze(nowMs: 5000 + 11999, lastUserZoomAtMs: 5000), isTrue);
      expect(isInsideZoomFreeze(nowMs: 5000 + 12000, lastUserZoomAtMs: 5000), isFalse);
    });
  });
}
