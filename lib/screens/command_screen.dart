// lib/screens/command_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart'; // For .tr and Get.snackbar
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';

class CommandScreen extends StatefulWidget {
  const CommandScreen({super.key});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  final _formKey = GlobalKey<FormState>(); // Added Form Key for validation
  api.CommandType? _selectedCommandType; 
  bool _noQueue = false;
  final TextEditingController _dataController = TextEditingController();
  int? _deviceId;
  String? _selectedDeviceName;
  List<api.CommandType> _availableCommandTypes = []; 

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    // Assuming the map screen stores the selected device's ID in 'selectedDeviceId'
    _deviceId = prefs.getInt('selectedDeviceId');
    _selectedDeviceName = prefs.getString('selectedDeviceName');
    if (_deviceId == null) {
      Get.snackbar('Error'.tr, 'Device ID not found.'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() {});
  }
  
  // Helper function to map API type (camelCase) to Translation Key (commandPascalCase)
  String _getCommandTranslationKey(String? type) {
    if (type == null || type.isEmpty) {
      return 'Unknown Command'; // Fallback text if type is missing
    }
    // E.g., 'custom' -> 'Custom' -> 'commandCustom'
    // E.g., 'engineStop' -> 'EngineStop' -> 'commandEngineStop'
    final capitalized = type.substring(0, 1).toUpperCase() + type.substring(1);
    return 'command$capitalized';
  }

  // --- API CALLS USING TraccarProvider AND CommandsApi ---

  Future<void> _fetchAndShowCommandTypes(api.CommandsApi commandsApi) async {
    if (_deviceId == null) {
      Get.snackbar('Error'.tr, 'Cannot fetch types, device ID is missing.'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      final types = await commandsApi.commandsTypesGet(deviceId: _deviceId);

      if (types == null || types.isEmpty) {
        Get.snackbar('Info'.tr, 'No commands available for this device.'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      _availableCommandTypes = types;

      if (!mounted) return;
      _showCommandTypePicker();
      
    } on api.ApiException catch (e) {
      Get.snackbar('Error'.tr, 'Failed to load command types: ${e.message}'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error'.tr, 'An unknown error occurred.'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _sendCommand(api.CommandsApi commandsApi) async {
    if (!_formKey.currentState!.validate() || _deviceId == null || _selectedCommandType == null) {
      Get.snackbar('Error'.tr, 'Please select a command type and fill required fields.'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    
    final Map<String, dynamic> attributes = {
      'noQueue': _noQueue,
    };
    
    final commandType = _selectedCommandType!.type;

    if (commandType == 'custom') {
      attributes['data'] = _dataController.text;
    }
    
    final commandBody = api.Command(
      deviceId: _deviceId,
      type: commandType,
      attributes: attributes, 
    );

    try {
      await commandsApi.commandsSendPost(commandBody);

      Get.snackbar('Success'.tr, 'Command sent successfully.'.tr,
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green.shade100);
      Navigator.of(context).pop();
    } on api.ApiException catch (e) {
      Get.snackbar('Error'.tr, 'Failed to send command: ${e.message}'.tr,
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade100);
    } catch (e) {
      Get.snackbar('Error'.tr, 'An unknown error occurred during command dispatch.'.tr,
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade100);
    }
  }

  // --- UI/Helper Methods ---

  void _showCommandTypePicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          children: _availableCommandTypes.map((cmdType) {
            final typeString = cmdType.type ?? '';
            // *** TRANSLATION FIX APPLIED HERE ***
            final translationKey = _getCommandTranslationKey(typeString);
            
            return ListTile(
              // Use the mapped key with .tr
              title: Text(translationKey.tr), 
              onTap: () {
                setState(() {
                  _selectedCommandType = cmdType;
                  _dataController.clear(); 
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final commandsApi = api.CommandsApi(traccarProvider.apiClient);

    return Scaffold(
      appBar: AppBar(
        title: Text('Required'.tr), // "Required".tr is likely missing, consider using a provided key like "commandTitle"
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Device ID Display
              if (_deviceId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text('sharedDevice'.tr+': $_selectedDeviceName',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),

              // Type Input Field
              GestureDetector(
                onTap: () async {
                  await _fetchAndShowCommandTypes(commandsApi); 
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Type'.tr,
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  // Use the helper for displaying the selected type as well
                  child: Text(
                    _getCommandTranslationKey(_selectedCommandType?.type)?.tr ?? 'Select Command Type'.tr,
                    style: TextStyle(
                      color: _selectedCommandType == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // No Queue Checkbox
              Row(
                children: <Widget>[
                  Checkbox(
                    value: _noQueue,
                    onChanged: (bool? newValue) {
                      setState(() {
                        _noQueue = newValue ?? false;
                      });
                    },
                  ),
                  Text('commandNoQueue'.tr), // Using provided translation key
                ],
              ),
              const SizedBox(height: 16.0),

              // Data Input Field (Visible only for 'custom' type)
              if (_selectedCommandType?.type == 'custom')
                TextFormField(
                  controller: _dataController,
                  decoration: InputDecoration(
                    labelText: 'commandData'.tr, // Using provided translation key
                    border: const OutlineInputBorder(),
                    hintText: 'Enter custom command data'.tr,
                  ),
                  validator: (value) {
                    if (_selectedCommandType?.type == 'custom' && (value == null || value.isEmpty)) {
                      return 'Data is required for custom command.'.tr;
                    }
                    return null;
                  },
                ),

              const SizedBox(height: 32.0),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cancel button
                    },
                    child: Text('Cancel'.tr,
                        style: TextStyle(color: Theme.of(context).primaryColor)),
                  ),
                  const SizedBox(width: 8.0),
                  ElevatedButton(
                    onPressed: _selectedCommandType != null
                        ? () => _sendCommand(commandsApi) 
                        : null,
                    child: Text('commandSend'.tr), // Using provided translation key
                  ),
                ],
              ),
            ],
          ),
        ),
      ), 
    );
  }
}