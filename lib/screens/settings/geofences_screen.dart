// geofences_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:collection';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:get/get.dart';

class GeofencesScreen extends StatefulWidget {
  const GeofencesScreen({super.key});

  @override
  _GeofencesScreenState createState() => _GeofencesScreenState();
}

class _GeofencesScreenState extends State<GeofencesScreen> {
  late Future<List<api.Geofence>> _geofencesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _geofencesFuture = _fetchGeofences();
  }

  Future<List<api.Geofence>> _fetchGeofences() async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
    final geofences = await geofencesApi.geofencesGet();
    return geofences ?? [];
  }

  void _deleteGeofence(int geofenceId) async {
    try {
      final traccarProvider = Provider.of<TraccarProvider>(
        context,
        listen: false,
      );
      final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
      await geofencesApi.geofencesIdDelete(geofenceId);
      setState(() {
        _geofencesFuture = _fetchGeofences();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('sharedRemoveConfirm'.tr)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete geofence: $e')));
    }
  }

  void _editGeofence(api.Geofence geofence) async {
    final updatedGeofence = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddGeofenceScreen(geofence: geofence),
      ),
    );

    if (updatedGeofence != null) {
      try {
        final traccarProvider = Provider.of<TraccarProvider>(
          context,
          listen: false,
        );
        final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
        await geofencesApi.geofencesIdPut(updatedGeofence.id!, updatedGeofence);
        setState(() {
          _geofencesFuture = _fetchGeofences();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('sharedSaved'.tr)));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update geofence: $e')),
        );
      }
    }
  }

  String _getGeofenceDetails(api.Geofence geofence) {
    final area = geofence.area;
    if (area == null || area.isEmpty) return 'sharedNoData'.tr;
    if (area.startsWith('CIRCLE')) {
      try {
        final parts = area
            .substring(area.indexOf('(') + 1, area.indexOf(')'))
            .split(' ');
        final radius = double.tryParse(parts[2]) ?? 0.0;
        return 'Circle: ${radius.round()}m';
      } catch (e) {
        return 'Circle: Invalid format';
      }
    } else if (area.startsWith('POLYGON')) {
      try {
        final content = area.substring(
          area.indexOf('((') + 2,
          area.lastIndexOf('))'),
        );
        final points = content.split(',');
        return 'Polygon: ${points.length} points';
      } catch (e) {
        return 'Polygon: Invalid format';
      }
    }
    return 'sharedType'.tr + ' ' + 'Unknown Type';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sharedGeofences'.tr)),
      body: FutureBuilder<List<api.Geofence>>(
        future: _geofencesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('errorGeneral'.tr + ': ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('sharedNoData'.tr));
          } else {
            final geofences = snapshot.data!;
            return ListView.builder(
              itemCount: geofences.length,
              itemBuilder: (context, index) {
                final geofence = geofences[index];
                final details = _getGeofenceDetails(geofence);
                return ListTile(
                  title: Text(geofence.name ?? 'sharedNoData'.tr),
                  subtitle: Text(details),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editGeofence(geofence),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteGeofence(geofence.id!),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newGeofence = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddGeofenceScreen()),
          );

          if (newGeofence != null) {
            try {
              final traccarProvider = Provider.of<TraccarProvider>(
                context,
                listen: false,
              );
              final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
              await geofencesApi.geofencesPost(newGeofence);
              setState(() {
                _geofencesFuture = _fetchGeofences();
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('sharedSaved'.tr)));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to add geofence: $e')),
              );
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddGeofenceScreen extends StatefulWidget {
  final api.Geofence? geofence;

  const AddGeofenceScreen({super.key, this.geofence});

  @override
  _AddGeofenceScreenState createState() => _AddGeofenceScreenState();
}

class _AddGeofenceScreenState extends State<AddGeofenceScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _radius;
  late String _geofenceType;
  LatLng? _circleCenter;
  List<LatLng> _polygonPoints = [];

  final Set<Circle> _circles = HashSet<Circle>();
  final Set<Polygon> _polygons = HashSet<Polygon>();
  final Set<Marker> _polygonMarkers = HashSet<Marker>();

  late GoogleMapController _mapController;
  static const LatLng _center = LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    if (widget.geofence != null) {
      _name = widget.geofence!.name!;
      final area = widget.geofence!.area;
      if (area != null) {
        if (area.startsWith('CIRCLE')) {
          _geofenceType = 'CIRCLE';
          try {
            final parts = area
                .substring(area.indexOf('(') + 1, area.indexOf(')'))
                .split(' ');
            _circleCenter = LatLng(
              double.tryParse(parts[0]) ?? 0.0,
              double.tryParse(parts[1]) ?? 0.0,
            );
            final parsedRadius = double.tryParse(parts[2]);
            if (parsedRadius != null &&
                parsedRadius >= 10 &&
                parsedRadius <= 2000) {
              _radius = parsedRadius;
            } else {
              _radius = 10.0;
            }
          } catch (e) {
            _circleCenter = null;
            _radius = 10.0;
          }
        } else if (area.startsWith('POLYGON')) {
          _geofenceType = 'POLYGON';
          _radius = 0.0;
          try {
            final content = area.substring(
              area.indexOf('((') + 2,
              area.lastIndexOf('))'),
            );
            final points = content.split(',').map((p) {
              final coords = p.trim().split(' ');
              return LatLng(
                double.tryParse(coords[0]) ?? 0.0,
                double.tryParse(coords[1]) ?? 0.0,
              );
            }).toList();
            _polygonPoints = points;
          } catch (e) {
            _polygonPoints = [];
          }
        }
      } else {
        _geofenceType = 'CIRCLE';
        _radius = 10.0;
      }
    } else {
      _geofenceType = 'CIRCLE';
      _name = '';
      _radius = 10;
    }
    _updateShapes();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_geofenceType == 'CIRCLE' && _circleCenter != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_circleCenter!, 14.0),
      );
    } else if (_geofenceType == 'POLYGON' && _polygonPoints.isNotEmpty) {
      double minLat = _polygonPoints[0].latitude;
      double maxLat = _polygonPoints[0].latitude;
      double minLng = _polygonPoints[0].longitude;
      double maxLng = _polygonPoints[0].longitude;
      double totalLat = 0;
      double totalLng = 0;
      for (final point in _polygonPoints) {
        totalLat += point.latitude;
        totalLng += point.longitude;
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }
      final centerLat = totalLat / _polygonPoints.length;
      final centerLng = totalLng / _polygonPoints.length;

      _mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          50, // padding
        ),
      );
    }
  }

  void _onTap(LatLng point) {
    setState(() {
      if (_geofenceType == 'CIRCLE') {
        _circleCenter = point;
      } else {
        _polygonPoints.add(point);
      }
      _updateShapes();
    });
  }

  void _updateShapes() {
    _circles.clear();
    _polygons.clear();
    _polygonMarkers.clear();

    if (_geofenceType == 'CIRCLE' && _circleCenter != null) {
      _circles.add(
        Circle(
          circleId: const CircleId('geofence_circle'),
          center: _circleCenter!,
          radius: _radius,
          fillColor: Colors.blue.withOpacity(0.3),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    } else if (_geofenceType == 'POLYGON' && _polygonPoints.isNotEmpty) {
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('geofence_polygon'),
          points: _polygonPoints,
          fillColor: Colors.green.withOpacity(0.3),
          strokeColor: Colors.green,
          strokeWidth: 2,
        ),
      );
      for (int i = 0; i < _polygonPoints.length; i++) {
        _polygonMarkers.add(
          Marker(
            markerId: MarkerId('polygon_point_$i'),
            position: _polygonPoints[i],
            infoWindow: InfoWindow(title: 'Point ${i + 1}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.geofence == null
              ? 'sharedCreateGeofence'.tr
              : 'sharedEdit'.tr + ' ' + 'sharedGeofence'.tr,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              if (_formKey.currentState!.validate() &&
                  ((_geofenceType == 'CIRCLE' && _circleCenter != null) ||
                      (_geofenceType == 'POLYGON' &&
                          _polygonPoints.length >= 3))) {
                _formKey.currentState!.save();
                final String area;
                if (_geofenceType == 'CIRCLE') {
                  area =
                      'CIRCLE(${_circleCenter!.latitude} ${_circleCenter!.longitude} $_radius)';
                } else {
                  final pointsString = _polygonPoints
                      .map((p) => '${p.latitude} ${p.longitude}')
                      .join(', ');
                  area = 'POLYGON((${pointsString}))';
                }

                final geofence = api.Geofence(
                  id: widget.geofence?.id,
                  name: _name,
                  area: area,
                );
                Navigator.pop(context, geofence);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _geofenceType == 'CIRCLE'
                          ? 'Please enter a name and select a point on the map.'
                                .tr
                          : 'Please enter a name and draw a polygon with at least 3 points.'
                                .tr,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: InputDecoration(labelText: 'sharedName'.tr),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _name = value!;
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _geofenceType,
                  decoration: InputDecoration(labelText: 'sharedType'.tr),
                  items: [
                    DropdownMenuItem(
                      value: 'CIRCLE',
                      child: Text('mapShapeCircle'.tr),
                    ),
                    DropdownMenuItem(
                      value: 'POLYGON',
                      child: Text('mapShapePolygon'.tr),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _geofenceType = value!;
                      _updateShapes();
                    });
                  },
                ),
                const SizedBox(height: 20),
                if (_geofenceType == 'CIRCLE')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${'commandRadius'.tr}: ${_radius.round()} ${'sharedMeters'.tr}',
                      ),
                      Slider(
                        value: _radius,
                        min: 10,
                        max: 2000,
                        divisions: 199,
                        label: _radius.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            _radius = value;
                            _updateShapes();
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('mapShapeCircle'.tr),
                    ],
                  ),
                if (_geofenceType == 'POLYGON')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('mapShapePolygon'.tr + ': ${_polygonPoints.length}'),
                      const SizedBox(height: 10),
                      Text('TapMapAddPolygon'.tr),
                    ],
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 400, // Increased map height
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target:
                          _circleCenter ??
                          (_polygonPoints.isNotEmpty
                              ? _polygonPoints.first
                              : _center),
                      zoom: 14.0,
                    ),
                    onTap: _onTap,
                    circles: _circles,
                    polygons: _polygons,
                    markers: _polygonMarkers,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
