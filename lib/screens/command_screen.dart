// lib/screens/command_screen.dart
// CommandScreen for sending commands to selected device
import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // For .tr
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart'; // Import Provider
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/command_outbox.dart';
import 'package:trabcdefg/services/feedback.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/widgets/command_attributes_form.dart';

/// True when a send failed because the server could not be reached, rather
/// than because it answered with an error.
///
/// [api.ApiClient] wraps every transport error as `ApiException.withInner(400,
/// ...)`, so the failure only shows up in its `innerException`.
bool _isConnectionFailure(Object error) {
  if (error is IOException || error is TimeoutException || error is http.ClientException) {
    return true;
  }
  if (error is api.ApiException) {
    final inner = error.innerException;
    return inner is IOException || inner is TimeoutException || inner is http.ClientException;
  }
  return false;
}

class CommandScreen extends StatefulWidget {
  const CommandScreen({super.key});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  final _formKey = GlobalKey<FormState>(); // Added Form Key for validation
  api.CommandType? _selectedCommandType;
  bool _noQueue = false;
  bool _rebootAfterConnection = true;
  bool _isSending = false;
  final CommandAttributeControllers _attributeControllers =
      CommandAttributeControllers();
  int? _deviceId;
  String? _selectedDeviceName;
  List<api.CommandType> _availableCommandTypes = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  @override
  void dispose() {
    _attributeControllers.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getInt('selectedDeviceId');
    _selectedDeviceName = prefs.getString('selectedDeviceName');
    if (_deviceId == null) {
      if (mounted) FeedbackService.error('commandDeviceNotFound'.tr, context: context);
    }
    setState(() {});
  }

  String _getCommandTranslationKey(String? type) {
    if (type == null || type.isEmpty) {
      return 'commandTitle'.tr;
    }
    final capitalized = type.substring(0, 1).toUpperCase() + type.substring(1);
    return 'command$capitalized';
  }

  // --- API CALLS ---

  Future<void> _fetchAndShowCommandTypes(api.CommandsApi commandsApi) async {
    if (_deviceId == null) {
      FeedbackService.error('commandMissingDevice'.tr, context: context);
      return;
    }

    try {
      final types = await commandsApi.getCommandsTypes(deviceId: _deviceId);

      if (types == null || types.isEmpty) {
        FeedbackService.info('commandNoCommands'.tr, context: context);
        return;
      }

      _availableCommandTypes = types;

      if (!mounted) return;
      _showCommandTypePicker();
    } on api.ApiException catch (e) {
      if (mounted) FeedbackService.error('commandTypesLoadFailed'.trParams({'error': e.message ?? ''}), context: context);
    } catch (e) {
      if (mounted) FeedbackService.error('commandUnknownError'.tr, context: context);
    }
  }

  Future<void> _sendCommand(api.CommandsApi commandsApi) async {
    if (_isSending) return;

    if (!_formKey.currentState!.validate() ||
        _deviceId == null ||
        _selectedCommandType == null) {
      FeedbackService.error('commandSelectTypeAndFill'.tr, context: context);
      return;
    }

    final commandType = _selectedCommandType!.type;
    final isSetConnection = commandType == 'setConnection';
    if (isSetConnection) {
      // Show the value that is actually sent; some trackers reject octets
      // with leading zeros.
      _attributeControllers.server.text = normalizeServerAddress(
        _attributeControllers.server.text.trim(),
      );
    }
    final Map<String, dynamic> attributes = {
      // A connection switch must not be dropped while the tracker is offline.
      'noQueue': isSetConnection ? false : _noQueue,
      ...buildCommandAttributes(commandType, _attributeControllers),
    };

    final commandBody = api.Command(
      deviceId: _deviceId,
      type: commandType,
      attributes: attributes,
    );

    setState(() => _isSending = true);
    try {
      await commandsApi.postCommandsSend(commandBody);

      if (isSetConnection && _rebootAfterConnection) {
        try {
          await commandsApi.postCommandsSend(
            api.Command(
              deviceId: _deviceId,
              type: 'rebootDevice',
              attributes: const {'noQueue': false},
            ),
          );
        } catch (_) {
          // The tracker may already apply the new server and drop the link
          // before the restart command is delivered.
        }
      }

      // FIX: Guard use of BuildContext across async gaps
      if (!mounted) return;

      FeedbackService.success(
        isSetConnection
            ? 'commandSetConnectionSent'.tr
            : 'commandSent'.tr,
        context: context,
      );
      Navigator.of(context).pop();
    } on api.ApiException catch (e) {
      if (_isConnectionFailure(e)) {
        await _queueCommand(commandBody);
      } else {
        if (!mounted) return;
        FeedbackService.error('commandSendFailed'.trParams({'error': e.message ?? ''}), context: context);
      }
    } catch (e) {
      if (_isConnectionFailure(e)) {
        await _queueCommand(commandBody);
      } else {
        if (!mounted) return;
        FeedbackService.error('commandUnknownErrorDispatch'.tr, context: context);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Keeps the command instead of losing it, and leaves the screen open so the
  /// user still sees what they typed.
  Future<void> _queueCommand(api.Command command) async {
    try {
      await CommandOutbox.enqueue(command);
    } catch (e) {
      if (!mounted) return;
      FeedbackService.error('commandSendFailed'.trParams({'error': '$e'}), context: context);
      return;
    }
    if (!mounted) return;
    FeedbackService.info('commandQueued'.tr, context: context);
  }

  void _showCommandTypePicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          children: _availableCommandTypes.map((cmdType) {
            final typeString = cmdType.type ?? '';
            final translationKey = _getCommandTranslationKey(typeString);

            return ListTile(
              title: Text(translationKey.tr),
              onTap: () {
                setState(() {
                  _selectedCommandType = cmdType;
                  _attributeControllers.clear();
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
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final commandsApi = api.CommandsApi(traccarProvider.apiClient);

    return Scaffold(
      appBar: CupertinoNavigationBar(middle: Text('deviceCommand'.tr)),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_deviceId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    '${'sharedDevice'.tr}: $_selectedDeviceName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

              GestureDetector(
                onTap: () async {
                  await _fetchAndShowCommandTypes(commandsApi);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'sharedType'.tr,
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(CupertinoIcons.chevron_down),
                  ),
                  // FIX: Left operand can't be null layout fixed here
                  child: Text(
                    _selectedCommandType == null
                        ? 'commandSelectType'.tr
                        : _getCommandTranslationKey(_selectedCommandType!.type)
                              .tr,
                    style: TextStyle(
                      color: _selectedCommandType == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              if (_selectedCommandType?.type == 'setConnection')
                Row(
                  children: <Widget>[
                    Checkbox(
                      value: _rebootAfterConnection,
                      onChanged: (bool? newValue) {
                        setState(() {
                          _rebootAfterConnection = newValue ?? false;
                        });
                      },
                    ),
                    Expanded(child: Text('commandRebootAfterConnection'.tr)),
                  ],
                )
              else
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
                    Text('commandNoQueue'.tr),
                  ],
                ),

              CommandAttributeFields(
                type: _selectedCommandType?.type,
                controllers: _attributeControllers,
                outlined: true,
              ),

              const SizedBox(height: 32.0),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'sharedCancel'.tr,
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  ElevatedButton(
                    onPressed: _selectedCommandType != null && !_isSending
                        ? () => _sendCommand(commandsApi)
                        : null,
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('commandSend'.tr),
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
