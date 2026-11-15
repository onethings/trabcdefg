// Rate limits for the pushes the playback loop makes across the platform
// channel. Each consumer of the playback position has its own budget, so the
// rule "how often may this one publish" lives in one place instead of a
// `now - lastAt >= intervalMs` pair per consumer.

/// Fires at most once per [intervalMs].
class PublishBudget {
  PublishBudget(this.intervalMs);

  final int intervalMs;
  int _lastAtMs = 0;
  bool _spent = false;

  /// True when the budget allows a publish at [nowMs], and then it spends it.
  bool due(int nowMs) {
    // A clock that stepped backwards must not hold a consumer off until it
    // catches up with the last stamp.
    if (_spent && nowMs >= _lastAtMs && nowMs - _lastAtMs < intervalMs) return false;
    _lastAtMs = nowMs;
    _spent = true;
    return true;
  }

  /// Clears the spent budget, for a consumer that has just published out of
  /// band and must not be held back by its own interval.
  void reset() {
    _lastAtMs = 0;
    _spent = false;
  }
}
