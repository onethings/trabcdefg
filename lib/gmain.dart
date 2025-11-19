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
import 'dart:typed_data'; 

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
  
  bool _customIconsLoaded = false; 

  // Fallback icon: The instantly available system default pin
  final BitmapDescriptor _genericDefaultIcon = BitmapDescriptor.defaultMarker; 
  
  Position? _currentDevicePosition; 

  static const CameraPosition _defaultCameraPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    
    // Start icon loading immediately in the background
    _loadMarkerIcons().then((_) {
      if (mounted) {
        setState(() {
          _customIconsLoaded = true; 
          _updateMarkersOnMap(); // Explicitly redraw markers with new icons
        }); 
      }
    });
  }

  @override
  void didUpdateWidget(covariant LiveTrackingMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    
    final newPosition = traccarProvider.positions.firstWhere(
        (pos) => pos.deviceId == widget.selectedDevice.id,
        orElse: () => Position(),
    );

    // Only update the map if the position data has actually changed
    if (newPosition.id != _currentDevicePosition?.id) 
    {
        _currentDevicePosition = newPosition;
        _updateMap(newPosition); 
    }
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
          if (kDebugMode) {
            // print('Could not load icon: $iconPath. Using fallback.');
          }
        }
      }
    }
    // Load the specific 'default-unknown' icon for Tier 2 fallback
    if (_markerIcons['default-unknown'] == null) {
      _markerIcons['default-unknown'] = await _loadFallbackIcon();
    }
  }

  Future<BitmapDescriptor> _loadFallbackIcon() async {
    try {
      final byteData = await rootBundle.load('assets/images/marker_default_unknown.png');
      final imageData = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(imageData, targetHeight: 100);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteDataResized = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.fromBytes(byteDataResized!.buffer.asUint8List());
    } catch (e) {
      // If even the dedicated custom fallback icon fails to load, return the system default
      return _genericDefaultIcon;
    }
  }

  BitmapDescriptor _getMarkerIcon(Device device) {
    final status = device.status ?? 'unknown';
    final category = device.category ?? 'default';
    final key = '$category-$status';
    
    // 1. Tier 1: Try to find the exact icon
    if (_markerIcons.containsKey(key)) {
      return _markerIcons[key]!;
    }
    
    // 2. Tier 2: Fall back to the preloaded 'default-unknown' custom icon.
    final fallbackCustomIcon = _markerIcons['default-unknown'];
    if (fallbackCustomIcon != null) {
        return fallbackCustomIcon;
    }
    
    // 3. Tier 3: Final fallback: Always return the visible system default pin.
    return _genericDefaultIcon;
  }
  
  void _updateMarkersOnMap() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    
    final lastPosition = traccarProvider.positions.firstWhere(
      (pos) => pos.deviceId == widget.selectedDevice.id,
      orElse: () => Position(),
    );

    // Call the existing _updateMap to redraw the markers with the correct icons
    if (lastPosition.latitude != null && lastPosition.longitude != null) {
      _updateMap(lastPosition); 
    } else if (mounted) {
       // Force a rebuild to ensure the next data pass uses the loaded icons
      setState(() {});
    }
  }

  void _updateMap(Position? currentPosition) {
    if (currentPosition == null || currentPosition.latitude == null || currentPosition.longitude == null) return;

    final newPosition = LatLng(
      currentPosition.latitude!.toDouble(),
      currentPosition.longitude!.toDouble(),
    );

    setState(() {
      _markers.clear();
      
      // Add new position to polyline if different from the last point
      if (_polylineCoordinates.isEmpty || _polylineCoordinates.last != newPosition) {
          _polylineCoordinates.add(newPosition);
      }

      _markers.add(
        Marker(
          markerId: MarkerId(widget.selectedDevice.id!.toString()),
          position: newPosition,
          infoWindow: InfoWindow(
            title: widget.selectedDevice.name ?? 'Device Location',
          ),
          icon: _getMarkerIcon(widget.selectedDevice),
          rotation: currentPosition.course?.toDouble() ?? 0.0,
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
        title: Text('mapLiveRoutes'.tr), //widget.selectedDevice.name ?? 'mapLiveRoutes'.tr
        actions: [
          IconButton(icon: const Icon(Icons.layers), onPressed: _toggleMapType),
          IconButton(
            icon: const Icon(Icons.traffic),
            color: _isTrafficEnabled ? Colors.blue : null,
            onPressed: _toggleTraffic,
          ),
        ],
      ),
      body: Consumer<TraccarProvider>( 
        builder: (context, traccarProvider, child) {
          final lastPosition = traccarProvider.positions.firstWhere(
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
                  if (!_controller.isCompleted) {
                    _controller.complete(controller);
                    _updateMap(lastPosition); 
                  }
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
        final speedKmh = lastPosition.speed != null ? (lastPosition.speed! * 1.852).toStringAsFixed(2) : 'N/A';
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
              Text('deviceStatus'.tr+': ${widget.selectedDevice.status ?? 'N/A'}'),
              const SizedBox(height: 4.0),
              Text(
                'deviceLastUpdate'.tr+': ${lastPosition.deviceTime?.toLocal() ?? 'N/A'}',
              ),
              Text(
                'positionSpeed'.tr+': $speedKmh '+'sharedKmh'.tr,
              ),
              const Divider(),
              Text(
                'deviceSecondaryInfo'.tr+':',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (attributes.containsKey('batteryLevel'))
                ListTile(
                  leading: const Icon(Icons.battery_std),
                  title:  Text('positionBatteryLevel'.tr),
                  subtitle: Text('${attributes['batteryLevel']}%'),
                ),
              if (attributes.containsKey('totalDistance'))
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text('deviceTotalDistance'.tr),
                  subtitle: Text(
                    '${(attributes['totalDistance'] / 1000).toStringAsFixed(2)} km',
                  ),
                ),
              if (attributes.containsKey('engineHours'))
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: Text('reportEngineHours'.tr),
                  subtitle: Text(
                    '${(attributes['engineHours'] / 3600).toStringAsFixed(2)} '+'sharedHourAbbreviation'.tr,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}