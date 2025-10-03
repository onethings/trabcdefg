// add_device_screen.dart

import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class AddDeviceScreen extends StatefulWidget {
  final api.Device? device;

  const AddDeviceScreen({super.key, this.device});

  @override
  _AddDeviceScreenState createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _uniqueId;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      _name = widget.device!.name!;
      _uniqueId = widget.device!.uniqueId!;
    } else {
      _name = '';
      _uniqueId = '';
    }
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
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();
    
    // Create the device object from the form data
    final newDevice = api.Device(
      id: widget.device?.id,
      name: _name,
      uniqueId: _uniqueId,
    );

    try {
      final traccarProvider = Provider.of<TraccarProvider>(
        context,
        listen: false,
      );
      final devicesApi = api.DevicesApi(traccarProvider.apiClient);
      
      if (widget.device == null) {
        // Add new device
        await devicesApi.devicesPost(newDevice);
        // Return the new device object
        if (mounted) {
          Navigator.of(context).pop(newDevice);
        }
      } else {
        // Update existing device
        await devicesApi.devicesIdPut(newDevice.id!, newDevice);
        // Return the updated device object
        if (mounted) {
          Navigator.of(context).pop(newDevice);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('deviceSaveFailed'.trParams({'error': e.toString()})),
          ),
        );
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device == null ? 'sharedAdd'.tr+'sharedDevice'.tr : 'sharedEdit'.tr+'sharedDevice'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDevice,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: InputDecoration(labelText: 'sharedName'.tr),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'deviceEnterName'.tr;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _name = value!;
                  },
                ),
                TextFormField(
                  initialValue: _uniqueId,
                  decoration: InputDecoration(labelText: 'deviceIdentifier'.tr),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'deviceEnterUniqueId'.tr;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _uniqueId = value!;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}