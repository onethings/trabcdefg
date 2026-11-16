// Zoom for the history route page, derived from what the camera has to show.
//
// The page holds two views and each one owns its zoom. Overview shows the whole
// track, so its zoom is the fit and nothing else. Follow shows the ground the
// vehicle covers next, so its zoom is a ground span divided by the screen the
// playback panel leaves. A single remembered zoom number serves neither view: it
// is the wrong number the moment the track length or the playback speed changes,
// which is why saving the last zoom keeps landing wrong.
//
// A user who zooms during follow is answering a different question, "bigger or
// smaller than what the app picked", so what gets remembered is that ratio and
// not the absolute zoom. The ratio survives a speed change and still leaves the
// app free to pull back at 20x.

import 'dart:math' as math;

/// Ground metres one pixel covers at zoom 0 on the equator.
const double _equatorMetersPerPixelAtZoom0 = 156543.03392;

/// Ground width, in metres of screen height, the follow view shows at 1x.
const double baseFollowSpanMeters = 1500;

/// How fast the span opens up as the playback speed rises. 0.35 keeps 20x at
/// roughly three times the 1x span: enough road ahead to read, still a chase
/// camera rather than a country view.
const double _speedSpanExponent = 0.35;

const double minFollowZoom = 3;
const double maxFollowZoom = 19;

/// How wide a preference the learned ratio may express, in zoom levels.
const double maxUserOffsetLog2 = 2;

/// Ground span, in metres of screen height, that [speed] needs.
double spanMetersForSpeed(double speed) {
  final double clampedSpeed = speed.clamp(1.0, 20.0);
  return baseFollowSpanMeters * math.pow(clampedSpeed, _speedSpanExponent);
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

/// Follow zoom for [speed] at [latitude], shifted by the user's own preference.
double followZoom({required double speed, required double latitude, required double viewportHeightPx, double userOffsetLog2 = 0}) {
  final double derived = zoomForSpan(spanMeters: spanMetersForSpeed(speed), latitude: latitude, viewportHeightPx: viewportHeightPx);
  return (derived + userOffsetLog2).clamp(minFollowZoom, maxFollowZoom);
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
