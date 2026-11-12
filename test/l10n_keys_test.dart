// Guards the translation contract the UI code relies on:
// 1. every `.tr` / `.trParams` key used in lib/ must exist in en_US,
// 2. a sentence must never be used as a key (GetX cannot translate it),
// 3. trParams must pass the placeholders its en_US value declares.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/l10n/en_us.dart';

void main() {
  final keyPattern = RegExp(
    r"""(['"])([^'"\\]{1,200})\1\s*\.\s*tr(?:Params)?\b""",
  );
  final paramPattern = RegExp(
    r"""(['"])([^'"\\]{1,200})\1\s*\.\s*trParams\(\{([^}]*)\}""",
  );
  final placeholderPattern = RegExp(r"""['"]([A-Za-z0-9_]+)['"]\s*:""");

  test('every .tr/.trParams key used in lib exists in en_US', () {
    final missing = <String, Set<String>>{};
    for (final file in _dartFiles()) {
      final content = file.readAsStringSync();
      for (final match in keyPattern.allMatches(content)) {
        final key = match.group(2)!;
        if (!enUs.containsKey(key)) {
          missing.putIfAbsent(file.path, () => {}).add(key);
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'keys used in code but missing from en_US: $missing',
    );
  });

  test('no sentence is used as a translation key', () {
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      final content = file.readAsStringSync();
      for (final match in keyPattern.allMatches(content)) {
        final key = match.group(2)!;
        if (key.contains(' ')) {
          offenders.add('${file.path}: $key');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'these strings can never be translated: $offenders',
    );
  });

  test('trParams calls match the placeholders their en_US value declares', () {
    final problems = <String>[];
    for (final file in _dartFiles()) {
      final content = file.readAsStringSync();
      for (final match in paramPattern.allMatches(content)) {
        final key = match.group(2)!;
        final value = enUs[key];
        if (value == null) continue;
        for (final placeholder in placeholderPattern.allMatches(match.group(3)!)) {
          final name = placeholder.group(1)!;
          if (!value.contains('@$name')) {
            problems.add('${file.path}: "$key" has no @$name placeholder');
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}

Iterable<File> _dartFiles() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.replaceAll('\\', '/').contains('/src/generated_api/')) {
      continue;
    }
    yield entity;
  }
}
