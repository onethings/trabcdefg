import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/utils/playback_view.dart';

const double _taipeiLatitude = 25.03;
const double _viewport = 595;

void main() {
  group('the follow view shows a share of this track', () {
    test('a longer track opens the view up, so the marker keeps a readable pace', () {
      final double city = spanMetersForTrack(trackLengthMeters: 10000, speed: 1);
      final double highway = spanMetersForTrack(trackLengthMeters: 400000, speed: 1);
      expect(highway, greaterThan(city * 20));
    });

    test('the same track opens up as the playback speed rises', () {
      final double slow = spanMetersForTrack(trackLengthMeters: 50000, speed: 1);
      final double fast = spanMetersForTrack(trackLengthMeters: 50000, speed: 20);
      expect(fast, greaterThan(slow));
      expect(fast, lessThan(slow * 10), reason: '20x must not turn into a country view');
    });

    test('a tiny track does not zoom in past a readable street scale', () {
      expect(spanMetersForTrack(trackLengthMeters: 300, speed: 1), minFollowSpanMeters);
      expect(spanMetersForTrack(trackLengthMeters: 300, speed: 20), minFollowSpanMeters);
    });

    test('the view never shows more than the whole track', () {
      for (final double length in [500.0, 5000.0, 80000.0]) {
        for (final double speed in [1.0, 20.0]) {
          final double span = spanMetersForTrack(trackLengthMeters: length, speed: speed);
          expect(span, lessThanOrEqualTo(length), reason: 'track $length at ${speed}x');
        }
      }
    });
  });

  group('the promise: crossing time does not depend on how long the track is', () {
    test('at 1x the marker crosses the screen in the same time on any track', () {
      final double city = secondsToCrossScreen(trackLengthMeters: 8000, speed: 1, viewportHeightPx: _viewport);
      final double trip = secondsToCrossScreen(trackLengthMeters: 120000, speed: 1, viewportHeightPx: _viewport);
      final double highway = secondsToCrossScreen(trackLengthMeters: 400000, speed: 1, viewportHeightPx: _viewport);
      expect(city, closeTo(18, 0.5));
      expect(trip, closeTo(18, 0.5));
      expect(highway, closeTo(18, 0.5));
    });

    test('raising the speed is the only thing that hurries the marker across', () {
      final double atOne = secondsToCrossScreen(trackLengthMeters: 60000, speed: 1, viewportHeightPx: _viewport);
      final double atTwenty = secondsToCrossScreen(trackLengthMeters: 60000, speed: 20, viewportHeightPx: _viewport);
      expect(atTwenty, lessThan(atOne));
      expect(atTwenty, greaterThan(1.5), reason: 'still follows the arrow instead of blinking past it');
    });
  });

  group('turning a span into a zoom', () {
    test('a zoom derived from a span really shows that span', () {
      for (final double span in [400.0, 1500.0, 42000.0]) {
        final double zoom = zoomForSpan(spanMeters: span, latitude: _taipeiLatitude, viewportHeightPx: _viewport);
        final double covered = metersPerPixel(latitude: _taipeiLatitude, zoom: zoom) * _viewport;
        expect(covered, closeTo(span, span * 0.01));
      }
    });

    test('the same span needs a higher zoom nearer the equator', () {
      expect(zoomForSpan(spanMeters: 1500, latitude: 60, viewportHeightPx: _viewport), lessThan(zoomForSpan(spanMeters: 1500, latitude: 0, viewportHeightPx: _viewport)));
    });

    test('a taller screen needs a higher zoom for the same ground span', () {
      expect(zoomForSpan(spanMeters: 1500, latitude: _taipeiLatitude, viewportHeightPx: 900), greaterThan(zoomForSpan(spanMeters: 1500, latitude: _taipeiLatitude, viewportHeightPx: 600)));
    });

    test('follow zoom pulls back at high speed and comes back in at 1x', () {
      final double slow = followZoom(trackLengthMeters: 40000, speed: 1, latitude: _taipeiLatitude, viewportHeightPx: _viewport);
      final double fast = followZoom(trackLengthMeters: 40000, speed: 20, latitude: _taipeiLatitude, viewportHeightPx: _viewport);
      expect(fast, lessThan(slow - 1));
      expect(fast, greaterThan(minFollowZoom));
    });

    test('a cross-city highway day is read at a wider zoom than a city errand', () {
      final double city = followZoom(trackLengthMeters: 5000, speed: 1, latitude: _taipeiLatitude, viewportHeightPx: _viewport);
      final double highway = followZoom(trackLengthMeters: 300000, speed: 1, latitude: _taipeiLatitude, viewportHeightPx: _viewport);
      expect(highway, lessThan(city - 3));
    });

    test('the user offset shifts the derived zoom and stays in range', () {
      final double base = followZoom(trackLengthMeters: 20000, speed: 1, latitude: _taipeiLatitude, viewportHeightPx: _viewport);
      expect(followZoom(trackLengthMeters: 20000, speed: 1, latitude: _taipeiLatitude, viewportHeightPx: _viewport, userOffsetLog2: 1), closeTo(base + 1, 0.001));
      expect(followZoom(trackLengthMeters: 20000, speed: 1, latitude: _taipeiLatitude, viewportHeightPx: _viewport, userOffsetLog2: -99), minFollowZoom);
      expect(followZoom(trackLengthMeters: 20000, speed: 1, latitude: _taipeiLatitude, viewportHeightPx: _viewport, userOffsetLog2: 99), maxFollowZoom);
    });
  });

  group('learning what the user likes', () {
    test('zooming in once moves the remembered offset toward that wish', () {
      expect(settleFollowOffset(currentOffset: 0, userZoom: 16, derivedZoom: 14.5), closeTo(0.6, 0.001));
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
