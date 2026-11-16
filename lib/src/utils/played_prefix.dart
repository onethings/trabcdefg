// The walked prefix of a track, as the line vertices the map is handed.
//
// A push replaces the whole GeoJSON source, so the cost of one push is the
// vertex count of the line it carries, and that count grows with how much of
// the track has been walked. Keeping a uniform sample of the walked points,
// bounded by [PlayedPrefix.maxVertices], holds the cost of a push flat for a
// whole play-through instead of letting it grow with the track.

/// Vertices of the played prefix, sampled at a uniform stride.
class PlayedPrefix {
  PlayedPrefix({this.maxVertices = 1500}) : assert(maxVertices > 1);

  /// Most vertices [vertices] ever holds.
  final int maxVertices;

  final List<List<double>> _vertices = [];
  int _stride = 1;
  int _lastIndex = -1;

  /// Read-only by convention: spread it instead of mutating it.
  List<List<double>> get vertices => _vertices;

  void clear() {
    _vertices.clear();
    _stride = 1;
    _lastIndex = -1;
  }

  /// Extends the prefix to [index], reading the track through [coordinateAt].
  ///
  /// Doubling the stride keeps the vertices whose index is a multiple of it, so
  /// what the map is given depends only on [index] and [maxVertices]. Playing
  /// forward and dragging back to the same [index] therefore draw the same
  /// line, and a doubling drops only detail that is already off screen.
  void advanceTo(int index, List<double> Function(int index) coordinateAt) {
    if (index < _lastIndex) clear();
    if (index <= _lastIndex) return;

    while (index ~/ _stride + 1 > maxVertices) {
      _stride *= 2;
      final int kept = (_vertices.length + 1) ~/ 2;
      for (var i = 0; i < kept; i++) {
        _vertices[i] = _vertices[i * 2];
      }
      _vertices.length = kept;
    }

    for (var i = _lastIndex + 1; i <= index; i++) {
      if (i % _stride == 0) _vertices.add(coordinateAt(i));
    }
    _lastIndex = index;
  }
}
