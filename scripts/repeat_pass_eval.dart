// Runs the repeat-pass classifier over exported tracker KML files and reports
// what it decided, so a real recording can be checked instead of only the
// synthetic tracks in the tests. Each KML file becomes one polyline: blue where
// the path is new, purple where the classifier says the vehicle passed before.
//
//   dart scripts/repeat_pass_eval.dart [kml-dir] [--verify]
//     [--toleranceMeters=N] [--minGapMeters=N]
//
// --verify runs a brute-force reference classifier, restating the same rules
// without the metre grid or the piece split, and reports any point where the
// shipped classifier disagrees, plus how many near-exact repeats the
// neighbour-agreement rule suppressed. --toleranceMeters and --minGapMeters
// override the classifier defaults so a threshold change can be measured on
// the same recordings before it is made. The run also prints one SVG per input
// under build/repeat_eval/.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:trabcdefg/src/utils/repeat_pass.dart';

const double _mPerDegLat = 110574.0;

double _option(List<String> args, String name, double fallback) {
  for (final String arg in args) {
    if (arg.startsWith('--$name=')) {
      final double? value = double.tryParse(arg.substring(name.length + 3));
      if (value != null) return value;
    }
  }
  return fallback;
}

void main(List<String> args) {
  final List<String> dirs = args.where((String a) => !a.startsWith('--')).toList();
  final bool verify = args.contains('--verify');
  final double toleranceMeters = _option(args, 'toleranceMeters', defaultRepeatToleranceMeters);
  final double minGapMeters = _option(args, 'minGapMeters', defaultMinGapMeters);
  final Directory dir = Directory(dirs.isEmpty ? 'positions-kml' : dirs.first);
  if (!dir.existsSync()) {
    stderr.writeln('no such directory: ${dir.path}');
    exit(2);
  }
  final List<File> files = dir.listSync().whereType<File>().where((File f) => f.path.endsWith('.kml')).toList()..sort((File a, File b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stderr.writeln('no .kml files in ${dir.path}');
    exit(2);
  }
  final Directory outDir = Directory('build/repeat_eval')..createSync(recursive: true);

  var totalPoints = 0;
  var totalFlagged = 0;
  var totalRepeatMetres = 0.0;
  var totalTrackMetres = 0.0;
  for (final File file in files) {
    final String name = file.uri.pathSegments.last;
    final List<List<double>>? track = parseKml(file.readAsStringSync());
    if (track == null || track.length < 2) {
      stdout.writeln('SKIP $name (no usable LineString)');
      continue;
    }
    final Float64List packed = Float64List(track.length * 2);
    for (var i = 0; i < track.length; i++) {
      packed[i * 2] = track[i][0];
      packed[i * 2 + 1] = track[i][1];
    }
    final Stopwatch watch = Stopwatch()..start();
    final Uint8List flags = classifyRepeatPasses(packed, toleranceMeters: toleranceMeters, minGapMeters: minGapMeters);
    watch.stop();

    final int flagged = flags.where((int f) => f == 1).length;
    totalPoints += track.length;
    totalFlagged += flagged;

    // Evidence beyond the flag bit: how close each flagged point really sits to
    // the earlier geometry, and how much travel separated them. A parallel
    // street that the classifier mistakes for a repeat shows up as a matched
    // distance near the tolerance, not near zero.
    final _MatchAnalysis match = _analyzeMatches(track, flags, toleranceMeters: toleranceMeters, minGapMeters: minGapMeters);
    final String histogram = match.distanceHistogram();
    final (int jumps, double jumpKm) = _jumpStats(track);

    // Group consecutive flags into runs and measure each in metres, so a run of
    // parked duplicates cannot inflate the repeat estimate.
    final List<(int, int, double)> runs = <(int, int, double)>[];
    var runStart = -1;
    for (var i = 0; i <= flags.length; i++) {
      final bool on = i < flags.length && flags[i] == 1;
      if (!on && runStart >= 0) {
        runs.add((runStart, i - 1, _runMetres(track, runStart, i - 1)));
        runStart = -1;
      } else if (on && runStart < 0) {
        runStart = i;
      }
    }
    final double repeatMetres = runs.fold<double>(0, (double sum, (int, int, double) r) => sum + r.$3);
    final double totalMetres = _pathMetres(track);
    totalRepeatMetres += repeatMetres;
    totalTrackMetres += totalMetres;
    runs.sort((( int, int, double) a, (int, int, double) b) => b.$3.compareTo(a.$3));
    final String top = runs.take(4).map(((int, int, double) r) {
      final double avg = match.meanDistance(r.$1, r.$2);
      return '${r.$3.toStringAsFixed(0)}m@${r.$1}-${r.$2}/off${avg.toStringAsFixed(0)}/${match.runShape(r.$1, r.$2)}';
    }).join(' ');

    stdout.writeln('${name.padRight(18)} pts=${track.length.toString().padLeft(5)} '
        'flagged=${(100 * flagged / track.length).toStringAsFixed(1).padLeft(5)}% '
        'runs=${runs.length.toString().padLeft(3)} '
        'repeatKm=${(repeatMetres / 1000).toStringAsFixed(1).padLeft(6)} '
        'of=${(totalMetres / 1000).toStringAsFixed(1).padLeft(6)}km '
        '${watch.elapsedMilliseconds}ms');
    stdout.writeln('    jumps (chords excluded as gaps): $jumps, ${jumpKm.toStringAsFixed(1)} km');
    stdout.writeln('    distance histogram of flagged points (m): $histogram');
    stdout.writeln('    top runs (metres@index/mean offset/span+rho): $top');

    if (verify) {
      final Uint8List reference = _referenceFlags(packed, toleranceMeters: toleranceMeters, minGapMeters: minGapMeters);
      var mismatches = 0;
      for (var i = 0; i < flags.length; i++) {
        if (flags[i] != reference[i]) mismatches++;
      }
      final int candidates = match.candidateCount(toleranceMeters);
      final int suppressedExact = match.suppressedExactCount();
      stdout.writeln('    verify: fast-vs-reference mismatches=$mismatches; '
          'candidates(no neighbour rule)=$candidates flagged=${match.flaggedCount} '
          'suppressed-near-exact(<=3m)=$suppressedExact');
    }

    final String svgName = '${name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.svg';
    File('${outDir.path}/$svgName').writeAsStringSync(_svg(name, track, flags));
  }
  stdout.writeln('TOTAL flagged ${(100 * totalFlagged / math.max(1, totalPoints)).toStringAsFixed(1)}% '
      'of $totalPoints points, repeat distance ${(100 * totalRepeatMetres / math.max(1, totalTrackMetres)).toStringAsFixed(1)}% '
      'of ${(totalTrackMetres / 1000).toStringAsFixed(1)} km; SVGs in ${outDir.path}');
}

/// Extracts the first LineString's `<coordinates>`. A KML file is a single
/// placemark here; altitude is ignored because only the ground path matters.
List<List<double>>? parseKml(String text) {
  final RegExpMatch? match = RegExp(r'<coordinates>([\s\S]*?)</coordinates>').firstMatch(text);
  if (match == null) return null;
  final List<List<double>> out = <List<double>>[];
  for (final String token in match.group(1)!.trim().split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final List<String> parts = token.split(',');
    if (parts.length < 2) continue;
    final double? lng = double.tryParse(parts[0]);
    final double? lat = double.tryParse(parts[1]);
    if (lng == null || lat == null || !lng.isFinite || !lat.isFinite) continue;
    out.add(<double>[lng, lat]);
  }
  return out;
}

double _metresPerDegreeLng(double latitude) => 111320.0 * math.cos(latitude * math.pi / 180);

/// Chords the jump guard keeps out of the index: a GPS jump or a lost fix is
/// long next to the ordinary steps beside it. This is the number to compare
/// with a tracker export's jammer notes.
(int, double) _jumpStats(List<List<double>> track) {
  final int count = track.length;
  if (count < 3) return (0, 0);
  final List<double> chords = <double>[for (var i = 0; i + 1 < count; i++) _metresBetween(track[i], track[i + 1])];
  double shortestPlausible(int start) {
    var shortest = double.infinity;
    for (final int k in <int>[start - 1, start + 1]) {
      if (k < 0 || k >= chords.length) continue;
      final double c = chords[k];
      if (!c.isFinite || c < 1) continue;
      if (c < shortest) shortest = c;
    }
    return shortest.isFinite ? shortest : 0;
  }

  var jumps = 0;
  var jumpKm = 0.0;
  for (var s = 0; s < chords.length; s++) {
    final double plausible = shortestPlausible(s);
    if (plausible > 0 && chords[s] > 10 * plausible) {
      jumps++;
      jumpKm += chords[s];
    }
  }
  return (jumps, jumpKm / 1000);
}

double _metresBetween(List<double> a, List<double> b) {
  const double r = 0.017453292519943295;
  final double dLat = (b[1] - a[1]) * r;
  final double dLng = (b[0] - a[0]) * r;
  final double h = math.pow(math.sin(dLat / 2), 2) + math.cos(a[1] * r) * math.cos(b[1] * r) * math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371000 * math.asin(math.min(1, math.sqrt(h)));
}

/// Ground distance walked while flags are on, which is the number a person
/// comparing the map with the purple line expects.
double _runMetres(List<List<double>> track, int from, int to) {
  var sum = 0.0;
  for (var i = from; i < to; i++) {
    sum += _metresBetween(track[i], track[i + 1]);
  }
  return sum;
}

double _pathMetres(List<List<double>> track) {
  var sum = 0.0;
  for (var i = 1; i < track.length; i++) {
    sum += _metresBetween(track[i - 1], track[i]);
  }
  return sum;
}

/// Distance from every point to the closest eligible earlier segment, plus the
/// travel gap to that segment. Recomputed here the slow way; only the report
/// uses it, so the classifier's index never has to be trusted for the numbers.
class _MatchAnalysis {
  _MatchAnalysis(this.distances, this.gaps, this.matchedStart, this.flags);

  final List<double> distances;
  final List<double> gaps;
  final Int32List matchedStart;
  final Uint8List flags;

  int get flaggedCount {
    var count = 0;
    for (final int f in flags) {
      if (f == 1) count++;
    }
    return count;
  }

  String distanceHistogram() {
    final List<int> bins = List<int>.filled(8, 0);
    for (var i = 0; i < distances.length; i++) {
      if (flags[i] != 1) continue;
      final double d = distances[i];
      if (d < 0) continue;
      final int bin = d <= 2 ? 0 : d <= 5 ? 1 : d <= 10 ? 2 : d <= 15 ? 3 : d <= 20 ? 4 : d <= 25 ? 5 : d <= 30 ? 6 : 7;
      bins[bin]++;
    }
    final List<String> parts = <String>[];
    for (final (String label, int count) in <(String, int)>[
      ('0-2', bins[0]),
      ('2-5', bins[1]),
      ('5-10', bins[2]),
      ('10-15', bins[3]),
      ('15-20', bins[4]),
      ('20-25', bins[5]),
      ('25-30', bins[6]),
      ('>30', bins[7]),
    ]) {
      parts.add('$label:$count');
    }
    return parts.join(' ');
  }

  /// Points whose nearest earlier segment is inside [tolerance], before the
  /// neighbour-agreement rule decides which of them survive.
  int candidateCount(double tolerance) {
    var count = 0;
    for (final double d in distances) {
      if (d >= 0 && d <= tolerance) count++;
    }
    return count;
  }

  /// Candidates the neighbour rule removed even though they sit within 3 m of an
  /// earlier segment, i.e. genuine retraces lost to sparse or wobbly samples.
  int suppressedExactCount() {
    var count = 0;
    for (var i = 0; i < distances.length; i++) {
      if (flags[i] == 0 && distances[i] >= 0 && distances[i] <= 3) count++;
    }
    return count;
  }

  double meanDistance(int from, int to) {
    var count = 0;
    var sum = 0.0;
    for (var i = from; i <= to; i++) {
      if (flags[i] != 1) continue;
      final double d = i < distances.length ? distances[i] : -1;
      if (d < 0) continue;
      sum += d;
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  /// A genuine retrace walks an earlier stretch of the same track in order, so
  /// the matched segment index moves together with the run. Scattered matched
  /// indices mean the flags came from separate roads, not one repeated path.
  String runShape(int from, int to) {
    var minStart = 1 << 30;
    var maxStart = -1;
    final List<int> xs = <int>[];
    final List<int> ys = <int>[];
    for (var i = from; i <= to; i++) {
      if (flags[i] != 1 || matchedStart[i] < 0) continue;
      xs.add(i);
      ys.add(matchedStart[i]);
      minStart = math.min(minStart, matchedStart[i]);
      maxStart = math.max(maxStart, matchedStart[i]);
    }
    if (ys.length < 3) return 'span=?';
    // Pearson correlation of track order against matched segment order.
    final double meanX = xs.reduce((int a, int b) => a + b) / xs.length;
    final double meanY = ys.reduce((int a, int b) => a + b) / ys.length;
    var cov = 0.0;
    var vx = 0.0;
    var vy = 0.0;
    for (var k = 0; k < xs.length; k++) {
      final double dx = xs[k] - meanX;
      final double dy = ys[k] - meanY;
      cov += dx * dy;
      vx += dx * dx;
      vy += dy * dy;
    }
    final double rho = vx == 0 || vy == 0 ? 0 : cov / math.sqrt(vx * vy);
    return 'span=[$minStart..$maxStart] rho=${rho.toStringAsFixed(2)}';
  }
}

_MatchAnalysis _analyzeMatches(List<List<double>> track, Uint8List flags, {double toleranceMeters = defaultRepeatToleranceMeters, double minGapMeters = defaultMinGapMeters}) {
  final int count = track.length;
  final double minGap = minGapMeters;
  final Float64List travelled = Float64List(count);
  for (var i = 1; i < count; i++) {
    travelled[i] = travelled[i - 1] + _metresBetween(track[i - 1], track[i]);
  }
  double latitudeSum = 0;
  for (final List<double> p in track) {
    latitudeSum += p[1];
  }
  final double centreLatitude = latitudeSum / count;

  double chord(int start) {
    if (start < 0 || start + 1 >= count) return 0;
    return _metresBetween(track[start], track[start + 1]);
  }

  // Same jump rule as the classifier: the shorter neighbour with spacing
  // evidence is the yardstick.
  double shortestPlausibleNeighbour(int start) {
    var shortest = double.infinity;
    for (final int k in <int>[start - 1, start + 1]) {
      final double c = chord(k);
      if (!c.isFinite || c < _refMinSpacingEvidenceMeters) continue;
      if (c < shortest) shortest = c;
    }
    return shortest.isFinite ? shortest : 0;
  }

  double segmentsDistance(int point, int start) {
    final double mx = _metresPerDegreeLng(centreLatitude);
    final double px = (track[point][0] - track[start][0]) * mx;
    final double py = (track[point][1] - track[start][1]) * _mPerDegLat;
    final double ex = (track[start + 1][0] - track[start][0]) * mx;
    final double ey = (track[start + 1][1] - track[start][1]) * _mPerDegLat;
    final double l2 = ex * ex + ey * ey;
    if (l2 == 0) return math.sqrt(px * px + py * py);
    final double t = ((px * ex + py * ey) / l2).clamp(0.0, 1.0).toDouble();
    final double dx = px - t * ex;
    final double dy = py - t * ey;
    return math.sqrt(dx * dx + dy * dy);
  }

  final List<double> distances = List<double>.filled(count, -1);
  final List<double> gaps = List<double>.filled(count, -1);
  final Int32List matchedStart = Int32List(count)..fillRange(0, count, -1);
  for (var i = 0; i < count; i++) {
    var best = double.infinity;
    var bestGap = 0.0;
    var bestStart = -1;
    for (var start = 0; start + 1 < count; start++) {
      if (travelled[start + 1] > travelled[i] - minGap) break;
      final double lengthMeters = _metresBetween(track[start], track[start + 1]);
      if (lengthMeters > 10000) continue;
      final double plausibleNeighbour = shortestPlausibleNeighbour(start);
      if (plausibleNeighbour > 0 && lengthMeters > 10 * plausibleNeighbour) continue;
      final double d = segmentsDistance(i, start);
      if (d < best) {
        best = d;
        bestGap = travelled[i] - travelled[start + 1];
        bestStart = start;
      }
    }
    if (best.isFinite) {
      distances[i] = best;
      gaps[i] = bestGap;
      matchedStart[i] = bestStart;
    }
  }
  return _MatchAnalysis(distances, gaps, matchedStart, flags);
}

/// The same contract computed the slow, obvious way: every eligible earlier
/// segment is tested, nothing is bucketed or split. The rules are restated here
/// on purpose, so a change to them has to be made in both places.
const double _refMinSpacingEvidenceMeters = 1;

Uint8List _referenceFlags(Float64List lngLatPairs, {double toleranceMeters = defaultRepeatToleranceMeters, double minGapMeters = defaultMinGapMeters}) {
  final int count = lngLatPairs.length ~/ 2;
  final Uint8List candidates = Uint8List(count);
  if (count < 2) return candidates;

  final Float64List travelled = Float64List(count);
  for (var i = 1; i < count; i++) {
    final double lng1 = lngLatPairs[(i - 1) * 2];
    final double lat1 = lngLatPairs[(i - 1) * 2 + 1];
    final double lng2 = lngLatPairs[i * 2];
    final double lat2 = lngLatPairs[i * 2 + 1];
    travelled[i] = travelled[i - 1] + (lng1.isFinite && lat1.isFinite && lng2.isFinite && lat2.isFinite ? _metresBetween(<double>[lng1, lat1], <double>[lng2, lat2]) : 0);
  }

  double latitudeSum = 0;
  var latitudeCount = 0;
  for (var i = 0; i < count; i++) {
    final double lat = lngLatPairs[i * 2 + 1];
    if (!lat.isFinite) continue;
    latitudeSum += lat;
    latitudeCount++;
  }
  final double centreLatitude = latitudeCount == 0 ? 0 : latitudeSum / latitudeCount;
  final double mx = _metresPerDegreeLng(centreLatitude);

  double chord(int start) {
    if (start < 0 || start + 1 >= count) return 0;
    final double lng1 = lngLatPairs[start * 2];
    final double lat1 = lngLatPairs[start * 2 + 1];
    final double lng2 = lngLatPairs[(start + 1) * 2];
    final double lat2 = lngLatPairs[(start + 1) * 2 + 1];
    if (!lng1.isFinite || !lat1.isFinite || !lng2.isFinite || !lat2.isFinite) return double.infinity;
    return _metresBetween(<double>[lng1, lat1], <double>[lng2, lat2]);
  }

  double shortestPlausibleNeighbour(int start) {
    var shortest = double.infinity;
    for (final int k in <int>[start - 1, start + 1]) {
      final double c = chord(k);
      if (!c.isFinite || c < _refMinSpacingEvidenceMeters) continue;
      if (c < shortest) shortest = c;
    }
    return shortest.isFinite ? shortest : 0;
  }

  for (var i = 0; i < count; i++) {
    final double lng = lngLatPairs[i * 2];
    final double lat = lngLatPairs[i * 2 + 1];
    if (!lng.isFinite || !lat.isFinite) continue;
    for (var start = 0; start + 1 < count; start++) {
      if (travelled[start + 1] > travelled[i] - minGapMeters) break;
      final double lng1 = lngLatPairs[start * 2];
      final double lat1 = lngLatPairs[start * 2 + 1];
      final double lng2 = lngLatPairs[(start + 1) * 2];
      final double lat2 = lngLatPairs[(start + 1) * 2 + 1];
      if (!lng1.isFinite || !lat1.isFinite || !lng2.isFinite || !lat2.isFinite) continue;
      final double lengthMeters = _metresBetween(<double>[lng1, lat1], <double>[lng2, lat2]);
      if (lengthMeters > 10000) continue;
      final double plausibleNeighbour = shortestPlausibleNeighbour(start);
      if (plausibleNeighbour > 0 && lengthMeters > 10 * plausibleNeighbour) continue;
      final double px = (lng - lng1) * mx;
      final double py = (lat - lat1) * _mPerDegLat;
      final double ex = (lng2 - lng1) * mx;
      final double ey = (lat2 - lat1) * _mPerDegLat;
      final double l2 = ex * ex + ey * ey;
      final double distance;
      if (l2 == 0) {
        distance = math.sqrt(px * px + py * py);
      } else {
        final double t = ((px * ex + py * ey) / l2).clamp(0.0, 1.0).toDouble();
        final double dx = px - t * ex;
        final double dy = py - t * ey;
        distance = math.sqrt(dx * dx + dy * dy);
      }
      if (distance <= toleranceMeters) {
        candidates[i] = 1;
        break;
      }
    }
  }

  final Uint8List flags = Uint8List(count);
  for (var i = 0; i < count; i++) {
    if (candidates[i] == 0) continue;
    final bool neighbour = (i > 0 && candidates[i - 1] == 1) || (i + 1 < count && candidates[i + 1] == 1);
    if (neighbour) flags[i] = 1;
  }
  return flags;
}

String _svg(String title, List<List<double>> track, Uint8List flags) {
  const double width = 2000;
  const double height = 2000;
  const double pad = 60;
  double minLng = double.infinity, maxLng = -double.infinity, minLat = double.infinity, maxLat = -double.infinity;
  for (final List<double> p in track) {
    minLng = math.min(minLng, p[0]);
    maxLng = math.max(maxLng, p[0]);
    minLat = math.min(minLat, p[1]);
    maxLat = math.max(maxLat, p[1]);
  }
  final double cosLat = math.cos((minLat + maxLat) / 2 * math.pi / 180);
  if (cosLat <= 0 || maxLng - minLng <= 0) {
    return '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="60"><text x="10" y="30">$title</text></svg>';
  }
  final double spanLngM = (maxLng - minLng) * 111320 * cosLat;
  final double spanLatM = (maxLat - minLat) * _mPerDegLat;
  final double scale = (width - 2 * pad) / math.max(spanLngM, spanLatM);
  double x(double lng) => pad + (lng - minLng) * 111320 * cosLat * scale;
  double y(double lat) => height - pad - (lat - minLat) * _mPerDegLat * scale;

  final StringBuffer paths = StringBuffer();
  // One polyline per colour run, so the SVG stays small and the boundary is
  // drawn at the same vertex the classifier switched on.
  var i = 0;
  while (i + 1 < track.length) {
    final bool repeat = flags[i] == 1 || flags[i + 1] == 1;
    var j = i;
    while (j + 1 < track.length && ((flags[j] == 1 || flags[j + 1] == 1) == repeat)) {
      j++;
    }
    paths.write('<polyline fill="none" stroke="${repeat ? '#9C27B0' : '#0F53FE'}" stroke-width="2" points="');
    for (var k = i; k <= j; k++) {
      paths.write('${x(track[k][0]).toStringAsFixed(1)},${y(track[k][1]).toStringAsFixed(1)} ');
    }
    paths.write('"/>\n');
    i = j;
  }
  final List<double> start = track.first;
  final List<double> end = track.last;
  return '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height">'
      '<rect width="100%" height="100%" fill="#fafafa"/>'
      '$paths'
      '<circle cx="${x(start[0]).toStringAsFixed(1)}" cy="${y(start[1]).toStringAsFixed(1)}" r="6" fill="#2E7D32"/>'
      '<circle cx="${x(end[0]).toStringAsFixed(1)}" cy="${y(end[1]).toStringAsFixed(1)}" r="6" fill="#C62828"/>'
      '<text x="10" y="24" font-size="18" font-family="sans-serif">$title blue=new purple=repeat</text>'
      '</svg>';
}
