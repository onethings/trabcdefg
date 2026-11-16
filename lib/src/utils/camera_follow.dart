// Where the camera goes while a track plays.
//
// Follow is a dead zone, not a lock: the marker may drift away from the centre
// and the camera only moves once it reaches the outer band of the visible area.
// Pinning the marker to the centre makes the whole map slide under a marker
// that never moves, which reads as the camera fighting the user.

/// Fraction of the visible span, measured in from each edge, that counts as
/// "at the edge". 0.35 leaves the middle 30% free, which is what the bottom
/// playback panel leaves uncovered.
const double defaultEdgeBandFraction = 0.35;

/// Whether [point] has reached the outer band of [visible].
bool isInEdgeZone({required double latitude, required double longitude, required double south, required double west, required double north, required double east, double band = defaultEdgeBandFraction}) {
  return latitude > north - (north - south) * band || latitude < south + (north - south) * band || longitude > east - (east - west) * band || longitude < west + (east - west) * band;
}
