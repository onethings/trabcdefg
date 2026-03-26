// settings_screen.dart
// A settings screen for the TracDefg app, allowing users to modify preferences and log out.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/screens/settings/notification_page.dart';
import 'package:trabcdefg/screens/settings/edit_user_screen.dart';
import 'package:trabcdefg/screens/settings/geofences_screen.dart';
import 'package:trabcdefg/screens/settings/devices_screen.dart';
import 'package:trabcdefg/screens/settings/groups_screen.dart';
import 'package:trabcdefg/screens/settings/drivers_screen.dart';
import 'package:trabcdefg/screens/settings/calendars_screen.dart';
import 'package:trabcdefg/screens/settings/computed_attributes_screen.dart';
import 'package:trabcdefg/screens/settings/maintenance_screen.dart';
import 'package:trabcdefg/screens/settings/saved_commands_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:get/get.dart';
import 'package:trabcdefg/services/localization_service.dart';
import 'package:trabcdefg/providers/theme_provider.dart';
import 'package:trabcdefg/providers/settings_provider.dart';



class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Method to show the language selection dialog with more recognizable names
  void _showLanguageSelectionDialog() {
    final Map<String, String> languageNames = {
      'af': 'Afrikaans',
      'ar_SA': 'العربية (السعودية)',
      'ar': 'العربية',
      'az': 'Azərbaycan dili',
      'bg': 'Български',
      'bn': 'বাংলা',
      'ca': 'Català',
      'cs': 'Čeština',
      'da': 'Dansk',
      'de': 'Deutsch',
      'el': 'Ελληνικά',
      'en_US': 'English (US)',
   //   'en': 'English',
      'es': 'Español',
      'et': 'Eesti',
      'fa': 'فارسی',
      'fi': 'Suomi',
      'fr': 'Français',
      'gl': 'Galego',
      'he': 'עברית',
      'hi': 'हिन्दी',
      'hr': 'Hrvatski',
      'hu': 'Magyar',
      'hy': 'Հայերեն',
      'id': 'Bahasa Indonesia',
      'it': 'Italiano',
      'ja': '日本語',
      'ka': 'ქართული',
      'kk': 'Қазақ',
      'km': 'ភាសាខ្មែរ',
      'ko': '한국어',
      'lo': 'ລາວ',
      'lt': 'Lietuvių',
      'lv': 'Latviešu',
      'mk': 'Македонски',
      'ml': 'മലയാളം',
      'mn': 'Монгол',
      'ms': 'Bahasa Melayu',
      'nb': 'Norsk bokmål',
      'ne': 'नेपाली',
      'nl': 'Nederlands',
      'nn': 'Norsk nynorsk',
      'pl': 'Polski',
      'pt_BR': 'Português (Brasil)',
      'pt': 'Português',
      'ro': 'Română',
      'ru': 'Русский',
      'si': 'සිංහල',
      'sk': 'Slovenčina',
      'sl': 'Slovenščina',
      'sq': 'Shqip',
      'sr': 'Srpski',
      'sv': 'Svenska',
      'sw': 'Kiswahili',
      'ta': 'தமிழ்',
      'th': 'ไทย',
      'tk': 'Türkmen',
      'tr': 'Türkçe',
      'uk': 'Українська',
      'uz': 'Oʻzbekcha',
      'vi': 'Tiếng Việt',
      'zh_TW': '繁體中文',
      'zh': '简体中文',
      'my': 'မြန်မာဘာသာ',
    };

    final List<Locale> supportedLocales = [
      const Locale('af'),
      const Locale('ar', 'SA'),
      const Locale('ar'),
      const Locale('az'),
      const Locale('bg'),
      const Locale('bn'),
      const Locale('ca'),
      const Locale('cs'),
      const Locale('da'),
      const Locale('de'),
      const Locale('el'),
      const Locale('en', 'US'),
   //   const Locale('en'),
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
      const Locale('pt'),
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
      const Locale('zh'),
      const Locale('my'),
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('loginLanguage'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: supportedLocales.map((locale) {
                final String localeCode = locale.languageCode + (locale.countryCode != null ? '_${locale.countryCode}' : '');
                final String? languageName = languageNames[localeCode];
                return ListTile(
                  title: Text(languageName ?? localeCode),
                  onTap: () async {
                    await LocalizationService.saveLocale(locale);
                    Get.updateLocale(locale);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showThemeSelectionDialog() {
    final themeProvider = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('settingsTheme'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('themeSystem'.tr),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: themeProvider.themeMode,
                  onChanged: (ThemeMode? value) {
                    if (value != null) themeProvider.setThemeMode(value);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.system);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('themeLight'.tr),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: (ThemeMode? value) {
                    if (value != null) themeProvider.setThemeMode(value);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.light);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('themeDark'.tr),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: (ThemeMode? value) {
                    if (value != null) themeProvider.setThemeMode(value);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.dark);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFontSizeDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('settingsFontSize'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('settingsNormal'.tr),
                leading: Radio<double>(
                  value: 1.0,
                  groupValue: settingsProvider.fontSizeScale,
                  onChanged: (double? value) {
                    if (value != null) settingsProvider.setFontSizeScale(value);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  settingsProvider.setFontSizeScale(1.0);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('settingsLarge'.tr),
                leading: Radio<double>(
                  value: 1.2,
                  groupValue: settingsProvider.fontSizeScale,
                  onChanged: (double? value) {
                    if (value != null) settingsProvider.setFontSizeScale(value);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  settingsProvider.setFontSizeScale(1.2);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('settingsExtraLarge'.tr),
                leading: Radio<double>(
                  value: 1.4,
                  groupValue: settingsProvider.fontSizeScale,
                  onChanged: (double? value) {
                    if (value != null) settingsProvider.setFontSizeScale(value);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  settingsProvider.setFontSizeScale(1.4);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMarkerSizeDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('settingsMarkerSize'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('settingsNormal'.tr),
                leading: Radio<double>(
                  value: 1.0,
                  groupValue: settingsProvider.markerSizeScale,
                  onChanged: (double? value) {
                    if (value != null) settingsProvider.setMarkerSizeScale(value);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  settingsProvider.setMarkerSizeScale(1.0);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('settingsLarge'.tr),
                leading: Radio<double>(
                  value: 1.5,
                  groupValue: settingsProvider.markerSizeScale,
                  onChanged: (double? value) {
                    if (value != null) settingsProvider.setMarkerSizeScale(value);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  settingsProvider.setMarkerSizeScale(1.5);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('settingsExtraLarge'.tr),
                leading: Radio<double>(
                  value: 2.0,
                  groupValue: settingsProvider.markerSizeScale,
                  onChanged: (double? value) {
                    if (value != null) settingsProvider.setMarkerSizeScale(value);
                    Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  settingsProvider.setMarkerSizeScale(2.0);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final traccarProvider = context.read<TraccarProvider>();
    final authService = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('settingsTitle'.tr),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: Text('loginLanguage'.tr),
                    onTap: _showLanguageSelectionDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.brightness_6),
                    title: Text('settingsTheme'.tr),
                    onTap: _showThemeSelectionDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.text_fields),
                    title: Text('settingsFontSize'.tr),
                    onTap: _showFontSizeDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text('settingsMarkerSize'.tr),
                    onTap: _showMarkerSizeDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: Text('sharedNotifications'.tr),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: Text('settingsUser'.tr),
                    onTap: () {
                     Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditUserScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.devices),
                    title: Text('deviceTitle'.tr),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DevicesScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text('sharedGeofence'.tr),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GeofencesScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: Text('settingsGroups'.tr),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GroupsScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text('sharedDrivers'.tr),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DriversScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text('sharedCalendars'.tr),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalendarsScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calculate),
                    title: Text('sharedComputedAttributes'.tr),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ComputedAttributesScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.build),
                    title: Text('sharedMaintenance'.tr),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MaintenanceScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.save),
                    title: Text('sharedSavedCommands'.tr),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedCommandsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Clear session data and disconnect WebSocket
                  traccarProvider.clearSessionAndData();
                  
                  // Navigate back to the login screen and clear the navigation stack
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50), // Make the button full-width
                ),
                child: Text('loginLogout'.tr),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      '${'appVersion'.tr}: ${snapshot.data!.version}+${snapshot.data!.buildNumber}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}