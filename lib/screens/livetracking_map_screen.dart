// lib/screens/livetracking_map_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';

class LiveTrackingMapScreen extends StatefulWidget {
  final Device selectedDevice;
  const LiveTrackingMapScreen({super.key, required this.selectedDevice});

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  MapType _mapType = MapType.normal;
  bool _isTrafficEnabled = false;
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _isCameraLocked = true;
  late final Future<void> _iconLoadingFuture;

  static const CameraPosition _defaultCameraPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _iconLoadingFuture = _loadMarkerIcons();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely update the map after the icons are loaded and dependencies change.
    _iconLoadingFuture.then((_) {
      final provider = Provider.of<TraccarProvider>(context, listen: false);
      final lastPosition = provider.positions.firstWhere(
        (pos) => pos.deviceId == widget.selectedDevice.id,
        orElse: () => Position(),
      );
      _updateMap(lastPosition);
    });
  }

  @override
  void dispose() {
    _controller.future.then((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    const categories = [
      'animal', 'arrow', 'bicycle', 'boat', 'bus', 'car', 'crane', 'default',
      'helicopter', 'motorcycle', 'null', 'offroad', 'person', 'pickup', 'plane',
      'scooter', 'ship', 'tractor', 'train', 'tram', 'trolleybus', 'truck', 'van',
    ];
    const statuses = ['online', 'offline', 'static', 'idle', 'unknown'];

    for (final category in categories) {
      for (final status in statuses) {
        final iconPath = 'assets/images/marker_${category}_$status.png';
        try {
          final byteData = await rootBundle.load(iconPath);
          final imageData = byteData.buffer.asUint8List();
          final codec = await ui.instantiateImageCodec(imageData, targetHeight: 100);
          final frameInfo = await codec.getNextFrame();
          final image = frameInfo.image;
          final byteDataResized = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteDataResized != null) {
            final bitmap = BitmapDescriptor.fromBytes(byteDataResized.buffer.asUint8List());
            _markerIcons['$category-$status'] = bitmap;
          }
        } catch (e) {
          print('Could not load icon: $iconPath. Using fallback.');
        }
      }
    }
    _markerIcons['default-unknown'] = await _loadDefaultIcon();
  }

  Future<BitmapDescriptor> _loadDefaultIcon() async {
    final byteData = await rootBundle.load('assets/images/marker_default_unknown.png');
    final imageData = byteData.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(imageData, targetHeight: 100);
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;
    final byteDataResized = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteDataResized!.buffer.asUint8List());
  }

  BitmapDescriptor _getMarkerIcon(Device device) {
    final status = device.status ?? 'unknown';
    final category = device.category ?? 'default';
    final key = '$category-$status';
    return _markerIcons[key] ?? _markerIcons['default-unknown']!;
  }

  void _updateMap(Position? lastPosition) {
    if (lastPosition == null || lastPosition.latitude == null || lastPosition.longitude == null) return;

    final newPosition = LatLng(
      lastPosition.latitude!.toDouble(),
      lastPosition.longitude!.toDouble(),
    );

    setState(() {
      _markers.clear();
      _polylines.clear();
      _polylineCoordinates.add(newPosition);

      _markers.add(
        Marker(
          markerId: MarkerId(widget.selectedDevice.id!.toString()),
          position: newPosition,
          infoWindow: InfoWindow(
            title: widget.selectedDevice.name ?? 'Device Location',
          ),
          icon: _getMarkerIcon(widget.selectedDevice),
          rotation: lastPosition.course?.toDouble() ?? 0.0,
        ),
      );

      _polylines.add(
        Polyline(
          polylineId: PolylineId(widget.selectedDevice.id!.toString()),
          points: _polylineCoordinates,
          color: Colors.blue,
          width: 5,
        ),
      );
    });

    if (_isCameraLocked) {
      _controller.future.then((controller) {
        controller.animateCamera(
          CameraUpdate.newLatLng(newPosition),
        );
      });
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal ? MapType.satellite : MapType.normal;
    });
  }

  void _toggleTraffic() {
    setState(() {
      _isTrafficEnabled = !_isTrafficEnabled;
    });
  }

  Future<void> _recenter(Position? lastPosition) async {
    if (lastPosition == null || lastPosition.latitude == null || lastPosition.longitude == null) return;

    final controller = await _controller.future;
    final position = LatLng(
      lastPosition.latitude!.toDouble(),
      lastPosition.longitude!.toDouble(),
    );

    setState(() {
      _isCameraLocked = true;
    });

    controller.animateCamera(
      CameraUpdate.newLatLngZoom(position, 17.0),
    );
  }

  Future<void> _zoomIn() async {
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.zoomIn(),
    );
  }

  Future<void> _zoomOut() async {
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.zoomOut(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedDevice.name ?? 'Map'),
        actions: [
          IconButton(icon: const Icon(Icons.layers), onPressed: _toggleMapType),
          IconButton(
            icon: const Icon(Icons.traffic),
            color: _isTrafficEnabled ? Colors.blue : null,
            onPressed: _toggleTraffic,
          ),
        ],
      ),
      body: FutureBuilder(
        future: _iconLoadingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final lastPosition = Provider.of<TraccarProvider>(context).positions.firstWhere(
            (pos) => pos.deviceId == widget.selectedDevice.id,
            orElse: () => Position(),
          );
          
          final initialCameraPosition =
              lastPosition.latitude != null && lastPosition.longitude != null
                  ? CameraPosition(
                      target: LatLng(
                        lastPosition.latitude!.toDouble(),
                        lastPosition.longitude!.toDouble(),
                      ),
                      zoom: 14.0,
                    )
                  : _defaultCameraPosition;

          return Stack(
            children: [
              GoogleMap(
                mapType: _mapType,
                initialCameraPosition: initialCameraPosition,
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
                trafficEnabled: _isTrafficEnabled,
                onCameraMoveStarted: () {
                  setState(() {
                    _isCameraLocked = false;
                  });
                },
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: "zoomIn",
                      mini: true,
                      onPressed: _zoomIn,
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: "zoomOut",
                      mini: true,
                      onPressed: _zoomOut,
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: "recenter",
                      mini: true,
                      onPressed: () => _recenter(lastPosition),
                      child: const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomSheet: _buildBottomSheet(context),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return Consumer<TraccarProvider>(
      builder: (context, provider, child) {
        final lastPosition = provider.positions.firstWhere(
          (pos) => pos.deviceId == widget.selectedDevice.id,
          orElse: () => Position(),
        );
        final attributes = lastPosition.attributes as Map<String, dynamic>? ?? {};

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.selectedDevice.name ?? 'Unknown Device',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8.0),
              Text('Status: ${widget.selectedDevice.status ?? 'N/A'}'),
              const SizedBox(height: 4.0),
              Text(
                'Last update: ${lastPosition.deviceTime?.toLocal() ?? 'N/A'}',
              ),
              Text(
                'Speed: ${lastPosition.speed?.toStringAsFixed(2) ?? 'N/A'} km/h',
              ),
              const Divider(),
              const Text(
                'Detailed Information:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (attributes.containsKey('batteryLevel'))
                ListTile(
                  leading: const Icon(Icons.battery_std),
                  title: const Text('Battery Level'),
                  subtitle: Text('${attributes['batteryLevel']}%'),
                ),
              if (attributes.containsKey('totalDistance'))
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: const Text('Total Distance'),
                  subtitle: Text(
                    '${(attributes['totalDistance'] / 1000).toStringAsFixed(2)} km',
                  ),
                ),
              if (attributes.containsKey('engineHours'))
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Engine Hours'),
                  subtitle: Text(
                    '${(attributes['engineHours'] / 3600).toStringAsFixed(2)} h',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}