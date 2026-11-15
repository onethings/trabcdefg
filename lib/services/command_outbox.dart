// lib/services/command_outbox.dart
// Commands that could not be sent are kept here and replayed once the
// connection returns.
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

/// Persists commands that could not be sent, keyed by insertion order.
class CommandOutbox {
  static const String _boxName = 'command_outbox';

  static Future<Box<String>> _open() => Hive.openBox<String>(_boxName);

  static Future<void> enqueue(api.Command command) async {
    final box = await _open();
    await box.add(jsonEncode(command.toJson()));
  }

  static Future<int> pendingCount() async {
    final box = await _open();
    return box.length;
  }

  /// Sends every queued command; a command is dropped only after it succeeds,
  /// so a partial failure keeps the rest for the next attempt. Returns how many
  /// were delivered.
  static Future<int> replay(api.CommandsApi commandsApi) async {
    final box = await _open();
    if (box.isEmpty) return 0;

    final keys = box.keys.cast<int>().toList()..sort();
    var sent = 0;
    for (final key in keys) {
      final raw = box.get(key);
      final command = raw == null ? null : _decode(raw);
      if (command == null) {
        // Unreadable entry; drop it so it cannot block the queue forever.
        await box.delete(key);
        continue;
      }

      try {
        await commandsApi.postCommandsSend(command);
      } catch (_) {
        break; // connection still down; keep the rest for later
      }
      await box.delete(key);
      sent++;
    }
    return sent;
  }

  static api.Command? _decode(String raw) {
    try {
      return api.Command.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
