// add_device_screen.dart
// A screen to add a new driver in the TracDefg app.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/qr_scanner_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class AddDeviceScreen extends StatefulWidget {
  final api.Device? device;

  const AddDeviceScreen({super.key, this.device});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
  // Changed _AddDeviceScreenState to State<AddDeviceScreen> above ^
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _uniqueIdController;
  late final TextEditingController _phoneController;
  late final TextEditingController _modelController;
  late final TextEditingController _contactController;
  late int? _groupId;
  late String? _category;
  late bool _disabled;

  final List<TextEditingController> _attributeKeyControllers = [];
  final List<TextEditingController> _attributeValueControllers = [];

  List<api.Group>? _groups;
  bool _loadingGroups = true;

  // Category options mirroring the Traccar web UI.
  static const List<String> _categoryKeys = [
    'categoryDefault',
    'categoryAnimal',
    'categoryBicycle',
    'categoryBoat',
    'categoryBus',
    'categoryCar',
    'categoryCamper',
    'categoryCrane',
    'categoryHelicopter',
    'categoryMotorcycle',
    'categoryPerson',
    'categoryPlane',
    'categoryShip',
    'categoryTractor',
    'categoryTrailer',
    'categoryTrain',
    'categoryTram',
    'categoryTruck',
    'categoryVan',
    'categoryScooter',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _nameController = TextEditingController(text: d?.name ?? '');
    _uniqueIdController = TextEditingController(text: d?.uniqueId ?? '');
    _phoneController = TextEditingController(text: d?.phone ?? '');
    _modelController = TextEditingController(text: d?.model ?? '');
    _contactController = TextEditingController(text: d?.contact ?? '');
    _groupId = d?.groupId;
    _category = d?.category ?? (d == null ? 'categoryDefault'.tr : null);
    _disabled = d?.disabled ?? false;

    final attrs =
        (d?.attributes as Map<String, dynamic>?) ?? const <String, dynamic>{};
    for (final entry in attrs.entries) {
      _attributeKeyControllers.add(TextEditingController(text: entry.key));
      _attributeValueControllers.add(
        TextEditingController(text: entry.value?.toString() ?? ''),
      );
    }

    _fetchGroups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _uniqueIdController.dispose();
    _phoneController.dispose();
    _modelController.dispose();
    _contactController.dispose();
    for (final c in _attributeKeyControllers) {
      c.dispose();
    }
    for (final c in _attributeValueControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchGroups() async {
    try {
      final traccarProvider = Provider.of<TraccarProvider>(
        context,
        listen: false,
      );
      final groupsApi = api.GroupsApi(traccarProvider.apiClient);
      final groups = await groupsApi.getGroups();
      if (mounted) {
        setState(() {
          _groups = groups ?? [];
          _loadingGroups = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load groups: $e');
      if (mounted) {
        setState(() => _loadingGroups = false);
      }
    }
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _uniqueIdController.text = result);
    }
  }

  void _addAttribute() {
    setState(() {
      _attributeKeyControllers.add(TextEditingController());
      _attributeValueControllers.add(TextEditingController());
    });
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributeKeyControllers.removeAt(index).dispose();
      _attributeValueControllers.removeAt(index).dispose();
    });
  }

  // void _saveDevice() async {
  //   if (_formKey.currentState!.validate()) {
  //     _formKey.currentState!.save();
  //     final newDevice = api.Device(
  //       id: widget.device?.id,
  //       name: _name,
  //       uniqueId: _uniqueId,
  //     );

  //     try {
  //       if (widget.device == null) {
  //         final traccarProvider = Provider.of<TraccarProvider>(
  //           context,
  //           listen: false,
  //         );
  //         final devicesApi = api.DevicesApi(traccarProvider.apiClient);
  //         // Add new device
  //         await devicesApi.devicesPost(newDevice);
  //         Navigator.of(context).pop(true);
  //       } else {
  //         final traccarProvider = Provider.of<TraccarProvider>(
  //           context,
  //           listen: false,
  //         );
  //         final devicesApi = api.DevicesApi(traccarProvider.apiClient);
  //         // Update existing device
  //         await devicesApi.devicesIdPut(newDevice.id!, newDevice);
  //         Navigator.of(context).pop(true);
  //       }
  //     } catch (e) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('deviceSaveFailed'.trParams({'error': e.toString()})),
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }
  // Conceptual code for AddDeviceScreen.dart

  void _saveDevice() async {
    if (!_formKey.currentState!.validate()) return;

    final attributesMap = <String, dynamic>{};
    for (var i = 0; i < _attributeKeyControllers.length; i++) {
      final key = _attributeKeyControllers[i].text.trim();
      if (key.isNotEmpty) {
        attributesMap[key] = _attributeValueControllers[i].text;
      }
    }

    final device = api.Device(
      id: widget.device?.id,
      name: _nameController.text.trim(),
      uniqueId: _uniqueIdController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      model: _modelController.text.trim().isEmpty
          ? null
          : _modelController.text.trim(),
      contact: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      category: _category,
      groupId: _groupId,
      disabled: _disabled,
      attributes: attributesMap.isEmpty ? null : attributesMap,
    );

    try {
      final traccarProvider = Provider.of<TraccarProvider>(
        context,
        listen: false,
      );
      final devicesApi = api.DevicesApi(traccarProvider.apiClient);

      if (widget.device == null) {
        await devicesApi.postDevices(device);
      } else {
        await devicesApi.putDevicesId(device.id!, device);
      }
      if (mounted) {
        Navigator.of(context).pop(device);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save device: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.device != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${isEditing ? 'sharedEdit'.tr : 'sharedAdd'.tr} ${'sharedDevice'.tr}',
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.checkmark_circle),
            tooltip: 'sharedSave'.tr,
            onPressed: _saveDevice,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader('sharedRequired'.tr),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: _decoration('sharedName'.tr),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _uniqueIdController,
                decoration: _decoration(
                  'deviceIdentifier'.tr,
                  helper: 'deviceIdentifierHelp'.tr,
                  suffix: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    tooltip: 'sharedQrCode'.tr,
                    onPressed: _scanQrCode,
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Identifier is required'
                    : null,
              ),

              const SizedBox(height: 24),
              _sectionHeader('sharedExtra'.tr),
              if (_loadingGroups)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else
                DropdownButtonFormField<int?>(
                  initialValue: _groupId,
                  decoration: _decoration(
                    'groupDialog'.tr,
                    hint: 'groupNoGroup'.tr,
                  ),
                  items: _groupItems(),
                  onChanged: (v) => setState(() => _groupId = v),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _decoration('sharedPhone'.tr),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                textInputAction: TextInputAction.next,
                decoration: _decoration('deviceModel'.tr),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                textInputAction: TextInputAction.next,
                decoration: _decoration('deviceContact'.tr),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _category,
                decoration: _decoration('deviceCategory'.tr),
                items: _categoryItems(),
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                title: Text('sharedDisabled'.tr),
                value: _disabled,
                onChanged: (v) => setState(() => _disabled = v),
              ),

              const SizedBox(height: 24),
              _sectionHeader('sharedAttributes'.tr),
              for (var i = 0; i < _attributeKeyControllers.length; i++)
                _attributeRow(i),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _addAttribute,
                  icon: const Icon(Icons.add),
                  label: Text('sharedAdd'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(
    String label, {
    String? helper,
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      hintText: hint,
      suffixIcon: suffix,
      border: const OutlineInputBorder(),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  List<DropdownMenuItem<int?>> _groupItems() {
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(value: null, child: Text('groupNoGroup'.tr)),
    ];
    var found = false;
    for (final g in _groups ?? const <api.Group>[]) {
      if (g.id == _groupId) found = true;
      items.add(
        DropdownMenuItem<int?>(value: g.id, child: Text(g.name ?? '#${g.id}')),
      );
    }
    // Keep the value selectable even if the group no longer exists.
    if (_groupId != null && !found) {
      items.add(
        DropdownMenuItem<int?>(value: _groupId, child: Text('#$_groupId')),
      );
    }
    return items;
  }

  List<DropdownMenuItem<String?>> _categoryItems() {
    final options = _categoryKeys.map((k) => k.tr).toSet().toList();
    if (_category != null && !options.contains(_category)) {
      options.insert(0, _category!);
    }
    return options
        .map(
          (value) =>
              DropdownMenuItem<String?>(value: value, child: Text(value)),
        )
        .toList();
  }

  Widget _attributeRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _attributeKeyControllers[index],
              decoration: _decoration('Key'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _attributeValueControllers[index],
              decoration: _decoration('Value'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            tooltip: 'sharedRemove'.tr,
            onPressed: () => _removeAttribute(index),
          ),
        ],
      ),
    );
  }
}
