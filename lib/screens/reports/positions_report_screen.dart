// lib/screens/reports/positions_report_screen.dart
// Positions report with map view, route path, position selection and
// traccar-web style column selection (columns are discovered from the response).
// Based on traccar-web PositionsReportPage (uses /api/positions + map).
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class PosItem {
  final int id;
  final int deviceId;
  final DateTime fixTime;
  final DateTime deviceTime;
  final DateTime serverTime;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double course;
  final double accuracy;
  final String? address;
  final String? protocol;
  final bool valid;
  final Map<String, dynamic> attributes;

  /// Original JSON so the report can expose fields this model does not type
  /// (new server fields, or attributes such as `iccid` and `odometer`).
  final Map<String, dynamic> raw;

  PosItem({
    required this.id,
    required this.deviceId,
    required this.fixTime,
    required this.deviceTime,
    required this.serverTime,
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
    this.speed = 0,
    this.course = 0,
    this.accuracy = 0,
    this.address,
    this.protocol,
    this.valid = false,
    this.attributes = const {},
    this.raw = const {},
  });

  factory PosItem.fromJson(Map<String, dynamic> json) {
    return PosItem(
      id: json['id'] as int,
      deviceId: json['deviceId'] as int,
      fixTime: DateTime.parse(json['fixTime'] as String),
      deviceTime: DateTime.parse(json['deviceTime'] as String),
      serverTime: DateTime.parse(json['serverTime'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      course: (json['course'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String?,
      protocol: json['protocol'] as String?,
      valid: json['valid'] as bool? ?? false,
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
      raw: json,
    );
  }
}

class PositionsReportScreen extends StatefulWidget {
  const PositionsReportScreen({super.key});

  @override
  State<PositionsReportScreen> createState() => _PositionsReportScreenState();
}

class _PositionsReportScreenState extends State<PositionsReportScreen> {
  List<PosItem> _items = [];
  bool _isLoading = true;
  String? _deviceName;
  PosItem? _selectedItem;

  maplibre.MapLibreMapController? _mapController;
  bool _mapReady = false;
  bool _showMap = true;

  // Like traccar-web's ColumnSelect, columns are discovered from the response
  // instead of being hardcoded, so attributes (iccid, odometer, alarm, ...)
  // and any field a newer server adds become selectable automatically.
  static const _ignoredColumns = {
    'id',
    'deviceId',
    'attributes',
    'network',
    'outdated',
  };
  static const _standardColumnOrder = [
    'fixTime',
    'deviceTime',
    'serverTime',
    'valid',
    'latitude',
    'longitude',
    'altitude',
    'speed',
    'course',
    'accuracy',
    'address',
    'protocol',
  ];
  static const _standardColumnLabels = {
    'fixTime': 'positionFixTime',
    'deviceTime': 'positionDeviceTime',
    'serverTime': 'positionServerTime',
    'valid': 'positionValid',
    'latitude': 'positionLatitude',
    'longitude': 'positionLongitude',
    'altitude': 'positionAltitude',
    'speed': 'positionSpeed',
    'course': 'positionCourse',
    'accuracy': 'positionAccuracy',
    'address': 'positionAddress',
    'protocol': 'positionProtocol',
  };
  static const _defaultColumns = {
    'fixTime',
    'latitude',
    'longitude',
    'speed',
    'course',
  };
  static const _dateColumns = {'fixTime', 'deviceTime', 'serverTime'};
  static const _meterColumns = {
    'distance',
    'totalDistance',
    'odometer',
    'serviceOdometer',
    'tripOdometer',
  };

  List<String> _availableColumns = const [];
  final Set<String> _selectedColumns = {..._defaultColumns};

  @override
  void initState() {
    super.initState();
    _fetchPositions();
  }

  Future<void> _fetchPositions() async {
    setState(() => _isLoading = true);
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');
    if (deviceId == null || fromDateString == null || toDateString == null) {
      setState(() => _isLoading = false);
      return;
    }
    final fromDate = DateTime.tryParse(fromDateString);
    final toDate = DateTime.tryParse(toDateString);
    if (fromDate == null || toDate == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final queryParams = [
        api.QueryParam('from', fromDate.toIso8601String()),
        api.QueryParam('to', toDate.toIso8601String()),
        api.QueryParam('deviceId', deviceId.toString()),
      ];
      final response = await traccarProvider.apiClient.invokeAPI(
        '/positions',
        'GET',
        queryParams,
        null,
        {'Accept': 'application/json'},
        {},
        'application/json',
      );
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = (json.decode(response.body) as List? ?? [])
            .cast<Map<String, dynamic>>();
        _items = data.map(PosItem.fromJson).toList();
        _availableColumns = _collectColumns(data);
        final device = traccarProvider.devices.firstWhere(
          (d) => d.id == deviceId,
          orElse: () => api.Device(),
        );
        _deviceName = device.name;
      }
    } catch (e) {
      debugPrint('Positions error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load positions.'.tr)));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> _collectColumns(List<Map<String, dynamic>> data) {
    final keys = <String>{};
    for (final position in data) {
      position.forEach((key, _) {
        if (!_ignoredColumns.contains(key)) keys.add(key);
      });
      final attributes = position['attributes'];
      if (attributes is Map) {
        attributes.forEach((key, _) => keys.add(key.toString()));
      }
    }
    final ordered = <String>[
      ..._standardColumnOrder.where(keys.contains),
      ...keys.where((key) => !_standardColumnOrder.contains(key)),
    ];
    // The device or protocol can change between loads; never keep a stale
    // selection (or an empty one) around.
    _selectedColumns.removeWhere((key) => !ordered.contains(key));
    if (_selectedColumns.isEmpty) {
      _selectedColumns.addAll(_defaultColumns.where(ordered.contains));
    }
    return ordered;
  }

  String _labelFor(String key) {
    final l10nKey =
        _standardColumnLabels[key] ??
        'position${key[0].toUpperCase()}${key.substring(1)}';
    final translated = l10nKey.tr;
    return translated == l10nKey ? key : translated;
  }

  dynamic _valueOf(PosItem item, String key) =>
      item.raw[key] ?? item.attributes[key];

  String _formatValue(PosItem item, String key) {
    final value = _valueOf(item, key);
    if (value == null) return '-';
    if (_dateColumns.contains(key)) {
      final date = DateTime.tryParse(value.toString());
      return date == null
          ? value.toString()
          : DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toLocal());
    }
    if (value is bool) return value ? 'sharedYes'.tr : 'sharedNo'.tr;
    if (value is num) {
      if (key == 'speed') {
        return '${(value * 1.852).toStringAsFixed(1)} ${'sharedKmh'.tr}';
      }
      if (key == 'course') return '${value.toStringAsFixed(0)}°';
      if (key == 'latitude' || key == 'longitude') {
        return value.toStringAsFixed(5);
      }
      if (_meterColumns.contains(key)) {
        return '${(value / 1000).toStringAsFixed(2)} ${'sharedKm'.tr}';
      }
      return value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
    }
    if (value is List) return value.join(', ');
    return value.toString();
  }

  void _toggleColumn(String key) {
    setState(() {
      if (!_selectedColumns.remove(key)) _selectedColumns.add(key);
    });
  }

  Widget _buildItem(PosItem item) {
    final selected = _selectedItem?.id == item.id;
    final columns = _availableColumns.where(_selectedColumns.contains).toList();
    return Card(
      elevation: selected ? 6 : 1,
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          setState(() => _selectedItem = item);
          _updateMap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Icon(
                  item.valid
                      ? CupertinoIcons.location_solid
                      : CupertinoIcons.location,
                  color: item.valid ? Colors.green : Colors.red,
                  size: 18,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (columns.isEmpty ? ['fixTime'] : columns).map((
                    key,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${_labelFor(key)}: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text: _formatValue(item, key),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMapCreated(maplibre.MapLibreMapController c) {
    _mapController = c;
    _mapReady = true;
  }

  Future<void> _updateMap() async {
    if (!_mapReady || _mapController == null || _items.isEmpty) return;
    try {
      await _mapController!.clearLines();
      await _mapController!.clearCircles();

      // Route line
      final coords = _items
          .map((p) => maplibre.LatLng(p.latitude, p.longitude))
          .toList();
      if (coords.length >= 2) {
        await _mapController!.addLine(
          maplibre.LineOptions(
            geometry: coords,
            lineColor: "#1E88E5",
            lineWidth: 3.0,
          ),
        );
      }
      // Selected position marker
      if (_selectedItem != null) {
        await _mapController!.addCircle(
          maplibre.CircleOptions(
            geometry: maplibre.LatLng(
              _selectedItem!.latitude,
              _selectedItem!.longitude,
            ),
            circleColor: "#E53935",
            circleRadius: 8,
          ),
        );
        await _mapController!.animateCamera(
          maplibre.CameraUpdate.newCameraPosition(
            maplibre.CameraPosition(
              target: maplibre.LatLng(
                _selectedItem!.latitude,
                _selectedItem!.longitude,
              ),
              zoom: 15,
            ),
          ),
        );
      } else {
        // Fit all points
        final lats = _items.map((p) => p.latitude);
        final lngs = _items.map((p) => p.longitude);
        _mapController?.animateCamera(
          maplibre.CameraUpdate.newLatLngBounds(
            maplibre.LatLngBounds(
              southwest: maplibre.LatLng(
                lats.reduce((a, b) => a < b ? a : b),
                lngs.reduce((a, b) => a < b ? a : b),
              ),
              northeast: maplibre.LatLng(
                lats.reduce((a, b) => a > b ? a : b),
                lngs.reduce((a, b) => a > b ? a : b),
              ),
            ),
            left: 40,
            right: 40,
            top: 40,
            bottom: 40,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mapStyle = Provider.of<MapStyleProvider>(context)
        .getStyle(Theme.of(context).brightness);
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: Text('${'reportPositions'.tr}: ${_deviceName ?? ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_availableColumns.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.view_column),
                tooltip: 'sharedColumns'.tr,
                onSelected: _toggleColumn,
                itemBuilder: (_) => _availableColumns.map((key) {
                  return PopupMenuItem<String>(
                    value: key,
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selectedColumns.contains(key),
                          onChanged: null,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text(_labelFor(key))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            IconButton(
              icon: Icon(
                _showMap ? CupertinoIcons.list_bullet : CupertinoIcons.map,
              ),
              tooltip: _showMap ? 'Show List' : 'Show Map',
              onPressed: () => setState(() => _showMap = !_showMap),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(child: Text('sharedNoData'.tr))
          : Column(
              children: [
                if (_showMap)
                  SizedBox(
                    height: 250,
                    child: maplibre.MapLibreMap(
                      onMapCreated: _onMapCreated,
                      onStyleLoadedCallback: _updateMap,
                      styleString: mapStyle,
                      initialCameraPosition: maplibre.CameraPosition(
                        target: maplibre.LatLng(
                          _items.first.latitude,
                          _items.first.longitude,
                        ),
                        zoom: 12,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _buildItem(_items[i]),
                  ),
                ),
              ],
            ),
    );
  }
}
