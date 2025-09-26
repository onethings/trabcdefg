// // lib/screens/map_screen.dart

// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:provider/provider.dart';
// import 'package:trabcdefg/providers/traccar_provider.dart';
// import 'package:trabcdefg/src/generated_api/api.dart';
// import 'package:trabcdefg/src/generated_api/model/device_extensions.dart';
// import 'dart:async';
// import 'package:flutter/services.dart';
// import 'dart:ui' as ui;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'monthly_mileage_screen.dart';
// import 'device_list_screen.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import 'device_details_screen.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'settings/geofences_screen.dart';
// import 'package:trabcdefg/constants.dart';
// import 'dart:io';
// import 'share_device_screen.dart'; // Import the new screen
// import 'command_screen.dart'; 
// import 'package:trabcdefg/screens/settings/devices_screen.dart';
// import 'package:trabcdefg/screens/settings/add_device_screen.dart';

// class MapScreen extends StatefulWidget {
//   final Device? selectedDevice;

//   const MapScreen({super.key, this.selectedDevice});

//   @override
//   State<MapScreen> createState() => _MapScreenState();
// }

// class _MapScreenState extends State<MapScreen> {
//   final Map<String, BitmapDescriptor> _markerIcons = {};
//   bool _markersLoaded = false;
//   bool _isSatelliteView = false;
//   GoogleMapController? mapController;
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   Device? _currentDevice;

//   @override
//   void initState() {
//     super.initState();
//     _loadMarkerIcons();
//     _currentDevice = widget.selectedDevice;
//     if (_currentDevice != null) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         // Your logic for initial state handling
//       });
//     }
//   }

//   Future<void> _loadMarkerIcons() async {
//     const List<String> categories = [
//       'animal',
//       'arrow',
//       'bicycle',
//       'boat',
//       'bus',
//       'car',
//       'crane',
//       'default',
//       'helicopter',
//       'motorcycle',
//       'null',
//       'offroad',
//       'person',
//       'pickup',
//       'plane',
//       'scooter',
//       'ship',
//       'tractor',
//       'train',
//       'tram',
//       'trolleybus',
//       'truck',
//       'van',
//     ];
//     const List<String> statuses = [
//       'online',
//       'offline',
//       'static',
//       'idle',
//       'unknown',
//     ];

//     for (var category in categories) {
//       for (var status in statuses) {
//         final iconPath = 'assets/images/marker_${category}_$status.png';
//         try {
//           final byteData = await rootBundle.load(iconPath);
//           final imageData = byteData.buffer.asUint8List();
//           final codec = await ui.instantiateImageCodec(
//             imageData,
//             targetHeight: 100,
//           );
//           final frameInfo = await codec.getNextFrame();
//           final image = frameInfo.image;
//           final byteDataResized = await image.toByteData(
//             format: ui.ImageByteFormat.png,
//           );
//           if (byteDataResized != null) {
//             final bitmap = BitmapDescriptor.fromBytes(
//               byteDataResized.buffer.asUint8List(),
//             );
//             _markerIcons['$category-$status'] = bitmap;
//           }
//         } catch (e) {
//           print('Could not load icon: $iconPath. Using fallback.'.tr);
//         }
//       }
//     }
//     if (mounted) {
//       setState(() {
//         _markersLoaded = true;
//       });
//     }
//   }

//   PersistentBottomSheetController? _bottomSheetController;
//   String _formatDate(DateTime? date) {
//     if (date == null) return 'N/A';
//     return DateFormat('MM/dd/yyyy, hh:mm:ss a').format(date.toLocal());
//   }

//   void _onDeviceSelected(Device device, List<Position> allPositions) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setInt('selectedDeviceId', device.id!);
//     await prefs.setString('selectedDeviceName', device.name!);

//     final position = allPositions.firstWhere(
//       (p) => p.deviceId == device.id,
//       orElse: () => Position(
//         deviceId: device.id,
//         latitude: 0.0,
//         longitude: 0.0,
//       ), // Fallback
//     );

//     if (position.latitude != null &&
//         position.longitude != null &&
//         mapController != null) {
//       mapController!.animateCamera(
//         CameraUpdate.newLatLngZoom(
//           LatLng(position.latitude!.toDouble(), position.longitude!.toDouble()),
//           15, // A closer zoom level
//         ),
//       );
//     }

//     // Show the detail panel for the selected device
//     _showDeviceDetailPanel(device);
//   }

//   Color _getBatteryColor(double batteryLevel) {
//     if (batteryLevel > 75) {
//       return Colors.green;
//     } else if (batteryLevel > 25) {
//       return Colors.orange;
//     } else {
//       return Colors.red;
//     }
//   }

//   Future<void> _launchUrl(Uri url) async {
//     if (!await launchUrl(url)) {
//       throw 'Could not launch $url';
//     }
//   }

//   void _showMoreOptionsDialog(Device device, Position position) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('More Options'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 ListTile(
//                   title: const Text('Create Geofence'),
//                   onTap: () {
//                     Navigator.of(context).pop();
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const AddGeofenceScreen(),
//                       ),
//                     );
//                   },
//                 ),
//                 ListTile(
//                   title: const Text('Google Maps'),
//                   onTap: () {
//                     Navigator.of(context).pop();
//                     if (position.latitude != null && position.longitude != null) {
//                       final url = Uri.parse(
//                           'https://maps.google.com/?q=${position.latitude},${position.longitude}');
//                       _launchUrl(url);
//                     }
//                   },
//                 ),
//                 ListTile(
//                   title: const Text('Apple Maps'),
//                   onTap: () {
//                     Navigator.of(context).pop();
//                     if (position.latitude != null && position.longitude != null) {
//                       final url = Uri.parse(
//                           'https://maps.apple.com/?q=${position.latitude},${position.longitude}');
//                       _launchUrl(url);
//                     }
//                   },
//                 ),
//                 ListTile(
//                   title: const Text('Street View'),
//                   onTap: () {
//                     Navigator.of(context).pop();
//                     if (position.latitude != null && position.longitude != null) {
//                       final url = Uri.parse(
//                           'google.streetview:cbll=${position.latitude},${position.longitude}');
//                       _launchUrl(url);
//                     }
//                   },
//                 ),
//                 ListTile(
//                   title: const Text('Share Device'),
//                   onTap: () async {
//                     Navigator.of(context).pop();
//                     final prefs = await SharedPreferences.getInstance();
//                     await prefs.setInt('sharedDeviceId', device.id!);
//                     await prefs.setString('sharedDeviceName', device.name!);
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (context) => const ShareDeviceScreen()),
//                     );
//                   },
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _showDeviceDetailPanel(Device device) {
//     _bottomSheetController?.close();

//     _bottomSheetController = _scaffoldKey.currentState!.showBottomSheet(
//       (context) {
//         // Find the current position for the device
//         final currentPosition = Provider.of<TraccarProvider>(
//           context,
//           listen: false,
//         ).positions.firstWhere(
//           (p) => p.deviceId == device.id,
//           orElse: () => Position(),
//         );

//         return Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Container(
//             width: double.infinity,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(24.0),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.05),
//                   blurRadius: 20,
//                   spreadRadius: 5,
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Top handle
//                 Center(
//                   child: Container(
//                     margin: const EdgeInsets.only(top: 8, bottom: 16),
//                     height: 4,
//                     width: 40,
//                     decoration: BoxDecoration(
//                       color: Colors.grey[300],
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                 ),
//                 // Device Name and Status
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.start,
//                         children: [
//                           Text(
//                             device.name ?? 'Unknown Device'.tr,
//                             style: const TextStyle(
//                               fontSize: 17,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.info, color: Color(0xFF5B697B)),
//                             onPressed: () async {
//                               // Handle info button tap
//                               final prefs = await SharedPreferences.getInstance();
//                               await prefs.setInt('selectedDeviceId', device.id!);
//                               await prefs.setString(
//                                   'selectedDeviceName', device.name!);
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (context) =>
//                                       const DeviceDetailsScreen(),
//                                 ),
//                               );
//                               print('Info button tapped!');
//                             },
//                           ),
//                           if ((currentPosition.attributes
//                                       as Map<String, dynamic>?)?['distance'] !=
//                                   null &&
//                               ((currentPosition.attributes
//                                           as Map<String, dynamic>)['distance']
//                                       as double) >
//                                   0.0)
//                             Text(
//                               '${((currentPosition.attributes as Map<String, dynamic>)['distance'] as double).toStringAsFixed(2)} km',
//                               style: const TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                         ],
//                       ),
//                       Row(
//                         children: [
//                           //Speed
//                           if (currentPosition.speed != null &&
//                               currentPosition.speed != 0.0)
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 4.0,
//                               ),
//                               child: Text(
//                                 '${currentPosition.speed} km/h',
//                                 style: const TextStyle(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.black,
//                                 ),
//                               ),
//                             ),
//                           // Ignition Icon
//                           if ((currentPosition.attributes
//                                   as Map<String, dynamic>?)?['ignition'] !=
//                               null)
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 4.0,
//                               ),
//                               child: Icon(
//                                 Icons.key,
//                                 color: (currentPosition.attributes
//                                             as Map<String, dynamic>?)?['ignition'] ==
//                                         true
//                                     ? Colors.green
//                                     : Colors.red,
//                               ),
//                             ),
//                           // Battery Icon with Percentage
//                           if ((currentPosition.attributes
//                                   as Map<String, dynamic>?)?['batteryLevel'] !=
//                               null)
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 4.0,
//                               ),
//                               child: Stack(
//                                 alignment: Alignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.battery_full,
//                                     color: _getBatteryColor(
//                                       ((currentPosition.attributes
//                                                   as Map<String, dynamic>)['batteryLevel']
//                                               as int)
//                                           .toDouble(), // Cast to double
//                                     ),
//                                   ),
//                                   Text(
//                                     '${(currentPosition.attributes as Map<String, dynamic>)['batteryLevel']}',
//                                     style: const TextStyle(
//                                       fontSize: 10,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   child: Column(
//                     children: [
//                       _buildDetailsPanel(
//                         fixTime: _formatDate(currentPosition.fixTime),
//                         address: (currentPosition.attributes
//                                 as Map<String, dynamic>?)?['address'] ??
//                             'N/A',
//                         totalDistance:
//                             '${(currentPosition.attributes as Map<String, dynamic>?)?['totalDistance']?.toStringAsFixed(2) ?? 'N/A'} km',
//                       ),
//                       // const SizedBox(height: 16),
//                       _buildReportPanel(
//                         onRefreshPressed: () {
//                           _bottomSheetController?.close();
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => MonthlyMileageScreen(),
//                             ),
//                           );
//                         },
//                         onMoreOptionsPressed: () =>
//                             _showMoreOptionsDialog(device, currentPosition),
//                             onUploadPressed: () async { 
//                           // The device ID is already in SharedPreferences
//                           Navigator.push( 
//                             context, 
//                             MaterialPageRoute( 
//                               builder: (context) => const CommandScreen(), 
//                             ), 
//                           ); 
//                         }, 
//                         onEditPressed: () async { // <--- ADDED EDIT LOGIC
//                           _bottomSheetController?.close();
//                            final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
//                           // Navigate to AddDeviceScreen, passing the current device for editing
//                           final updatedDevice = await Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               // Assuming AddDeviceScreen is used for both add and edit
//                               builder: (context) => AddDeviceScreen(device: device), 
//                             ),
//                           );
//  // Logic to handle updated device (e.g., refresh devices list)
//                           if (updatedDevice != null) {
//                             // You might need a way to refresh the device data on the map/UI
//                             await traccarProvider.fetchInitialData();
//                           }
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//       backgroundColor: Colors.transparent,
//       elevation: 0,
//     );
//   }

//   LatLng? _getInitialCameraPosition(List<Position> positions) {
//     if (_currentDevice != null) {
//       final position = positions.firstWhere(
//         (p) => p.deviceId == _currentDevice!.id,
//         orElse: () => Position(latitude: 0, longitude: 0),
//       );
//       return LatLng(
//         position.latitude?.toDouble() ?? 0,
//         position.longitude?.toDouble() ?? 0,
//       );
//     }
//     return positions.isNotEmpty
//         ? LatLng(
//             positions.first.latitude!.toDouble(),
//             positions.first.longitude!.toDouble(),
//           )
//         : null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       appBar: AppBar(
//         title: Text('mapTitle'.tr),
//         actions: [
//           IconButton(
//             icon: Icon(_isSatelliteView ? Icons.satellite : Icons.map),
//             onPressed: () {
//               setState(() {
//                 _isSatelliteView = !_isSatelliteView;
//               });
//             },
//           ),
//         ],
//       ),
//       drawer: Drawer(
//         child: Consumer<TraccarProvider>(
//           builder: (context, provider, child) {
//             return ListView.builder(
//               itemCount: provider.devices.length,
//               itemBuilder: (context, index) {
//                 final device = provider.devices[index];
//                 return ListTile(
//                   title: Text(device.name ?? 'Unknown Device'.tr),
//                   onTap: () {
//                     _onDeviceSelected(device, provider.positions);
//                     _scaffoldKey.currentState?.closeDrawer();
//                   },
//                 );
//               },
//             );
//           },
//         ),
//       ),
//       body: Consumer<TraccarProvider>(
//         builder: (context, provider, child) {
//           if (!_markersLoaded || provider.devices.isEmpty) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           final Set<Marker> markers = {};
//           for (var position in provider.positions) {
//             if (position.latitude != null && position.longitude != null) {
//               final device = provider.devices.firstWhere(
//                 (d) => d.id == position.deviceId,
//                 orElse: () => Device(
//                   id: 0,
//                   name: 'Unknown'.tr,
//                   status: 'offline',
//                   category: 'default',
//                 ),
//               );

//               final course = position.course?.toDouble() ?? 0.0;
//               markers.add(
//                 Marker(
//                   markerId: MarkerId(position.deviceId.toString()),
//                   position: LatLng(
//                     position.latitude!.toDouble(),
//                     position.longitude!.toDouble(),
//                   ),
//                   icon: _getMarkerIcon(device, position),
//                   rotation: course,
//                   infoWindow: InfoWindow(title: device.name ?? 'Unknown'.tr),
//                   onTap: () => _onDeviceSelected(device, provider.positions),
//                 ),
//               );
//             }
//           }

//           final initialLocation = _getInitialCameraPosition(provider.positions);

//           return Stack(
//             children: [
//               GoogleMap(
//                 mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
//                 initialCameraPosition: CameraPosition(
//                   target: initialLocation ?? const LatLng(0, 0),
//                   zoom: 10,
//                 ),
//                 onMapCreated: (controller) {
//                   mapController = controller;
//                   if (_currentDevice != null) {
//                     _onDeviceSelected(_currentDevice!, provider.positions);
//                   }
//                 },
//                 markers: markers,
//               ),
//               if (_currentDevice != null)
//                 Positioned(
//                   bottom: 0,
//                   left: 0,
//                   right: 0,
//                   child: Container(
//                     padding: const EdgeInsets.all(16.0),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: const BorderRadius.only(
//                         topLeft: Radius.circular(16.0),
//                         topRight: Radius.circular(16.0),
//                       ),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.1),
//                           blurRadius: 10,
//                           spreadRadius: 5,
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               _currentDevice!.name ?? 'Unknown Device'.tr,
//                               style: const TextStyle(
//                                 fontSize: 20,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             IconButton(
//                               icon: const Icon(Icons.close),
//                               onPressed: () {
//                                 setState(() {
//                                   _currentDevice = null;
//                                 });
//                               },
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         Text('Status: ${(_currentDevice!.status ?? 'N/A').tr}'),
//                       ],
//                     ),
//                   ),
//                 ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   // Helper method for marker icon
//   BitmapDescriptor _getMarkerIcon(Device device, Position position) {
//     final status = device.status ?? 'unknown';
//     final category = device.category ?? 'default';
//     final key = '$category-$status';
//     if (_markerIcons.containsKey(key)) {
//       return _markerIcons[key]!;
//     }
//     // Fallback to the default icon if a specific one is not found
//     return _markerIcons['default-unknown']!;
//   }
// }

// // Widget to build the statistical info cards
// Widget _buildInfoCard({
//   required IconData icon,
//   required String value,
//   required String label,
//   required Color color,
// }) {
//   return Expanded(
//     child: Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF0F3F9),
//         borderRadius: BorderRadius.circular(16.0),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, color: color),
//               const SizedBox(width: 8),
//               Text(
//                 value,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 4),
//           Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
//         ],
//       ),
//     ),
//   );
// }

// // Widget to build the main details panel with time and distance
// Widget _buildDetailsPanel({
//   required String fixTime,
//   required String address,
//   required String totalDistance,
// }) {
//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       // Fix Time Row
//       Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           const Text(
//             'Fix Time',
//             style: TextStyle(color: Color(0xFF5B697B), fontSize: 14),
//           ),
//           Text(
//             fixTime,
//             style: const TextStyle(
//               color: Colors.black,
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//       // Address Row
//       if (address != 'N/A')
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             const Text(
//               'Address',
//               style: TextStyle(color: Color(0xFF5B697B), fontSize: 14),
//             ),
//             Expanded(
//               child: Text(
//                 address,
//                 textAlign: TextAlign.right,
//                 style: const TextStyle(
//                   color: Colors.black,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//       // Total Distance Row
//       Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           const Text(
//             'Total Distance',
//             style: TextStyle(color: Color(0xFF5B697B), fontSize: 14),
//           ),
//           Row(
//             children: [
//               Text(
//                 totalDistance,
//                 style: const TextStyle(
//                   color: Colors.black,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               const Icon(Icons.settings, color: Color(0xFF5B697B), size: 16),
//             ],
//           ),
//         ],
//       ),
//     ],
//   );
// }

// // Widget to build the report and history panel
// Widget _buildReportPanel({
//   required VoidCallback onRefreshPressed,
//   required VoidCallback onMoreOptionsPressed,
//   required VoidCallback onUploadPressed,
//   required VoidCallback onEditPressed,
// }) {
//   return Row(
//     mainAxisAlignment: MainAxisAlignment.spaceAround,
//     children: [
//       // More options icon
//       IconButton(
//         icon: const Icon(Icons.more_horiz, color: Color(0xFF5B697B)),
//         onPressed: onMoreOptionsPressed,
//       ),
//       // Refresh icon
//       IconButton(
//         icon: const Icon(Icons.refresh, color: Color(0xFF5B697B)),
//         onPressed: onRefreshPressed,
//       ),
//       // Upload icon
//       IconButton(
//         icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF246BFD)),
//         onPressed: onUploadPressed,
//       ),
//       // Edit icon
//       IconButton(
//         icon: const Icon(Icons.edit, color: Color(0xFF5B697B)),
//         onPressed: onEditPressed,
//       ),
//       // Delete icon
//       IconButton(
//         icon: const Icon(Icons.delete_outline, color: Colors.red),
//         onPressed: () {
//           // Handle delete tap
//           print('Delete tapped!');
//         },
//       ),
//     ],
//   );
// }