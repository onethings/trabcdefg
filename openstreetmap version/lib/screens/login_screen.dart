import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/constants.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/screens/qr_scanner_screen.dart';
import 'package:get/get.dart';
import 'package:trabcdefg/services/localization_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController(text: AppConstants.traccarServerUrl);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final traccarProvider = context.read<TraccarProvider>();

      await authService.login(
        _emailController.text,
        _passwordController.text,
      );

      final prefs = await SharedPreferences.getInstance();
      final jSessionId = prefs.getString('jSessionId');
      if (jSessionId != null) {
        traccarProvider.setSessionId(jSessionId);
      }

      await traccarProvider.fetchInitialData();

      if (mounted) {
        Navigator.of(context).pushNamed('/main');
      }
    } on api.ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'loginFailed'.tr}: ${e.message}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showServerSelectionDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('SelectServer'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...AppConstants.officialServers.map((url) {
                  return ListTile(
                    title: Text(url),
                    onTap: () {
                      _serverUrlController.text = url;
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
                const Divider(),
                TextField(
                  controller: _serverUrlController,
                  decoration: InputDecoration(
                    labelText: 'CustomServerURL'.tr,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final scannedUrl = await Navigator.of(context).push<String>(
                          MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                        );
                        if (scannedUrl != null) {
                          _serverUrlController.text = scannedUrl;
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('loginTitle'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: _showLanguageSelectionDialog,
          ),
          IconButton(
            icon: const Icon(Icons.public),
            onPressed: _showServerSelectionDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _serverUrlController,
              decoration: InputDecoration(labelText: 'ServerUrl'.tr),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'userEmail'.tr),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'userPassword'.tr),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _login, child: Text('loginLogin'.tr)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/register');
              },
              child: Text('loginRegister'.tr),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/reset-password');
              },
              child: Text('loginReset'.tr),
            ),
          ],
        ),
      ),
    );
  }
}