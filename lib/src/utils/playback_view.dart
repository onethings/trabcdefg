// Zoom for the history route page, derived from what the camera has to show.
//
// The page holds two views and each one owns its zoom. Overview shows the whole
// track, so its zoom is the fit and nothing else. Follow shows the ground the
// vehicle covers next, so its zoom is a share of this track divided by the screen
// the playback panel leaves.
//
// A fixed ground span cannot serve every track: one playback takes 120 seconds
// whether the track is 2 km or 400 km, so a span that reads well on a city drive
// leaves a highway drive crossing the screen in under a second. The span is
// therefore a share of the track, and the promise it makes is testable: at any
// playback speed the marker crosses the visible height in the same wall-clock
// time, whatever the track length. Only the speed multiplier changes that time.
//
// A user who zooms during follow is answering a different question, "bigger or
// smaller than what the app picked", so what gets remembered is that ratio and
// not the absolute zoom. The ratio survives a speed change and still leaves the
// app free to pull back at 20x. Nobody has to be asked for a distance.

import 'dart:math' as math;

/// Ground metres one pixel covers at zoom 0 on the equator.
const double _equatorMetersPerPixelAtZoom0 = 156543.03392;

/// Share of the track the follow view shows at 1x. With a play-through of
/// [basePlaybackSeconds] this is what makes the marker cross the visible height
/// in 18 seconds.
const double baseVisibleTrackFraction = 0.15;

/// How fast the share opens up as the playback speed rises. 0.35 keeps 20x at
/// roughly three times the 1x share: enough road ahead to read, still a chase
/// camera rather than a country view.
const double _speedSpanExponent = 0.35;

/// Never closer than this, so a very short track does not fill the screen with
/// a few hundred metres.
const double minFollowSpanMeters = 400;

/// Never more of the track than this, so fast playback still reads as following
/// rather than as an overview.
const double maxTrackFractionOnScreen = 0.9;

const double minFollowZoom = 3;
const double maxFollowZoom = 19;

/// How wide a preference the learned ratio may express, in zoom levels.
const double maxUserOffsetLog2 = 2;

/// Ground span, in metres of screen height, that this track needs at [speed].
double spanMetersForTrack({required double trackLengthMeters, required double speed}) {
  if (trackLengthMeters <= 0) return minFollowSpanMeters;
  final double clampedSpeed = speed.clamp(1.0, 20.0);
  final double raw = trackLengthMeters * baseVisibleTrackFraction * math.pow(clampedSpeed, _speedSpanExponent);
  final double ceiling = math.max(minFollowSpanMeters, trackLengthMeters * maxTrackFractionOnScreen);
  return raw.clamp(minFollowSpanMeters, ceiling);
}

/// Ground metres one pixel covers at [latitude] and [zoom].
double metersPerPixel({required double latitude, required double zoom}) {
  return _equatorMetersPerPixelAtZoom0 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
}

/// Zoom that makes [spanMeters] fill [viewportHeightPx] at [latitude].
double zoomForSpan({required double spanMeters, required double latitude, required double viewportHeightPx}) {
  if (spanMeters <= 0 || viewportHeightPx <= 0) return minFollowZoom;
  final double metresPerPixelWanted = spanMeters / viewportHeightPx;
  final double zoom = math.log(_equatorMetersPerPixelAtZoom0 * math.cos(latitude * math.pi / 180) / metresPerPixelWanted) / math.ln2;
  return zoom.clamp(minFollowZoom, maxFollowZoom);
}

/// Follow zoom for this track at [speed], shifted by the user's own preference.
double followZoom({required double trackLengthMeters, required double speed, required double latitude, required double viewportHeightPx, double userOffsetLog2 = 0}) {
  final double derived = zoomForSpan(spanMeters: spanMetersForTrack(trackLengthMeters: trackLengthMeters, speed: speed), latitude: latitude, viewportHeightPx: viewportHeightPx);
  return (derived + userOffsetLog2).clamp(minFollowZoom, maxFollowZoom);
}

/// Seconds the marker takes to cross the visible height, the promise the span
/// makes. Used by the tests to hold the promise for every track length.
double secondsToCrossScreen({required double trackLengthMeters, required double speed, required double viewportHeightPx, double baseSeconds = 120}) {
  final double span = spanMetersForTrack(trackLengthMeters: trackLengthMeters, speed: speed);
  final double groundMetresPerSecond = trackLengthMeters / (baseSeconds / speed.clamp(1.0, 20.0));
  if (groundMetresPerSecond <= 0) return 0;
  return span / groundMetresPerSecond;
}

/// The offset to remember after the user zooms to [userZoom] while the app had
/// derived [derivedZoom].
///
/// Weighted toward the new sample so one deliberate gesture moves the setting,
/// and clamped so a one-off peek at a single stop cannot turn every future
/// playback into a street view.
double settleFollowOffset({required double currentOffset, required double userZoom, required double derivedZoom, double weight = 0.4}) {
  final double sample = (userZoom - derivedZoom).clamp(-maxUserOffsetLog2, maxUserOffsetLog2);
  return (currentOffset + (sample - currentOffset) * weight).clamp(-maxUserOffsetLog2, maxUserOffsetLog2);
}

/// Whether the user's own zoom is still fresh enough that the app must leave it
/// alone. A gesture, a zoom button, or a speed change in this window means the
/// user is looking at something, not asking for a different default.
bool isInsideZoomFreeze({required int nowMs, required int lastUserZoomAtMs, int windowMs = 12000}) {
  if (lastUserZoomAtMs == 0) return false;
  return nowMs - lastUserZoomAtMs < windowMs;
}
