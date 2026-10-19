// settings_screen.dart
// A settings screen for the TracDefg app, allowing users to modify preferences and log out.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/settings_provider.dart';
import 'package:trabcdefg/providers/theme_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/settings/calendars_screen.dart';
import 'package:trabcdefg/screens/settings/computed_attributes_screen.dart';
import 'package:trabcdefg/screens/settings/devices_screen.dart';
import 'package:trabcdefg/screens/settings/drivers_screen.dart';
import 'package:trabcdefg/screens/settings/edit_user_screen.dart';
import 'package:trabcdefg/screens/settings/geofences_screen.dart';
import 'package:trabcdefg/screens/settings/groups_screen.dart';
import 'package:trabcdefg/screens/settings/maintenance_screen.dart';
import 'package:trabcdefg/screens/settings/notification_page.dart';
import 'package:trabcdefg/screens/settings/saved_commands_screen.dart';
import 'package:trabcdefg/screens/settings/server_info_screen.dart';
import 'package:trabcdefg/screens/settings/emulator_screen.dart';
import 'package:trabcdefg/screens/reports/reports_screen.dart';
import 'package:trabcdefg/services/auth_session_store.dart';
import 'package:trabcdefg/services/localization_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  late final Future<String?> _serverVersion;

  @override
  void initState() {
    super.initState();
    _serverVersion = context.read<TraccarProvider>().fetchServerVersion();
  }

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

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 420,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Theme.of(context).colorScheme.surface,
        // ListTile needs a Material ancestor; the Cupertino popup route has none.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('loginLanguage'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: supportedLocales.map((locale) {
                        final String localeCode = locale.languageCode + (locale.countryCode != null ? '_${locale.countryCode}' : '');
                        final String? languageName = languageNames[localeCode];
                        return ListTile(
                          title: Text(languageName ?? localeCode),
                          onTap: () async {
                            await LocalizationService.saveLocale(locale);
                            if (!mounted) {
                              return;
                            }
                            Get.updateLocale(locale);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemeSelectionDialog() {
    final themeProvider = context.read<ThemeProvider>();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Theme.of(context).colorScheme.surface,
        // RadioListTile needs a Material ancestor; the Cupertino popup route has none.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('settingsTheme'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                RadioGroup<ThemeMode>(
                  groupValue: themeProvider.themeMode,
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                    }
                    Navigator.of(context).pop();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<ThemeMode>(title: Text('themeSystem'.tr), value: ThemeMode.system),
                      RadioListTile<ThemeMode>(title: Text('themeLight'.tr), value: ThemeMode.light),
                      RadioListTile<ThemeMode>(title: Text('themeDark'.tr), value: ThemeMode.dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Theme.of(context).colorScheme.surface,
        // RadioListTile needs a Material ancestor; the Cupertino popup route has none.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('settingsFontSize'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                RadioGroup<double>(
                  groupValue: settingsProvider.fontSizeScale,
                  onChanged: (double? value) {
                    if (value != null) {
                      settingsProvider.setFontSizeScale(value);
                    }
                    Navigator.of(context).pop();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<double>(title: Text('settingsNormal'.tr), value: 1.0),
                      RadioListTile<double>(title: Text('settingsLarge'.tr), value: 1.2),
                      RadioListTile<double>(title: Text('settingsExtraLarge'.tr), value: 1.4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMarkerSizeDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Theme.of(context).colorScheme.surface,
        // RadioListTile needs a Material ancestor; the Cupertino popup route has none.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('settingsMarkerSize'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                RadioGroup<double>(
                  groupValue: settingsProvider.markerSizeScale,
                  onChanged: (double? value) {
                    if (value != null) {
                      settingsProvider.setMarkerSizeScale(value);
                    }
                    Navigator.of(context).pop();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<double>(title: Text('settingsNormal'.tr), value: 1.0),
                      RadioListTile<double>(title: Text('settingsLarge'.tr), value: 1.5),
                      RadioListTile<double>(title: Text('settingsExtraLarge'.tr), value: 2.0),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsSection({required String title, required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.w700),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 60, height: 1), children[i]],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({required IconData icon, required String title, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 19, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(title),
      trailing: Icon(CupertinoIcons.chevron_right, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.35)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final traccarProvider = context.read<TraccarProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              height: 148,
              padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    right: -28,
                    top: -58,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.onPrimary.withValues(alpha: 0.09)),
                    ),
                  ),
                  Positioned(
                    right: 48,
                    bottom: -74,
                    child: Container(
                      width: 138,
                      height: 138,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.15), width: 22),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.slider_horizontal_3, color: colorScheme.onPrimary.withValues(alpha: 0.88), size: 25),
                        const SizedBox(height: 12),
                        Text(
                          'settingsTitle'.tr,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _settingsSection(
              title: 'reportTitle'.tr,
              children: [
                _settingsTile(
                  icon: CupertinoIcons.doc_text,
                  title: 'reportTitle'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen())),
                ),
              ],
            ),
            _settingsSection(
              title: 'loginLanguage'.tr,
              children: [
                _settingsTile(icon: CupertinoIcons.globe, title: 'loginLanguage'.tr, onTap: _showLanguageSelectionDialog),
                _settingsTile(icon: CupertinoIcons.sun_max, title: 'settingsTheme'.tr, onTap: _showThemeSelectionDialog),
                _settingsTile(icon: Icons.text_fields, title: 'settingsFontSize'.tr, onTap: _showFontSizeDialog),
                _settingsTile(icon: CupertinoIcons.location_solid, title: 'settingsMarkerSize'.tr, onTap: _showMarkerSizeDialog),
              ],
            ),
            _settingsSection(
              title: 'settingsUser'.tr,
              children: [
                _settingsTile(
                  icon: CupertinoIcons.bell,
                  title: 'sharedNotifications'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationPage())),
                ),
                _settingsTile(
                  icon: CupertinoIcons.person_crop_circle,
                  title: 'settingsUser'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditUserScreen())),
                ),
              ],
            ),
            _settingsSection(
              title: 'deviceTitle'.tr,
              children: [
                _settingsTile(
                  icon: Icons.devices,
                  title: 'deviceTitle'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DevicesScreen())),
                ),
                _settingsTile(
                  icon: CupertinoIcons.location_solid,
                  title: 'sharedGeofence'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GeofencesScreen())),
                ),
                _settingsTile(
                  icon: CupertinoIcons.person_2,
                  title: 'settingsGroups'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupsScreen())),
                ),
                _settingsTile(
                  icon: CupertinoIcons.person,
                  title: 'sharedDrivers'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DriversScreen())),
                ),
                _settingsTile(
                  icon: CupertinoIcons.calendar_today,
                  title: 'sharedCalendars'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarsScreen())),
                ),
                _settingsTile(
                  icon: Icons.calculate,
                  title: 'sharedComputedAttributes'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ComputedAttributesScreen())),
                ),
                _settingsTile(
                  icon: CupertinoIcons.wrench,
                  title: 'sharedMaintenance'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MaintenanceScreen())),
                ),
                _settingsTile(
                  icon: Icons.save,
                  title: 'sharedSavedCommands'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedCommandsScreen())),
                ),
                _settingsTile(
                  icon: CupertinoIcons.info_circle,
                  title: 'sharedInfoTitle'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServerInfoScreen())),
                ),
                _settingsTile(
                  icon: Icons.developer_mode,
                  title: 'sharedEmulator'.tr,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmulatorScreen())),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: OutlinedButton.icon(
                onPressed: () {
                  traccarProvider.clearSessionAndData();
                  Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                icon: const Icon(Icons.logout),
                label: Text('loginLogout'.tr),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Consumer<TraccarProvider>(
                builder: (context, provider, _) => FutureBuilder<PackageInfo>(
                  future: _packageInfo,
                  builder: (context, packageSnapshot) {
                    final serverUrl = provider.apiClient.basePath.replaceFirst(RegExp(r'/api/?$'), '');
                    final email = provider.currentUser?.email ?? AuthSessionStore.instance.email ?? '-';
                    final secondaryText = TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.58), fontSize: 12);

                      return Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(CupertinoIcons.info_circle, size: 17, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text('sharedInfoTitle'.tr, style: Theme.of(context).textTheme.titleSmall),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('${'appVersion'.tr}: ${packageSnapshot.data == null ? '-' : '${packageSnapshot.data!.version}+${packageSnapshot.data!.buildNumber}'}', style: secondaryText),
                              const SizedBox(height: 4),
                              Text('${'settingsServer'.tr}: $serverUrl', style: secondaryText),
                              const SizedBox(height: 4),
                              FutureBuilder<String?>(
                                future: _serverVersion,
                                builder: (context, versionSnapshot) {
                                  final version = versionSnapshot.data;
                                  if (version == null) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text('${'settingsServerVersion'.tr}: $version', style: secondaryText),
                                  );
                                },
                              ),
                              Text('${'userEmail'.tr}: $email', style: secondaryText),
                            ],
                          ),
                        ),
                      );
                },
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
