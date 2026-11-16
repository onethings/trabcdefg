// Standalone probe for the played-track line, with no server involved.
//
// Replays the layer sequence HistoryRouteScreen performs (route source and layer,
// then a played source and layer coloured per feature, then about 10 Hz
// setGeoJsonSource pushes that split the walked prefix into blue first-pass and
// purple repeat runs) over a synthetic out-and-back track. Run it on a device and
// look at the map.
//
//   flutter run -t lib/probe_played_line.dart -d <device id>
//
// The overlay reports the playback position, how many pushes landed, and the last
// error, so a missing line can be told apart from a failing push.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:trabcdefg/src/utils/playback_pacing.dart';
import 'package:trabcdefg/src/utils/publish_budget.dart';
import 'package:trabcdefg/src/utils/repeat_pass.dart';

void main() => runApp(const _ProbeApp());

const String _routeSourceId = "history_route_source";
const String _routeLayerId = "history_route_layer";
const String _playedSourceId = "played_route_source";
const String _playedLayerId = "played_layer";

class _ProbeApp extends StatelessWidget {
  const _ProbeApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: _ProbeScreen());
  }
}

class _ProbeScreen extends StatefulWidget {
  const _ProbeScreen();

  @override
  State<_ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<_ProbeScreen> {
  MapLibreMapController? _controller;
  final PublishBudget _budget = PublishBudget(100);
  bool _pushInFlight = false;
  Timer? _ticker;

  double _position = 0;
  int _pushes = 0;
  int _pushErrors = 0;
  int _repeatPoints = 0;
  String _lastError = "";
  String _status = "waiting for style";

  static final List<List<double>> _track = _buildTrack();
  static final Uint8List _repeatFlags = classifyRepeatPasses(_packed(_track));

  static Float64List _packed(List<List<double>> lngLat) {
    final Float64List packed = Float64List(lngLat.length * 2);
    for (var i = 0; i < lngLat.length; i++) {
      packed[i * 2] = lngLat[i][0];
      packed[i * 2 + 1] = lngLat[i][1];
    }
    return packed;
  }

  /// Out along a street and back with a small offset, so the return leg is a
  /// repeat pass.
  static List<List<double>> _buildTrack() {
    const double latitude = 25.033;
    final double metresPerDegreeLng = 111320.0 * cos(latitude * pi / 180);
    final List<List<double>> points = <List<double>>[];
    const int samples = 600;
    const double metres = 3000;

    for (var i = 0; i <= samples; i++) {
      final double along = metres * i / samples;
      points.add([121.545 + along / metresPerDegreeLng, latitude + 0.00004 * sin(i / 9)]);
    }
    for (var i = samples; i >= 0; i--) {
      final double along = metres * i / samples;
      points.add([121.545 + along / metresPerDegreeLng, latitude + 0.00004 * sin(i / 9) + 0.00007]);
    }
    return points;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _status = "style loaded, drawing");

    _repeatPoints = _repeatFlags.where((f) => f == 1).length;

    final Map<String, dynamic> routeGeoJson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {"color": "#808080"},
          "geometry": {"type": "LineString", "coordinates": _track},
        },
      ],
    };
    await controller.addSource(_routeSourceId, GeojsonSourceProperties(data: routeGeoJson));
    await controller.addLineLayer(_routeSourceId, _routeLayerId, const LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 4.0, lineOpacity: 0.8, lineJoin: 'round', lineCap: 'round'));

    await controller.addSource(_playedSourceId, const GeojsonSourceProperties(data: {"type": "FeatureCollection", "features": []}));
    await controller.addLineLayer(_playedSourceId, _playedLayerId, const LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 6.5, lineOpacity: 1.0, lineJoin: 'round', lineCap: 'round'));

    await controller.moveCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(25.028, 121.540), northeast: LatLng(25.040, 121.585)),
      left: 20,
      right: 20,
      top: 20,
      bottom: 20,
    ));

    setState(() => _status = "playing");

    int lastMs = 0;
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final double deltaSeconds = lastMs == 0 ? 1 / 60 : ((nowMs - lastMs) / 1000).clamp(0.0, 0.1);
      lastMs = nowMs;
      final double maxLimit = (_track.length - 1).toDouble();
      _position = advancePlaybackPosition(position: _position, maxPosition: maxLimit, speed: 20, deltaSeconds: deltaSeconds);
      _push();
      if (_position >= maxLimit) {
        timer.cancel();
        setState(() => _status = _pushErrors == 0 ? "finished, clean" : "finished with errors");
      }
    });
  }

  void _push() {
    final controller = _controller;
    if (controller == null) return;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_pushInFlight || !_budget.due(nowMs)) return;
    _pushInFlight = true;

    final int safeIdx = _position.floor().clamp(0, _track.length - 1);
    final int step = max(1, (safeIdx + 1) ~/ 1500);

    final List<Map<String, dynamic>> features = <Map<String, dynamic>>[];
    List<List<double>> run = <List<double>>[];
    bool runIsRepeat = false;

    void flushRun() {
      if (run.length < 2) return;
      features.add({
        'type': 'Feature',
        'properties': {'color': runIsRepeat ? '#9C27B0' : '#0F53FE'},
        'geometry': {'type': 'LineString', 'coordinates': run},
      });
    }

    void addVertex(List<double> vertex, bool repeat) {
      if (run.isEmpty) {
        run = [vertex];
        runIsRepeat = repeat;
        return;
      }
      if (repeat == runIsRepeat) {
        run.add(vertex);
        return;
      }
      final List<double> junction = run.last;
      flushRun();
      run = [junction, vertex];
      runIsRepeat = repeat;
    }

    for (var i = 0; i <= safeIdx; i += step) {
      addVertex(_track[i], _repeatFlags[i] == 1);
    }
    flushRun();

    if (features.isEmpty) {
      _pushInFlight = false;
      return;
    }

    unawaited(
      controller
          .setGeoJsonSource(_playedSourceId, <String, dynamic>{'type': 'FeatureCollection', 'features': features})
          .then((_) {
            _pushes++;
            if (mounted) setState(() {});
          })
          .catchError((Object error) {
            _pushErrors++;
            _lastError = error.toString();
            debugPrint('PROBE push error: $error');
            if (mounted) setState(() {});
          })
          .whenComplete(() => _pushInFlight = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: (c) => _controller = c,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: const CameraPosition(target: LatLng(25.033, 121.565), zoom: 13),
            styleString: 'assets/styles/liberty.json',
          ),
          Positioned(
            top: 40,
            left: 12,
            right: 12,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: Text(
                "$_status\nposition ${_position.toStringAsFixed(1)} / ${_track.length - 1}\npushes $_pushes, errors $_pushErrors\nrepeat flags $_repeatPoints of ${_track.length}\n$_lastError",
                style: const TextStyle(fontSize: 13, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
