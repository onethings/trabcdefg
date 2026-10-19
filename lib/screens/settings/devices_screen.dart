// devices_screen.dart
// A screen to display and manage devices in the TracDefg app.
import 'dart:convert';
import 'dart:developer' as developer; // For production-safe logging
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib; // FIX: camelCase to lower_case_with_underscores
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/settings/add_device_screen.dart';
import 'package:trabcdefg/screens/settings/connections_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState(); // FIX: Removed private type exposure
}

class _DevicesScreenState extends State<DevicesScreen> {
  late Future<List<api.Device>?> _devicesFuture;
  final TextEditingController _searchController = TextEditingController();
  List<api.Device> _allDevices = [];
  List<api.Device> _filteredDevices = [];
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  void _fetchDevices() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final devicesApi = api.DevicesApi(traccarProvider.apiClient);
    setState(() {
      _devicesFuture = devicesApi.getDevices().then((devices) {
        _allDevices = devices ?? [];
        _filteredDevices = _allDevices;
        return _filteredDevices;
      });
    });
  }

  void _filterDevices(String query) {
    setState(() {
      _filteredDevices = _allDevices.where((device) => device.name!.toLowerCase().contains(query.toLowerCase()) || device.uniqueId!.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _deleteDevice(int deviceId) async {
    try {
      final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
      final apiClient = traccarProvider.apiClient;

      final path = '/devices/$deviceId';
      final response = await apiClient.invokeAPI(path, 'DELETE', [], {}, <String, String>{}, <String, String>{}, 'application/json');

      // FIX: Guard BuildContext usage across an async gap using mounted check
      if (!mounted) return;

      if (response.statusCode == 204) {
        _fetchDevices();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('deviceDeleteSuccess'.tr)));
      } else {
        // FIX: Replaced print() with production-safe developer.log()
        developer.log('Server responded with status code: ${response.statusCode}', name: 'DevicesScreen');
        developer.log('Server response body: ${response.body}', name: 'DevicesScreen');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('deviceDeleteFailed'.trParams({'error': 'Server responded with status code: ${response.statusCode}'}))));
      }
    } catch (e) {
      // FIX: Replaced print() with developer.log()
      developer.log('Caught an exception: $e', name: 'DevicesScreen', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('deviceDeleteFailed'.trParams({'error': e.toString()}))));
    }
  }

  void _editDevice(api.Device device) async {
    final updatedDevice = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddDeviceScreen(device: device)));

    // FIX: Guard BuildContext usage across async gap
    if (!mounted) return;

    if (updatedDevice != null) {
      try {
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
        final devicesApi = api.DevicesApi(traccarProvider.apiClient);
        await devicesApi.putDevicesId(updatedDevice.id!, updatedDevice);

        if (!mounted) return;
        _fetchDevices();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('deviceUpdateSuccess'.tr)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('deviceUpdateFailed'.trParams({'error': e.toString()}))));
      }
    }
  }

  // --- Export Functions ---

  void _exportDevicesToCsv() async {
    if (_allDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('sharedNoData'.tr)));
      return;
    }

    List<List<dynamic>> rows = [];
    rows.add(['ID', 'sharedName'.tr, 'deviceIdentifier'.tr]);

    for (var device in _allDevices) {
      rows.add([device.id, device.name, device.uniqueId]);
    }

    // csv 6.0.0: use ListToCsvConverter (Csv() only exists in csv >= 7.0.0)
    final csv = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/devices.csv';
    final file = File(path);
    await file.writeAsString(csv);

    final xFile = XFile(path, mimeType: 'text/csv');

    // FIX: Replaced deprecated static Share class call with updated instanced SharePlus signature
    await SharePlus.instance.share(ShareParams(files: [xFile], text: 'Device list export'));
  }

  void _exportDevicesToXlsx() async {
    if (_allDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('sharedNoData'.tr)));
      return;
    }

    excel_lib.CellValue? cellFromDynamic(dynamic value) {
      if (value == null) {
        return null;
      }
      return excel_lib.TextCellValue(value.toString());
    }

    final excel = excel_lib.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    final header = ['ID', 'sharedName'.tr, 'deviceIdentifier'.tr];
    sheet.appendRow(header.map((e) => cellFromDynamic(e)).toList());

    for (var device in _allDevices) {
      final row = [device.id, device.name, device.uniqueId];
      sheet.appendRow(row.map((e) => cellFromDynamic(e)).toList());
    }

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/devices.xlsx';
    final file = File(path);

    final bytes = excel.encode();

    if (!mounted) return;

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('errorGeneral'.trParams({'error': 'Failed to encode Excel file'}))));
      return;
    }

    await file.writeAsBytes(bytes);

    final xFile = XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

    // FIX: Replaced deprecated static Share class call with updated instanced SharePlus signature
    await SharePlus.instance.share(ShareParams(files: [xFile], text: 'Device list export'));
  }

  Future<void> _importDevicesFromCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
      if (result == null) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw const FormatException('Unable to read the selected CSV file');
      }

      var csvContent = utf8.decode(bytes);
      if (csvContent.startsWith('\uFEFF')) {
        csvContent = csvContent.substring(1);
      }
      final rows = const CsvToListConverter(shouldParseNumbers: false).convert(csvContent);
      if (rows.isEmpty || rows.first.length < 3 || rows.first.first.toString().trim().toLowerCase() != 'id') {
        throw const FormatException('CSV must use the exported ID, name, identifier column order');
      }

      final existingIds = _allDevices.map((device) => device.uniqueId?.trim()).whereType<String>().toSet();
      final importedIds = <String>{};
      final devicesToImport = <api.Device>[];
      var skippedRows = 0;

      for (final row in rows.skip(1)) {
        if (row.every((value) => value.toString().trim().isEmpty)) continue;
        if (row.length < 3) {
          skippedRows++;
          continue;
        }

        final name = row[1].toString().trim();
        final uniqueId = row[2].toString().trim();
        if (name.isEmpty || uniqueId.isEmpty || existingIds.contains(uniqueId) || !importedIds.add(uniqueId)) {
          skippedRows++;
          continue;
        }
        devicesToImport.add(api.Device(name: name, uniqueId: uniqueId));
      }

      if (!mounted) return;
      if (devicesToImport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(skippedRows == 0 ? 'deviceImportNoDevices'.tr : 'deviceImportNoNewDevices'.trParams({'count': skippedRows.toString()}))));
        return;
      }

      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('deviceImportTitle'.tr),
          content: Text('deviceImportPreview'.trParams({'count': devicesToImport.length.toString(), 'skipped': skippedRows.toString()})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('sharedCancel'.tr)),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('deviceImportAction'.tr)),
          ],
        ),
      );
      if (shouldImport != true || !mounted) return;

      setState(() => _isImporting = true);
      final devicesApi = api.DevicesApi(Provider.of<TraccarProvider>(context, listen: false).apiClient);
      var importedCount = 0;
      try {
        for (final device in devicesToImport) {
          await devicesApi.postDevices(device);
          importedCount++;
        }
      } catch (error, stackTrace) {
        developer.log('Failed to import devices after $importedCount records', name: 'DevicesScreen', error: error, stackTrace: stackTrace);
        if (!mounted) return;
        setState(() => _isImporting = false);
        if (importedCount > 0) _fetchDevices();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('deviceImportPartialFailure'.trParams({'imported': importedCount.toString(), 'total': devicesToImport.length.toString(), 'error': error.toString()}))));
        return;
      }

      if (!mounted) return;
      setState(() => _isImporting = false);
      _fetchDevices();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('deviceImportSuccess'.trParams({'count': importedCount.toString(), 'skipped': skippedRows.toString()}))));
    } catch (error, stackTrace) {
      developer.log('Failed to import devices from CSV', name: 'DevicesScreen', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('deviceImportFailed'.trParams({'error': error.toString()}))));
    } finally {
      if (mounted && _isImporting) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showExportFormatSelectionDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Theme.of(context).colorScheme.surface,
        // ListTile needs a Material ancestor; the Cupertino popup route has none.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('deviceImportTitle'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text('deviceImportAction'.tr),
                  onTap: () {
                    Navigator.pop(context);
                    _importDevicesFromCsv();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('CSV (.csv) - Share/Save'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportDevicesToCsv();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: const Text('Excel (.xlsx) - Share/Save'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportDevicesToXlsx();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('deviceTitle'.tr),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'sharedSearch'.tr,
                prefixIcon: const Icon(CupertinoIcons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _filterDevices,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: _isImporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
            onPressed: _isImporting ? null : _showExportFormatSelectionDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<api.Device>?>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('errorGeneral'.trParams({'error': snapshot.error.toString()})));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('sharedNoData'.tr));
          } else {
            return ListView.builder(
              itemCount: _filteredDevices.length,
              itemBuilder: (context, index) {
                final device = _filteredDevices[index];
                return ListTile(
                  title: Text(device.name ?? 'unnamedDevice'.tr),
                  subtitle: Text(device.uniqueId ?? 'noUniqueId'.tr),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(CupertinoIcons.pencil), onPressed: () => _editDevice(device)),
                      IconButton(icon: const Icon(CupertinoIcons.trash), onPressed: () => _deleteDevice(device.id!)),
                      IconButton(
                        icon: const Icon(Icons.link),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectionsScreen(deviceId: device.id!)));
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: Padding(
        // 用 Padding 上移：Transform 只改變繪製位置，會讓可點擊區域與畫面位置錯開。
        padding: const EdgeInsets.only(bottom: 45),
        child: FloatingActionButton(
          onPressed: () async {
            final newDevice = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddDeviceScreen()));
            if (newDevice != null) {
              _fetchDevices();
            }
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
    );
  }
}
