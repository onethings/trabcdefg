// scripts/straight_gap_probe.dart
//
// 用 position-kml/ 底下匯出的實際軌跡，驗證「長直線缺口補成實際道路」到底有沒有
// 補到東西，並輸出一份 before / after 的 KML 方便疊在圖上看。
//
//   dart run scripts/straight_gap_probe.dart [kml 檔名...]
//
// 兩點取捨先講清楚，免得看到數字誤會：
//   * KML 只有座標沒有時間。這裡的時間戳按距離內插（30 km/h），讓 clean() 的速度
//     檢查維持中性——這個探針量的是幾何，不是時間軸。
//   * 「長度變長」是預期結果：直線抄近路，沿著路走一定比較遠。真正該看的是
//     「還剩幾條長直線」與最長那條直線的長度。

import 'dart:io';
import 'dart:math';

import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/position_cleaner.dart';

const String _routeUrl = 'https://valhalla1.openstreetmap.de/route';
const double _dpTolerance = 0.00005;
const double _gapMeters = 250;

/// 必須跟 PositionCleaner.fillStraightGaps 的預設值一致，探針才能解釋「還剩幾條
/// 長直線」是補不到還是超過我們願意猜路的距離。
const double _maxGapMeters = 20000;
const double _assumedKmh = 30;
const String _outputDir = 'build/map_match_probe';

Future<void> main(List<String> args) async {
  final files = args.isEmpty ? _defaultFiles() : args;
  Directory(_outputDir).createSync(recursive: true);

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      stdout.writeln('skip (not found): $path');
      continue;
    }
    await _probe(file);
  }
}

List<String> _defaultFiles() {
  final dir = Directory('position-kml');
  if (!dir.existsSync()) return const [];
  return dir.listSync().whereType<File>().where((file) => file.path.endsWith('.kml')).map((file) => file.path).toList()..sort();
}

Future<void> _probe(File file) async {
  final raw = _positionsFromKml(file.readAsStringSync());
  final cleaned = PositionCleaner.clean(raw);
  final simplified = PositionCleaner.douglasPeucker(cleaned, tolerance: _dpTolerance);
  final before = _chordStats(simplified);

  final stopwatch = Stopwatch()..start();
  final matched = await PositionCleaner.fillStraightGaps(simplified, routeUrl: _routeUrl, maxGapMeters: _maxGapMeters, maxRequests: 60, totalBudget: const Duration(seconds: 60));
  stopwatch.stop();
  final after = _chordStats(matched);
  final splices = _spliceStats(simplified, matched);
  final stillStraight = (before.longChords - splices.filled).clamp(0, before.longChords);
  final overBudget = (stillStraight - before.overLimitChords).clamp(0, stillStraight);

  stdout
    ..writeln('== ${file.path}')
    ..writeln('   points    raw ${raw.length} -> clean ${cleaned.length} -> dp ${simplified.length} -> matched ${matched.length}')
    ..writeln('   gaps      ${before.longChords} chords >= ${_gapMeters.round()} m -> $stillStraight still straight (${splices.filled} filled)')
    ..writeln('   left      ${before.overLimitChords} over ${(_maxGapMeters / 1000).round()} km (too far to guess a route), $overBudget not reached by the request budget')
    ..writeln('   longest   ${before.longestChord.round()} m -> ${after.longestChord.round()} m')
    ..writeln('   length    ${_km(before.meters)} km -> ${_km(after.meters)} km (+${_percent(before.meters, after.meters)}%)')
    ..writeln('   splicing  ${matched.length - simplified.length} points added, most detour ${splices.maxDeviation.round()} m off the straight line, ${stopwatch.elapsed.inSeconds}s');

  if (!identical(simplified, matched)) {
    final name = file.uri.pathSegments.last.replaceAll('.kml', '');
    final out = File('$_outputDir/$name-before-after.kml');
    out.writeAsStringSync(_beforeAfterKml(name, simplified, matched));
    stdout.writeln('   wrote     ${out.path}');
  }
}

/// 讀 KML 的 `<coordinates>`，每個點配一個按距離推算的時間戳。
List<api.Position> _positionsFromKml(String kml) {
  final coordinates = RegExp(r'<coordinates>([\s\S]*?)</coordinates>').firstMatch(kml)?.group(1)?.trim() ?? '';
  final points = <List<double>>[];
  for (final token in coordinates.split(RegExp(r'\s+'))) {
    final parts = token.split(',');
    if (parts.length < 2) continue;
    final lon = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lat == null || lon == null) continue;
    points.add([lat, lon]);
  }

  final start = DateTime.utc(2026, 1, 1);
  var elapsed = 0.0;
  final positions = <api.Position>[];
  for (var i = 0; i < points.length; i++) {
    if (i > 0) elapsed += _meters(points[i - 1], points[i]) / (_assumedKmh * 1000 / 3600);
    final time = start.add(Duration(milliseconds: (elapsed * 1000).round()));
    positions.add(api.Position(latitude: points[i][0], longitude: points[i][1], fixTime: time, deviceTime: time, speed: _assumedKmh / 1.852, valid: true));
  }
  return positions;
}

class _ChordStats {
  const _ChordStats(this.meters, this.longChords, this.longestChord, this.overLimitChords);

  final double meters;
  final int longChords;
  final double longestChord;
  final int overLimitChords;
}

_ChordStats _chordStats(List<api.Position> track) {
  var meters = 0.0;
  var longChords = 0;
  var overLimitChords = 0;
  var longest = 0.0;
  for (var i = 0; i < track.length - 1; i++) {
    final chord = _haversine(track[i].latitude!.toDouble(), track[i].longitude!.toDouble(), track[i + 1].latitude!.toDouble(), track[i + 1].longitude!.toDouble());
    meters += chord;
    if (chord >= _gapMeters) longChords++;
    if (chord > _maxGapMeters) overLimitChords++;
    if (chord > longest) longest = chord;
  }
  return _ChordStats(meters, longChords, longest, overLimitChords);
}

class _SpliceStats {
  const _SpliceStats(this.filled, this.maxDeviation);

  final int filled;
  final double maxDeviation;
}

/// 數一下有幾段真的補進新點，並量那段新幾何偏離原本直線多遠：偏離 0 表示只是
/// 把直線原樣接回去，偏離數十到數百公尺表示它真的沿著別的路走了。
_SpliceStats _spliceStats(List<api.Position> simplified, List<api.Position> matched) {
  final anchors = Set<api.Position>.identity()..addAll(simplified);
  var filled = 0;
  var maxDeviation = 0.0;
  List<double>? anchor;
  var run = <List<double>>[];

  for (final point in matched) {
    final coord = [point.latitude!.toDouble(), point.longitude!.toDouble()];
    if (anchors.contains(point)) {
      if (anchor != null && run.isNotEmpty) {
        filled++;
        final deviation = _maxOffChord(anchor, run, coord);
        if (deviation > maxDeviation) maxDeviation = deviation;
      }
      anchor = coord;
      run = <List<double>>[];
    } else {
      run.add(coord);
    }
  }
  return _SpliceStats(filled, maxDeviation);
}

/// [run] 這串點最多偏離 a→b 這條直線多少公尺（以 a 為原點的等距投影）。
double _maxOffChord(List<double> a, List<List<double>> run, List<double> b) {
  const metersPerDegree = 111320.0;
  final lonScale = metersPerDegree * cos(a[0] * pi / 180);
  double x(List<double> p) => (p[1] - a[1]) * lonScale;
  double y(List<double> p) => (p[0] - a[0]) * metersPerDegree;

  final bx = x(b);
  final by = y(b);
  final length = sqrt(bx * bx + by * by);
  if (length == 0) return 0;

  var worst = 0.0;
  for (final point in run) {
    final cross = (bx * y(point) - by * x(point)).abs() / length;
    if (cross > worst) worst = cross;
  }
  return worst;
}

String _beforeAfterKml(String name, List<api.Position> before, List<api.Position> after) {
  String line(List<api.Position> track) => track.map((p) => '${p.longitude},${p.latitude},0').join(' ');
  return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>$name before/after</name>
<Style id="before"><LineStyle><color>ff0000ff</color><width>4</width></LineStyle></Style>
<Style id="after"><LineStyle><color>ffff0000</color><width>4</width></LineStyle></Style>
<Placemark><name>before (clean + Douglas-Peucker)</name><styleUrl>#before</styleUrl>
<LineString><tessellate>1</tessellate><coordinates>${line(before)}</coordinates></LineString></Placemark>
<Placemark><name>after (gaps filled with road geometry)</name><styleUrl>#after</styleUrl>
<LineString><tessellate>1</tessellate><coordinates>${line(after)}</coordinates></LineString></Placemark>
</Document></kml>
''';
}

double _meters(List<double> a, List<double> b) => _haversine(a[0], a[1], b[0], b[1]);

double _haversine(double lat1Deg, double lon1Deg, double lat2Deg, double lon2Deg) {
  const earthRadius = 6371000.0;
  final lat1 = lat1Deg * pi / 180;
  final lat2 = lat2Deg * pi / 180;
  final deltaLat = (lat2Deg - lat1Deg) * pi / 180;
  final deltaLon = (lon2Deg - lon1Deg) * pi / 180;
  final h = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
  return 2 * earthRadius * asin(min(1.0, sqrt(h)));
}

String _km(double meters) => (meters / 1000).toStringAsFixed(2);

String _percent(double before, double after) => before <= 0 ? '-' : ((after - before) / before * 100).toStringAsFixed(1);
