import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/services/localization_service.dart';

void main() {
  // Locales that must be fully translated instead of falling back to English.
  const localizedLocales = ['en_US', 'zh', 'zh_TW', 'my', 'th', 'ja', 'ko'];

  const updateKeys = [
    'checkUpdate',
    'updateCurrentLatest',
    'updateNewVersionTitle',
    'updateNewVersionContent',
    'updateLater',
    'updateNow',
    'updateFailed',
  ];

  test('update flow keys are translated instead of showing raw keys', () {
    final translations = LocalizationService().keys;

    for (final locale in localizedLocales) {
      final localeKeys = translations[locale];
      expect(localeKeys, isNotNull, reason: 'missing locale table: $locale');

      for (final key in updateKeys) {
        final value = localeKeys![key];
        expect(value, isNotNull, reason: '$locale is missing "$key"');
        expect(value, isNotEmpty, reason: '$locale has an empty "$key"');
        expect(value, isNot(key), reason: '$locale "$key" falls back to the raw key');
      }
    }
  });

  test('localized locales cover every key defined for English', () {
    final translations = LocalizationService().keys;
    final english = translations['en_US']!;

    for (final locale in localizedLocales) {
      final localeKeys = translations[locale]!;
      final missing = english.keys.where((key) => !localeKeys.containsKey(key)).toList();
      expect(missing, isEmpty, reason: '$locale is missing keys: $missing');
    }
  });

  test('placeholders are preserved in translations', () {
    final translations = LocalizationService().keys;
    final english = translations['en_US']!;
    final placeholder = RegExp(r'@[A-Za-z]+');

    for (final locale in localizedLocales) {
      final localeKeys = translations[locale]!;
      for (final entry in english.entries) {
        final translated = localeKeys[entry.key];
        if (translated == null) continue;

        for (final match in placeholder.allMatches(entry.value)) {
          expect(
            translated.contains(match.group(0)!),
            isTrue,
            reason: '$locale "${entry.key}" is missing ${match.group(0)}',
          );
        }
      }
    }
  });
}
