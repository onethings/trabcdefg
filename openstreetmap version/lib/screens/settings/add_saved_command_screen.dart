// add_saved_command_screen.dart

import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class AddSavedCommandScreen extends StatefulWidget {
  const AddSavedCommandScreen({super.key});

  @override
  _AddSavedCommandScreenState createState() => _AddSavedCommandScreenState();
}

class _AddSavedCommandScreenState extends State<AddSavedCommandScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _description;
  String? _selectedType;
  bool _noQueue = false;
  late Future<List<api.CommandType>?> _commandTypesFuture;

  @override
  void initState() {
    super.initState();
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    // Correct way to instantiate CommandsApi with the authenticated client
    final commandsApi = api.CommandsApi(traccarProvider.apiClient);
    setState(() {
      _commandTypesFuture = commandsApi.commandsTypesGet();
    });
  }

  void _saveCommand() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final newCommand = api.Command(
        description: _description!,
        type: _selectedType!,
        attributes: {'noQueue': _noQueue},
      );

      try {
        final traccarProvider = Provider.of<TraccarProvider>(
          context,
          listen: false,
        );
        // Correct way to instantiate CommandsApi with the authenticated client
        final commandsApi = api.CommandsApi(traccarProvider.apiClient);
        await commandsApi.commandsPost(newCommand);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('sharedSavedCommand'.tr + ' ' + 'sharedSaved'.tr),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('errorGeneral'.tr + ': $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sharedAdd'.tr + ' ' + 'sharedSavedCommand'.tr),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText:
                        'sharedDescription'.tr +
                        ' (' +
                        'sharedRequired'.tr +
                        ')',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'sharedPleaseEnterDescription'.tr;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _description = value;
                  },
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<api.CommandType>?>(
                  future: _commandTypesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: Text('sharedLoading'.tr));
                    } else if (snapshot.hasError) {
                      return Text('errorGeneral'.tr + ': ${snapshot.error}');
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('sharedNoData'.tr));
                    } else {
                      final commandTypes = snapshot.data!
                          .map((type) => type.type!)
                          .toList();
                      _selectedType ??= commandTypes.first;
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'sharedType'.tr),
                        value: _selectedType,
                        items: commandTypes.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(_getTranslatedCommandType(value)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedType = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'sharedPleaseSelectCommandType'.tr;
                          }
                          return null;
                        },
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: _noQueue,
                      onChanged: (bool? value) {
                        setState(() {
                          _noQueue = value ?? false;
                        });
                      },
                    ),
                    Text('commandNoQueue'.tr),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('sharedCancel'.tr),
            ),
            ElevatedButton(
              onPressed: _saveCommand,
              child: Text('sharedSave'.tr),
            ),
          ],
        ),
      ),
    );
  }

  String _getTranslatedCommandType(String commandType) {
    switch (commandType) {
      case 'custom':
        return 'commandCustom'.tr;
      case 'deviceIdentification':
        return 'commandDeviceIdentification'.tr;
      case 'positionSingle':
        return 'commandPositionSingle'.tr;
      case 'positionPeriodic':
        return 'commandPositionPeriodic'.tr;
      case 'positionStop':
        return 'commandPositionStop'.tr;
      case 'engineStop':
        return 'commandEngineStop'.tr;
      case 'engineResume':
        return 'commandEngineResume'.tr;
      case 'alarmArm':
        return 'commandAlarmArm'.tr;
      case 'alarmDisarm':
        return 'commandAlarmDisarm'.tr;
      case 'alarmDismiss':
        return 'commandAlarmDismiss'.tr;
      case 'setTimezone':
        return 'commandSetTimezone'.tr;
      case 'requestPhoto':
        return 'commandRequestPhoto'.tr;
      case 'powerOff':
        return 'commandPowerOff'.tr;
      case 'rebootDevice':
        return 'commandRebootDevice'.tr;
      case 'factoryReset':
        return 'commandFactoryReset'.tr;
      case 'sendSms':
        return 'commandSendSms'.tr;
      case 'sendUssd':
        return 'commandSendUssd'.tr;
      case 'sosNumber':
        return 'commandSosNumber'.tr;
      case 'silenceTime':
        return 'commandSilenceTime'.tr;
      case 'setPhonebook':
        return 'commandSetPhonebook'.tr;
      case 'voiceMessage':
        return 'commandVoiceMessage'.tr;
      case 'outputControl':
        return 'commandOutputControl'.tr;
      case 'voiceMonitoring':
        return 'commandVoiceMonitoring'.tr;
      case 'setAgps':
        return 'commandSetAgps'.tr;
      case 'setIndicator':
        return 'commandSetIndicator'.tr;
      case 'configuration':
        return 'commandConfiguration'.tr;
      case 'getVersion':
        return 'commandGetVersion'.tr;
      case 'firmwareUpdate':
        return 'commandFirmwareUpdate'.tr;
      case 'setConnection':
        return 'commandSetConnection'.tr;
      case 'setOdometer':
        return 'commandSetOdometer'.tr;
      case 'getModemStatus':
        return 'commandGetModemStatus'.tr;
      case 'getDeviceStatus':
        return 'commandGetDeviceStatus'.tr;
      case 'setSpeedLimit':
        return 'commandSetSpeedLimit'.tr;
      case 'modePowerSaving':
        return 'commandModePowerSaving'.tr;
      case 'modeDeepSleep':
        return 'commandModeDeepSleep'.tr;
      case 'alarmGeofence':
        return 'commandAlarmGeofence'.tr;
      case 'alarmBattery':
        return 'commandAlarmBattery'.tr;
      case 'alarmSos':
        return 'commandAlarmSos'.tr;
      case 'alarmRemove':
        return 'commandAlarmRemove'.tr;
      case 'alarmClock':
        return 'commandAlarmClock'.tr;
      case 'alarmSpeed':
        return 'commandAlarmSpeed'.tr;
      case 'alarmFall':
        return 'commandAlarmFall'.tr;
      case 'alarmVibration':
        return 'commandAlarmVibration'.tr;
      default:
        return commandType;
    }
  }
}
