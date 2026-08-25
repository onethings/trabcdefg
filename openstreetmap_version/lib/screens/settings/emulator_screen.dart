// emulator_screen.dart
// A device emulator screen that lets users tap on a map to send positions to the Traccar server.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class EmulatorScreen extends StatefulWidget {
  const EmulatorScreen({super.key});

  @override
  State<EmulatorScreen> createState() => _EmulatorScreenState();
}

class _EmulatorScreenState extends State<EmulatorScreen> {
  MapLibreMapController? _mapController;
  bool _isStyleLoaded = false;
  bool _isSending = false;
  int? _selectedDeviceId;
  String? _lastSentStatus;

  /// Track positions sent during this session for display on the map
  final List<LatLng> _sentPositions = [];

  /// Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearch = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onStyleLoaded() async {
    _isStyleLoaded = true;
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  List<api.Device> _getDevices() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    return traccarProvider.devices;
  }

  String _getServerOrigin() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final uri = Uri.parse(traccarProvider.apiClient.basePath);
    return '${uri.scheme}://${uri.host}${uri.port == 80 || uri.port == 443 ? '' : ':${uri.port}'}';
  }

  Future<void> _sendPosition(LatLng point) async {
    if (_selectedDeviceId == null) {
      Get.snackbar('sharedEmulator'.tr, 'Please select a device first.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() {
      _isSending = true;
      _lastSentStatus = null;
    });

    try {
      final devices = _getDevices();
      final device = devices.firstWhere((d) => d.id == _selectedDeviceId, orElse: () => api.Device());

      if (device.uniqueId == null) {
        throw Exception('Device unique ID not found');
      }

      final serverOrigin = _getServerOrigin();

      // Match the traccar-web emulator behavior: POST to server origin with
      // form params: id (uniqueId), lat, lon
      final body = {'id': device.uniqueId!, 'lat': point.latitude.toString(), 'lon': point.longitude.toString()};

      final uri = Uri.parse(serverOrigin);
      await http.post(uri, headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: body);

      if (mounted) {
        // Calculate course from previous position (if available)
        double course = 0;
        if (_sentPositions.isNotEmpty) {
          final prev = _sentPositions.last;
          course = _calculateBearing(prev, point);
        }

        setState(() {
          _lastSentStatus = '✓ ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          _sentPositions.add(point);
        });

        // Update device marker (arrow) to new position
        await _addDeviceMarker(point, course);

        // Update sent marker on map
        await _updateSentMarker(point);

        // Camera animate to the sent position
        _mapController?.animateCamera(CameraUpdate.newLatLng(point), duration: const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('Failed to send position: $e');
      if (mounted) {
        setState(() {
          _lastSentStatus = '✗ $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _clearPositions() async {
    setState(() {
      _sentPositions.clear();
      _lastSentStatus = null;
    });
    await _rebuildAllMarkers();
  }

  // --- Device focus ---

  Future<void> _focusOnDevice(int? deviceId) async {
    if (deviceId == null || _mapController == null || !_isStyleLoaded) return;

    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final position = traccarProvider.getPosition(deviceId);

    if (position != null && position.latitude != null && position.longitude != null) {
      final latLng = LatLng(position.latitude!.toDouble(), position.longitude!.toDouble());
      await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15.0), duration: const Duration(milliseconds: 800));
      await _addDeviceMarker(latLng, position.course?.toDouble() ?? 0.0);
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * pi / 180;
    final double lon1 = start.longitude * pi / 180;
    final double lat2 = end.latitude * pi / 180;
    final double lon2 = end.longitude * pi / 180;
    return (atan2(sin(lon2 - lon1) * cos(lat2), cos(lat1) * sin(lat2) - cos(lat1) * cos(lat2) * cos(lon2 - lon1)) * 180 / pi + 360) % 360;
  }

  IconData _getPlaceIcon(String type) {
    switch (type) {
      case 'city':
      case 'town':
      case 'village':
        return Icons.location_city;
      case 'street':
      case 'road':
        return Icons.signpost;
      case 'amenity':
      case 'building':
        return Icons.business;
      case 'country':
      case 'state':
      case 'region':
        return Icons.flag;
      default:
        return Icons.place;
    }
  }

  // Tracks the latest device position for use in _rebuildAllMarkers
  LatLng? _deviceLatLng;

  Future<void> _addDeviceMarker(LatLng point, double course) async {
    if (_mapController == null || !_isStyleLoaded) return;
    _deviceLatLng = point;
    await _rebuildAllMarkers();
  }

  /// Rebuilds ALL markers from scratch to avoid state conflicts.
  Future<void> _rebuildAllMarkers() async {
    if (_mapController == null || !_isStyleLoaded) return;

    // Clear everything and rebuild
    try {
      await _mapController!.clearSymbols();
      await _mapController!.clearCircles();
    } catch (e) {
      debugPrint('Error clearing annotations: $e');
    }

    // Add device marker as a circle
    if (_deviceLatLng != null) {
      try {
        await _mapController!.addCircle(CircleOptions(geometry: _deviceLatLng, circleColor: '#0F53FE', circleRadius: 10, circleStrokeColor: '#FFFFFF', circleStrokeWidth: 3));
      } catch (e) {
        debugPrint('Error adding device circle: $e');
      }
    }

    // Add sent marker as a circle
    if (_sentPositions.isNotEmpty) {
      try {
        final lastSent = _sentPositions.last;
        await _mapController!.addCircle(CircleOptions(geometry: lastSent, circleColor: '#FF4444', circleRadius: 7, circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
      } catch (e) {
        debugPrint('Error adding sent circle: $e');
      }
    }
  }

  Future<void> _updateSentMarker(LatLng point) async {
    await _rebuildAllMarkers();
  }

  // --- Address search ---

  void _showSearchDialog() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchResults.clear();
        _searchController.clear();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=geojson&polygon_geojson=1&limit=8&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'Trabcdefg/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];
        if (mounted) {
          setState(() {
            _searchResults = features.cast<Map<String, dynamic>>();
            _isSearching = false;
          });
        }
      } else {
        if (mounted) setState(() => _isSearching = false);
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _zoomToSearchResult(Map<String, dynamic> feature) async {
    final coords = feature['geometry']?['coordinates'] as List?;
    if (coords == null || coords.length < 2) return;

    final lng = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    final point = LatLng(lat, lng);

    // Clear all and rebuild markers with search result
    if (_mapController != null && _isStyleLoaded) {
      try {
        await _mapController!.clearSymbols();
        await _mapController!.clearCircles();
      } catch (e) {
        debugPrint('Error clearing annotations: $e');
      }

      // Add device marker as a circle
      if (_deviceLatLng != null) {
        try {
          await _mapController!.addCircle(CircleOptions(geometry: _deviceLatLng, circleColor: '#0F53FE', circleRadius: 10, circleStrokeColor: '#FFFFFF', circleStrokeWidth: 3));
        } catch (_) {}
      }

      // Add sent marker as a circle
      if (_sentPositions.isNotEmpty) {
        try {
          final lastSent = _sentPositions.last;
          await _mapController!.addCircle(CircleOptions(geometry: lastSent, circleColor: '#FF4444', circleRadius: 7, circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
        } catch (_) {}
      }

      // Add search result marker as a circle
      await _mapController!.addCircle(CircleOptions(geometry: point, circleColor: '#00AA00', circleRadius: 8, circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
    }

    await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(point, 16.0), duration: const Duration(milliseconds: 800));

    setState(() {
      _showSearch = false;
      _searchResults.clear();
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final devices = _getDevices();
    final mapProvider = Provider.of<MapStyleProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Full screen map
          MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: const CameraPosition(target: LatLng(21.9162, 95.9560), zoom: 3.0),
            styleString: mapProvider.styleString,
            onMapClick: (point, latLng) {
              _sendPosition(latLng);
            },
            trackCameraPosition: true,
          ),

          // Top bar with back button and title
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  Expanded(
                    child: Text('sharedEmulator'.tr, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  // Search button
                  IconButton(icon: Icon(_showSearch ? Icons.search_off : Icons.search), onPressed: _showSearchDialog, tooltip: 'sharedSearch'.tr),
                  if (_lastSentStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _lastSentStatus!,
                        style: TextStyle(fontSize: 11, color: _lastSentStatus!.startsWith('✓') ? Colors.green : Theme.of(context).colorScheme.error),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Search overlay
          if (_showSearch)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search input field
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'searchOsm'.tr,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : IconButton(icon: const Icon(Icons.send), onPressed: () => _searchLocation(_searchController.text)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: _searchLocation,
                    ),
                  ),

                  // Search results
                  if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final feature = _searchResults[index];
                          final props = feature['properties'] as Map<String, dynamic>? ?? {};
                          final displayName = props['display_name'] as String? ?? '';
                          final type = props['type'] as String? ?? '';
                          return ListTile(
                            dense: true,
                            leading: Icon(_getPlaceIcon(type), size: 20),
                            title: Text(displayName.split(', ').take(3).join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            onTap: () => _zoomToSearchResult(feature),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          // Device selector panel at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Device selector
                  DropdownButtonFormField<int>(
                    value: _selectedDeviceId,
                    decoration: InputDecoration(
                      labelText: 'reportDevice'.tr,
                      prefixIcon: const Icon(Icons.devices),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: devices.map((device) {
                      return DropdownMenuItem<int>(
                        value: device.id,
                        child: Text('${device.name ?? 'N/A'} (${device.uniqueId ?? ''})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDeviceId = value;
                      });
                      _focusOnDevice(value);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Status row
                  Row(
                    children: [
                      // Sent count
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.pin_drop, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text('${_sentPositions.length} ${'reportPositions'.tr}', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),

                      // Clear button
                      if (_sentPositions.isNotEmpty)
                        TextButton.icon(
                          onPressed: _clearPositions,
                          icon: Icon(Icons.clear_all, size: 18, color: Theme.of(context).colorScheme.error),
                          label: Text('reportClear'.tr, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),

                      // Sending indicator
                      if (_isSending)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
                        ),
                    ],
                  ),

                  // Hint text
                  if (_selectedDeviceId == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tap on the map to send a position after selecting a device.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
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
