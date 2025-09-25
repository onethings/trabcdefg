// lib/screens/history_route_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryRouteScreen extends StatefulWidget {
  const HistoryRouteScreen({super.key});

  @override
  State<HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<HistoryRouteScreen> {
  GoogleMapController? mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<api.Position> _positions = [];
  double _playbackPosition = 0.0;
  Marker? _playbackMarker;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  BitmapDescriptor? _playbackMarkerIcon;
  BitmapDescriptor? _redDotMarkerIcon;
  PolylineId _fullRoutePolylineId = PolylineId('full_route');
  PolylineId _playedRoutePolylineId = PolylineId('played_route');
  MapType _mapType = MapType.normal;
  int? _deviceId;
  DateTime? _historyFrom;
  DateTime? _historyTo;
  int? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _loadHistoryParamsAndFetchRoute();
    _loadPlaybackMarkerIcon();
    _createDotMarkerIcon(Colors.red).then((icon) {
      _redDotMarkerIcon = icon;
    });
  }

  Future<void> _loadHistoryParamsAndFetchRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromString = prefs.getString('historyFrom');
    final toString = prefs.getString('historyTo');

    if (deviceId != null && fromString != null && toString != null) {
      setState(() {
        _deviceId = deviceId;
        _historyFrom = DateTime.tryParse(fromString);
        _historyTo = DateTime.tryParse(toString);
      });
      _fetchHistoryRoute();
    } else {
      print('Missing device ID or date range for history route.');
    }
  }

  Future<BitmapDescriptor> _createDotMarkerIcon(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final double radius = 5.0;
    final Size size = Size(radius * 2, radius * 2);

    canvas.drawCircle(Offset(radius, radius), radius, paint);

    final ui.Image img = await pictureRecorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Color _getSpeedColor(double speed) {
    if (speed <= 10) {
      return Colors.green;
    } else if (speed > 10 && speed <= 50) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  Future<void> _loadPlaybackMarkerIcon() async {
    try {
      final byteData = await rootBundle.load('assets/images/arrow.png');
      final imageData = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        imageData,
        targetHeight: 70,
        targetWidth: 70,
      );
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteDataResized = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      _playbackMarkerIcon = BitmapDescriptor.fromBytes(
        byteDataResized!.buffer.asUint8List(),
      );
    } catch (e) {
      print('Error loading playback marker icon: $e');
    }
  }

  void _fetchHistoryRoute() async {
     final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedDeviceId = prefs.getInt('selectedDeviceId');
    });
    if (_deviceId == null || _historyFrom == null || _historyTo == null) return;
    
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final positionsApi = api.PositionsApi(traccarProvider.apiClient);
    final positions = await positionsApi.positionsGet(
      deviceId: _selectedDeviceId,//[_deviceId!],
      from: _historyFrom!,
      to: _historyTo!,
    );

    setState(() {
      _positions = positions ?? [];
      _drawFullRoute();
    });
  }

  void _drawFullRoute() async {
    if (_positions.isEmpty) return;

    final points = _positions
        .map(
          (pos) => LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble()),
        )
        .toList();
    final fullRoutePolyline = Polyline(
      polylineId: _fullRoutePolylineId,
      points: points,
      color: Colors.grey.withOpacity(0.5),
      width: 5,
    );

    _markers.clear();

    List<Future<Marker>> markerFutures = [];

    _positions.asMap().forEach((index, pos) {
      final speed = pos.speed ?? 0.0;
      final color = _getSpeedColor(speed.toDouble());

      markerFutures.add(
        _createDotMarkerIcon(color).then(
          (icon) => Marker(
            markerId: MarkerId('point_$index'),
            position: LatLng(
              pos.latitude!.toDouble(),
              pos.longitude!.toDouble(),
            ),
            icon: icon,
          ),
        ),
      );
    });

    final createdMarkers = await Future.wait(markerFutures);

    setState(() {
      _polylines = {fullRoutePolyline};
      _markers = createdMarkers.toSet();
    });

    _animateCameraToRoute();
  }

  void _togglePlayback() {
    if (_positions.isEmpty) return;

    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) {
          if (_playbackPosition >= _positions.length - 1) {
            _playbackTimer?.cancel();
            setState(() {
              _isPlaying = false;
              _playbackPosition = 0.0;
              _updatePlaybackMarker();
            });
          } else {
            setState(() {
              _playbackPosition += 0.5;
              _updatePlaybackMarker();
            });
          }
        });
      } else {
        _playbackTimer?.cancel();
        _updatePlaybackMarker();
      }
    });
  }

  void _updatePlaybackMarker() {
    final int index = _playbackPosition.toInt();
    if (_positions.isEmpty || index >= _positions.length) return;

    final currentPosition = _positions[index];
    final nextPosition = (index + 1) < _positions.length
        ? _positions[index + 1]
        : currentPosition;

    double bearing = 0.0;
    if (currentPosition.latitude != nextPosition.latitude ||
        currentPosition.longitude != nextPosition.longitude) {
      final lat1 = _degreesToRadians(currentPosition.latitude!.toDouble());
      final lon1 = _degreesToRadians(currentPosition.longitude!.toDouble());
      final lat2 = _degreesToRadians(nextPosition.latitude!.toDouble());
      final lon2 = _degreesToRadians(nextPosition.longitude!.toDouble());

      final dLon = lon2 - lon1;
      final y = sin(dLon) * cos(lat2);
      final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
      bearing = atan2(y, x) * (180 / pi);
    }

    final newLatLng = LatLng(
      currentPosition.latitude!.toDouble(),
      currentPosition.longitude!.toDouble(),
    );

    _playbackMarker = Marker(
      markerId: const MarkerId('playback_marker'),
      position: newLatLng,
      icon: _playbackMarkerIcon ?? BitmapDescriptor.defaultMarker,
      rotation: bearing,
      anchor: const Offset(0.5, 0.5),
    );

    final playedPoints = _positions
        .sublist(0, index + 1)
        .map(
          (pos) => LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble()),
        )
        .toList();
    final playedRoutePolyline = Polyline(
      polylineId: _playedRoutePolylineId,
      points: playedPoints,
      color: const Color(0xFF0F53FE),
      width: 5,
    );

    mapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));

    setState(() {
      _markers.removeWhere(
        (marker) => marker.markerId.value == 'playback_marker',
      );
      _markers.add(_playbackMarker!);
      _polylines.removeWhere(
        (polyline) => polyline.polylineId.value == 'played_route',
      );
      _polylines.add(playedRoutePolyline);
    });
  }

  void _animateCameraToRoute() {
    if (mapController != null && _positions.isNotEmpty) {
      double minLat = _positions.first.latitude!.toDouble();
      double maxLat = _positions.first.latitude!.toDouble();
      double minLon = _positions.first.longitude!.toDouble();
      double maxLon = _positions.first.longitude!.toDouble();

      for (var pos in _positions) {
        minLat = min(minLat, pos.latitude!.toDouble());
        maxLat = max(maxLat, pos.latitude!.toDouble());
        minLon = min(minLon, pos.longitude!.toDouble());
        maxLon = max(maxLon, pos.longitude!.toDouble());
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLon),
        northeast: LatLng(maxLat, maxLon),
      );
      mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm:ss').format(time);
  }

  String get time {
    if (_positions.isEmpty) return 'N/A';
    final index = _playbackPosition.toInt().clamp(0, _positions.length - 1);
    return _formatTime(_positions[index].serverTime!);
  }

  String get speed {
    if (_positions.isEmpty) return 'N/A';
    final index = _playbackPosition.toInt().clamp(0, _positions.length - 1);
    final speed = _positions[index].speed ?? 0.0;
    return '${speed.toStringAsFixed(2)} km/h';
  }

  String get distanceText {
    if (_positions.isEmpty) return 'N/A';
    double totalDistance = 0.0;
    for (int i = 0; i < _positions.length - 1; i++) {
      totalDistance += _calculateDistance(
        LatLng(
          _positions[i].latitude!.toDouble(),
          _positions[i].longitude!.toDouble(),
        ),
        LatLng(
          _positions[i + 1].latitude!.toDouble(),
          _positions[i + 1].longitude!.toDouble(),
        ),
      );
    }
    return '${totalDistance.toStringAsFixed(2)} km';
  }

  double _calculateDistance(LatLng latLng1, LatLng latLng2) {
    const double earthRadius = 6371;
    final double dLat = _degreesToRadians(latLng2.latitude - latLng1.latitude);
    final double dLon = _degreesToRadians(
      latLng2.longitude - latLng1.longitude,
    );

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(latLng1.latitude)) *
            cos(_degreesToRadians(latLng2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    final maxSliderValue = _positions.isNotEmpty
        ? (_positions.length - 1).toDouble()
        : 0.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Route History')),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              _animateCameraToRoute();
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 15,
            ),
            mapType: _mapType,
            markers: _markers,
            polylines: _polylines,
          ),
          Positioned(
            top: 10,
            right: 10,
            child: FloatingActionButton(
              onPressed: _toggleMapType,
              child: const Icon(Icons.layers),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: _positions.isNotEmpty
                            ? _togglePlayback
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _playbackPosition,
                    min: 0,
                    max: maxSliderValue,
                    onChanged: (newValue) {
                      setState(() {
                        _playbackPosition = newValue;
                        _updatePlaybackMarker();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [const Text('Time'), Text(time)]),
                      Column(children: [const Text('Speed'), Text(speed)]),
                      Column(
                        children: [const Text('Distance'), Text(distanceText)],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}