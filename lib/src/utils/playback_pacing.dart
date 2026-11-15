// Playback pacing for the history route screen.
//
// The position the playback bar drives is measured in track-index units, but the
// pace must not depend on how many points the track happens to hold, how far
// apart they were recorded, or how often the device renders a frame. Anchoring
// the pace to a fixed play-through duration gives one promise instead: the whole
// track plays in [basePlaybackSeconds] / speed wall-clock seconds.

/// Wall-clock seconds one full play-through takes at 1x.
const double basePlaybackSeconds = 120;

/// How far the playback position moves for a wall-clock delta.
///
/// [position] and [maxPosition] are in track-index units, [speed] is the selected
/// multiplier, [deltaSeconds] is the wall-clock time since the previous tick.
double advancePlaybackPosition({
  required double position,
  required double maxPosition,
  required double speed,
  required double deltaSeconds,
  double baseSeconds = basePlaybackSeconds,
}) {
  if (maxPosition <= 0 || speed <= 0 || deltaSeconds <= 0 || baseSeconds <= 0) {
    return position;
  }
  final double next = position + maxPosition * speed * deltaSeconds / baseSeconds;
  return next > maxPosition ? maxPosition : next;
}

/// Wall-clock seconds a full play-through takes at [speed].
double playbackDurationSeconds(double speed, {double baseSeconds = basePlaybackSeconds}) {
  if (speed <= 0) return baseSeconds;
  return baseSeconds / speed;
}
