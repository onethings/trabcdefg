import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/widgets/command_attributes_form.dart';

void main() {
  late CommandAttributeControllers controllers;

  setUp(() {
    controllers = CommandAttributeControllers();
  });

  tearDown(() {
    controllers.dispose();
  });

  test('custom command sends data', () {
    controllers.data.text = '0xF030';
    expect(buildCommandAttributes('custom', controllers), {'data': '0xF030'});
  });

  test('positionPeriodic sends frequency', () {
    controllers.frequency.text = '30';
    expect(buildCommandAttributes('positionPeriodic', controllers), {
      'frequency': 30,
    });
  });

  test('setConnection sends server and port', () {
    controllers.server.text = 'example.com';
    controllers.port.text = '8082';
    expect(buildCommandAttributes('setConnection', controllers), {
      'server': 'example.com',
      'port': 8082,
    });
  });

  test('setConnection strips leading zeros from IPv4 octets', () {
    controllers.server.text = '104.237.009.196';
    controllers.port.text = '5015';
    expect(buildCommandAttributes('setConnection', controllers), {
      'server': '104.237.9.196',
      'port': 5015,
    });
  });

  test('message and voiceMessage send message', () {
    controllers.message.text = 'hello';
    expect(buildCommandAttributes('message', controllers), {
      'message': 'hello',
    });
    expect(buildCommandAttributes('voiceMessage', controllers), {
      'message': 'hello',
    });
  });

  test('index is optional and sent when provided', () {
    for (final type in [
      'requestPhoto',
      'outputControl',
      'videoStart',
      'videoStop',
    ]) {
      expect(buildCommandAttributes(type, controllers), isEmpty);
      controllers.index.text = '2';
      expect(buildCommandAttributes(type, controllers), {'index': 2});
      controllers.index.clear();
    }
  });

  test('setSpeedLimit sends speed and optional duration', () {
    controllers.speedLimit.text = '80';
    expect(buildCommandAttributes('setSpeedLimit', controllers), {'data': 80});

    controllers.duration.text = '10';
    expect(buildCommandAttributes('setSpeedLimit', controllers), {
      'data': 80,
      'duration': 10,
    });
  });

  test('commands without attributes produce an empty map', () {
    expect(buildCommandAttributes('rebootDevice', controllers), isEmpty);
    expect(buildCommandAttributes('positionSingle', controllers), isEmpty);
    expect(buildCommandAttributes('configuration', controllers), isEmpty);
  });
}
