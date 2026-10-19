// command_attributes_form.dart
// Shared inputs for the command attributes supported by the JT808 protocol
// encoder (Traccar 6.16.0).
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Holds the text controllers for every attribute a command can send.
class CommandAttributeControllers {
  final data = TextEditingController();
  final frequency = TextEditingController();
  final server = TextEditingController();
  final port = TextEditingController();
  final message = TextEditingController();
  final index = TextEditingController();
  final speedLimit = TextEditingController();
  final duration = TextEditingController();

  void clear() {
    for (final controller in [
      data,
      frequency,
      server,
      port,
      message,
      index,
      speedLimit,
      duration,
    ]) {
      controller.clear();
    }
  }

  void dispose() {
    data.dispose();
    frequency.dispose();
    server.dispose();
    port.dispose();
    message.dispose();
    index.dispose();
    speedLimit.dispose();
    duration.dispose();
  }
}

String? _requiredText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'sharedRequired'.tr;
  }
  return null;
}

/// JT808 writes these values with ByteBuf.writeInt, so they must fit a
/// signed 32-bit integer.
const int _maxInt32 = 2147483647;

String? _positiveInteger(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null || parsed <= 0 || parsed > _maxInt32) {
    return 'sharedInvalidNumber'.tr;
  }
  return null;
}

String? _optionalPositiveInteger(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return _positiveInteger(value);
}

/// Optional index/control flag written with ByteBuf.writeByte.
String? _optionalByte(String? value, {int min = 0}) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < min || parsed > 255) {
    return 'sharedInvalidNumber'.tr;
  }
  return null;
}

String? _serverAddress(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return 'sharedRequired'.tr;
  }
  final parts = text.split('.');
  if (parts.length == 4 &&
      parts.every((part) => RegExp(r'^\d+$').hasMatch(part))) {
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet > 255) {
        return 'sharedInvalidServerAddress'.tr;
      }
    }
  }
  return null;
}

/// Pads are stripped so addresses like 104.237.009.196 are sent as
/// 104.237.9.196, which devices parse as a normal IPv4 address.
String normalizeServerAddress(String value) {
  final parts = value.split('.');
  if (parts.length != 4 ||
      !parts.every((part) => RegExp(r'^\d+$').hasMatch(part))) {
    return value;
  }
  final octets = <String>[];
  for (final part in parts) {
    final octet = int.tryParse(part);
    if (octet == null || octet > 255) {
      return value;
    }
    octets.add(octet.toString());
  }
  return octets.join('.');
}

String? _port(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  if (parsed == null || parsed <= 0 || parsed > 65535) {
    return 'sharedInvalidNumber'.tr;
  }
  return null;
}

/// Builds the `attributes` map expected by the Traccar command API.
Map<String, dynamic> buildCommandAttributes(
  String? type,
  CommandAttributeControllers controllers,
) {
  final attributes = <String, dynamic>{};
  final index = int.tryParse(controllers.index.text.trim());

  switch (type) {
    case 'custom':
      attributes['data'] = controllers.data.text;
      break;
    case 'positionPeriodic':
      attributes['frequency'] = int.parse(controllers.frequency.text.trim());
      break;
    case 'setConnection':
      attributes['server'] = normalizeServerAddress(
        controllers.server.text.trim(),
      );
      attributes['port'] = int.parse(controllers.port.text.trim());
      break;
    case 'message':
    case 'voiceMessage':
      attributes['message'] = controllers.message.text;
      break;
    case 'requestPhoto':
    case 'outputControl':
    case 'videoStart':
    case 'videoStop':
      if (index != null) {
        attributes['index'] = index;
      }
      break;
    case 'setSpeedLimit':
      attributes['data'] = int.parse(controllers.speedLimit.text.trim());
      if (controllers.duration.text.trim().isNotEmpty) {
        attributes['duration'] = int.parse(controllers.duration.text.trim());
      }
      break;
  }

  return attributes;
}

/// Renders the input fields required by the selected command type.
class CommandAttributeFields extends StatelessWidget {
  const CommandAttributeFields({
    super.key,
    required this.type,
    required this.controllers,
    this.outlined = false,
  });

  final String? type;
  final CommandAttributeControllers controllers;
  final bool outlined;

  InputDecoration _decoration(
    String label, {
    String? hintText,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label.tr,
      hintText: hintText?.tr,
      suffixText: suffixText,
      border: outlined ? const OutlineInputBorder() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[];

    switch (type) {
      case 'custom':
        fields.add(
          TextFormField(
            controller: controllers.data,
            decoration: _decoration(
              'commandData',
              hintText: 'Enter custom command data',
            ),
            validator: _requiredText,
          ),
        );
        break;
      case 'positionPeriodic':
        fields.add(
          TextFormField(
            controller: controllers.frequency,
            keyboardType: TextInputType.number,
            decoration: _decoration(
              'commandFrequency',
              suffixText: 'sharedSecondAbbreviation'.tr,
            ),
            validator: _positiveInteger,
          ),
        );
        break;
      case 'setConnection':
        fields.addAll([
          TextFormField(
            controller: controllers.server,
            decoration: _decoration('commandServer'),
            validator: _serverAddress,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controllers.port,
            keyboardType: TextInputType.number,
            decoration: _decoration('commandPort'),
            validator: _port,
          ),
        ]);
        break;
      case 'message':
      case 'voiceMessage':
        fields.add(
          TextFormField(
            controller: controllers.message,
            decoration: _decoration('commandMessage'),
            validator: _requiredText,
          ),
        );
        break;
      case 'requestPhoto':
      case 'outputControl':
        fields.add(
          TextFormField(
            controller: controllers.index,
            keyboardType: TextInputType.number,
            decoration: _decoration('commandIndex'),
            validator: (value) => _optionalByte(value),
          ),
        );
        break;
      case 'videoStart':
      case 'videoStop':
        fields.add(
          TextFormField(
            controller: controllers.index,
            keyboardType: TextInputType.number,
            decoration: _decoration('commandIndex'),
            validator: (value) => _optionalByte(value, min: 1),
          ),
        );
        break;
      case 'setSpeedLimit':
        fields.addAll([
          TextFormField(
            controller: controllers.speedLimit,
            keyboardType: TextInputType.number,
            decoration: _decoration('attributeSpeedLimit', suffixText: 'km/h'),
            validator: _positiveInteger,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controllers.duration,
            keyboardType: TextInputType.number,
            decoration: _decoration(
              'reportDuration',
              suffixText: 'sharedSecondAbbreviation'.tr,
            ),
            validator: _optionalPositiveInteger,
          ),
        ]);
        break;
    }

    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const SizedBox(height: 16), ...fields],
    );
  }
}
