// localization_service.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import all the language files.
import 'package:trabcdefg/l10n/af.dart';
import 'package:trabcdefg/l10n/ar_SA.dart';
import 'package:trabcdefg/l10n/ar.dart';
import 'package:trabcdefg/l10n/az.dart';
import 'package:trabcdefg/l10n/bg.dart';
import 'package:trabcdefg/l10n/bn.dart';
import 'package:trabcdefg/l10n/ca.dart';
import 'package:trabcdefg/l10n/cs.dart';
import 'package:trabcdefg/l10n/da.dart';
import 'package:trabcdefg/l10n/de.dart';
import 'package:trabcdefg/l10n/el.dart';
import 'package:trabcdefg/l10n/en_US.dart';
import 'package:trabcdefg/l10n/en.dart';
import 'package:trabcdefg/l10n/es.dart';
import 'package:trabcdefg/l10n/et.dart';
import 'package:trabcdefg/l10n/fa.dart';
import 'package:trabcdefg/l10n/fi.dart';
import 'package:trabcdefg/l10n/fr.dart';
import 'package:trabcdefg/l10n/gl.dart';
import 'package:trabcdefg/l10n/he.dart';
import 'package:trabcdefg/l10n/hi.dart';
import 'package:trabcdefg/l10n/hr.dart';
import 'package:trabcdefg/l10n/hu.dart';
import 'package:trabcdefg/l10n/hy.dart';
import 'package:trabcdefg/l10n/id.dart';
import 'package:trabcdefg/l10n/it.dart';
import 'package:trabcdefg/l10n/ja.dart';
import 'package:trabcdefg/l10n/ka.dart';
import 'package:trabcdefg/l10n/kk.dart';
import 'package:trabcdefg/l10n/km.dart';
import 'package:trabcdefg/l10n/ko.dart';
import 'package:trabcdefg/l10n/lo.dart';
import 'package:trabcdefg/l10n/lt.dart';
import 'package:trabcdefg/l10n/lv.dart';
import 'package:trabcdefg/l10n/mk.dart';
import 'package:trabcdefg/l10n/ml.dart';
import 'package:trabcdefg/l10n/mn.dart';
import 'package:trabcdefg/l10n/ms.dart';
import 'package:trabcdefg/l10n/nb.dart';
import 'package:trabcdefg/l10n/ne.dart';
import 'package:trabcdefg/l10n/nl.dart';
import 'package:trabcdefg/l10n/nn.dart';
import 'package:trabcdefg/l10n/pl.dart';
import 'package:trabcdefg/l10n/pt_BR.dart';
import 'package:trabcdefg/l10n/pt.dart';
import 'package:trabcdefg/l10n/ro.dart';
import 'package:trabcdefg/l10n/ru.dart';
import 'package:trabcdefg/l10n/si.dart';
import 'package:trabcdefg/l10n/sk.dart';
import 'package:trabcdefg/l10n/sl.dart';
import 'package:trabcdefg/l10n/sq.dart';
import 'package:trabcdefg/l10n/sr.dart';
import 'package:trabcdefg/l10n/sv.dart';
import 'package:trabcdefg/l10n/sw.dart';
import 'package:trabcdefg/l10n/ta.dart';
import 'package:trabcdefg/l10n/th.dart';
import 'package:trabcdefg/l10n/tk.dart';
import 'package:trabcdefg/l10n/tr.dart';
import 'package:trabcdefg/l10n/uk.dart';
import 'package:trabcdefg/l10n/uz.dart';
import 'package:trabcdefg/l10n/vi.dart';
import 'package:trabcdefg/l10n/zh_TW.dart';
import 'package:trabcdefg/l10n/zh.dart';

class LocalizationService extends Translations {
  static const fallbackLocale = Locale('en', 'US');
  static const _languageKey = 'saved_language_code';

  static final langs = [
    'Afrikaans',
    'العربية',
    'Azərbaycan',
    'Български',
    'বাংলা',
    'Català',
    'Čeština',
    'Dansk',
    'Deutsch',
    'Ελληνικά',
    'English',
    'Español',
    'Eesti',
    'فارسی',
    'Suomi',
    'Français',
    'Galego',
    'עברית',
    'हिंदी',
    'Hrvatski',
    'Magyar',
    'Հայերեն',
    'Bahasa Indonesia',
    'Italiano',
    '日本語',
    'ქართული',
    'Қазақ',
    'ភាសាខ្មែរ',
    '한국어',
    'ລາວ',
    'Lietuvių',
    'Latviešu',
    'Македонски',
    'മലയാളം',
    'Монгол',
    'Melayu',
    'Norsk bokmål',
    'नेपाली',
    'Nederlands',
    'Nynorsk',
    'Polski',
    'Português (Brasil)',
    'Português',
    'Română',
    'Русский',
    'සිංහල',
    'Slovenčina',
    'Slovenščina',
    'Shqip',
    'Srpski',
    'Svenska',
    'Kiswahili',
    'தமிழ்',
    'ไทย',
    'Türkmen',
    'Türkçe',
    'Українська',
    'Oʻzbekcha',
    'Tiếng Việt',
    '繁體中文',
    '简体中文',
  ];

  static final locales = [
    const Locale('af', 'ZA'),
    const Locale('ar', 'SA'),
    const Locale('ar'), // Assuming this is for generic Arabic
    const Locale('az'),
    const Locale('bg'),
    const Locale('bn'),
    const Locale('ca'),
    const Locale('cs'),
    const Locale('da'),
    const Locale('de'),
    const Locale('el'),
    const Locale('en', 'US'),
    const Locale('en'), // Assuming this is for generic English
    const Locale('es'),
    const Locale('et'),
    const Locale('fa'),
    const Locale('fi'),
    const Locale('fr'),
    const Locale('gl'),
    const Locale('he'),
    const Locale('hi'),
    const Locale('hr'),
    const Locale('hu'),
    const Locale('hy'),
    const Locale('id'),
    const Locale('it'),
    const Locale('ja'),
    const Locale('ka'),
    const Locale('kk'),
    const Locale('km'),
    const Locale('ko'),
    const Locale('lo'),
    const Locale('lt'),
    const Locale('lv'),
    const Locale('mk'),
    const Locale('ml'),
    const Locale('mn'),
    const Locale('ms'),
    const Locale('nb'),
    const Locale('ne'),
    const Locale('nl'),
    const Locale('nn'),
    const Locale('pl'),
    const Locale('pt', 'BR'),
    const Locale('pt'), // Assuming this is for generic Portuguese
    const Locale('ro'),
    const Locale('ru'),
    const Locale('si'),
    const Locale('sk'),
    const Locale('sl'),
    const Locale('sq'),
    const Locale('sr'),
    const Locale('sv'),
    const Locale('sw'),
    const Locale('ta'),
    const Locale('th'),
    const Locale('tk'),
    const Locale('tr'),
    const Locale('uk'),
    const Locale('uz'),
    const Locale('vi'),
    const Locale('zh', 'TW'),
    const Locale('zh'), // Assuming this is for generic Chinese
  ];

  @override
  Map<String, Map<String, String>> get keys => {
        'af_ZA': af,
        'ar_SA': arSA,
        'ar': ar,
        'az': az,
        'bg': bg,
        'bn': bn,
        'ca': ca,
        'cs': cs,
        'da': da,
        'de': de,
        'el': el,
        'en_US': en_US,
        // 'en': enUS,
        'es': es,
        'et': et,
        'fa': fa,
        'fi': fi,
        'fr': fr,
        'gl': gl,
        'he': he,
        'hi': hi,
        'hr': hr,
        'hu': hu,
        'hy': hy,
        'id': id,
        'it': it,
        'ja': ja,
        'ka': ka,
        'kk': kk,
        'km': km,
        'ko': ko,
        'lo': lo,
        'lt': lt,
        'lv': lv,
        'mk': mk,
        'ml': ml,
        'mn': mn,
        'ms': ms,
        'nb': nb,
        'ne': ne,
        'nl': nl,
        'nn': nn,
        'pl': pl,
        'pt_BR': ptBR,
        'pt': pt,
        'ro': ro,
        'ru': ru,
        'si': si,
        'sk': sk,
        'sl': sl,
        'sq': sq,
        'sr': sr,
        'sv': sv,
        'sw': sw,
        'ta': ta,
        'th': th,
        'tk': tk,
        'tr': tr,
        'uk': uk,
        'uz': uz,
        'vi': vi,
        'zh_TW': zhTW,
        'zh': zhCN,
      };

  // Method to save the selected locale to SharedPreferences
  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
  }

  // Method to get the saved locale from SharedPreferences
  static Future<Locale?> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString(_languageKey);
    if (languageCode != null) {
      return Locale(languageCode);
    }
    return null;
  }
  
  // Method to convert a language code string to a Locale object
  static Locale getLocaleFromLang(String lang) {
    // This logic maps the language code to the correct Locale object.
    switch (lang) {
      case 'af':
        return const Locale('af', 'ZA');
      case 'ar_SA':
        return const Locale('ar', 'SA');
      case 'ar':
        return const Locale('ar');
      case 'az':
        return const Locale('az');
      case 'bg':
        return const Locale('bg');
      case 'bn':
        return const Locale('bn');
      case 'ca':
        return const Locale('ca');
      case 'cs':
        return const Locale('cs');
      case 'da':
        return const Locale('da');
      case 'de':
        return const Locale('de');
      case 'el':
        return const Locale('el');
      case 'en_US':
        return const Locale('en', 'US');
      case 'en':
        return const Locale('en');
      case 'es':
        return const Locale('es');
      case 'et':
        return const Locale('et');
      case 'fa':
        return const Locale('fa');
      case 'fi':
        return const Locale('fi');
      case 'fr':
        return const Locale('fr');
      case 'gl':
        return const Locale('gl');
      case 'he':
        return const Locale('he');
      case 'hi':
        return const Locale('hi');
      case 'hr':
        return const Locale('hr');
      case 'hu':
        return const Locale('hu');
      case 'hy':
        return const Locale('hy');
      case 'id':
        return const Locale('id');
      case 'it':
        return const Locale('it');
      case 'ja':
        return const Locale('ja');
      case 'ka':
        return const Locale('ka');
      case 'kk':
        return const Locale('kk');
      case 'km':
        return const Locale('km');
      case 'ko':
        return const Locale('ko');
      case 'lo':
        return const Locale('lo');
      case 'lt':
        return const Locale('lt');
      case 'lv':
        return const Locale('lv');
      case 'mk':
        return const Locale('mk');
      case 'ml':
        return const Locale('ml');
      case 'mn':
        return const Locale('mn');
      case 'ms':
        return const Locale('ms');
      case 'nb':
        return const Locale('nb');
      case 'ne':
        return const Locale('ne');
      case 'nl':
        return const Locale('nl');
      case 'nn':
        return const Locale('nn');
      case 'pl':
        return const Locale('pl');
      case 'pt_BR':
        return const Locale('pt', 'BR');
      case 'pt':
        return const Locale('pt');
      case 'ro':
        return const Locale('ro');
      case 'ru':
        return const Locale('ru');
      case 'si':
        return const Locale('si');
      case 'sk':
        return const Locale('sk');
      case 'sl':
        return const Locale('sl');
      case 'sq':
        return const Locale('sq');
      case 'sr':
        return const Locale('sr');
      case 'sv':
        return const Locale('sv');
      case 'sw':
        return const Locale('sw');
      case 'ta':
        return const Locale('ta');
      case 'th':
        return const Locale('th');
      case 'tk':
        return const Locale('tk');
      case 'tr':
        return const Locale('tr');
      case 'uk':
        return const Locale('uk');
      case 'uz':
        return const Locale('uz');
      case 'vi':
        return const Locale('vi');
      case 'zh_TW':
        return const Locale('zh', 'TW');
      case 'zh':
        return const Locale('zh');
      default:
        return Get.deviceLocale ?? fallbackLocale;
    }
  }
}