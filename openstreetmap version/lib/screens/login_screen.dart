import 'dart:ui';
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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trabcdefg/providers/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController(
    text: AppConstants.traccarServerUrl,
  );
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _version = "";

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = "${info.version}+${info.buildNumber}");
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ... (保留原本的 _login, _handleQrScan, _showServerDialog 等邏輯不變) ...
  // 注意：這裡為了簡潔省略重複的邏輯方法，請保留你原本的實作

  // === 這是修復錯誤所需的功能邏輯 ===

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      String serverUrl = _serverUrlController.text.trim();
      if (serverUrl.isEmpty) {
        throw Exception('Please enter a server URL'.tr);
      }
      
      // Auto-append scheme if missing
      if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
        // If it looks like a local IP or localhost, default to http, else https
        final isLocal = RegExp(r'^(localhost|127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)').hasMatch(serverUrl);
        serverUrl = (isLocal ? 'http://' : 'https://') + serverUrl;
      }
      
      // Remove trailing slash
      while (serverUrl.endsWith('/')) {
        serverUrl = serverUrl.substring(0, serverUrl.length - 1);
      }
      
      _serverUrlController.text = serverUrl;
      final newApiClient = api.ApiClient(basePath: '$serverUrl/api');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('traccarServerUrl', serverUrl);

      final authService = context.read<AuthService>();
      final traccarProvider = context.read<TraccarProvider>();

      authService.apiClient = newApiClient;
      traccarProvider.apiClient = newApiClient;

      await authService.login(_emailController.text, _passwordController.text);

      final jSessionId = prefs.getString('jSessionId');
      if (jSessionId != null) traccarProvider.setSessionId(jSessionId);

      await traccarProvider.fetchInitialData();

      if (mounted) Navigator.of(context).pushNamed('/main');
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error'.tr,
          e.toString().contains('Failed host lookup') || e.toString().contains('Exception occurred:')
              ? 'Could not connect to server. Please check the URL and your network.'.tr
              : e.toString(),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleQrScan(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (result != null) {
      _serverUrlController.text = result;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('traccarServerUrl', result);
    }
  }

  void _showServerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => _ServerPickerSheet(
        onSelected: (url) {
          _serverUrlController.text = url;
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('traccarServerUrl', url);
          });
        },
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => const _LanguagePickerSheet(),
    );
  }

  // === 功能邏輯結束 ===

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // 1. 動態背景裝飾
          _buildBackground(theme),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  //  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      // 3. 主要登入卡片 (Glassmorphism)
                      _buildLoginCard(theme, themeProvider),

                      const SizedBox(height: 20),
                      _buildActionButtons(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 頂部與底部裝飾性組件
          _buildTopActions(theme),
          _buildBottomInfo(theme, themeProvider),
        ],
      ),
    );
  }

  Widget _buildBackground(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.08),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(ThemeData theme, ThemeProvider themeProvider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildTextField(
                controller: _serverUrlController,
                label: 'ServerUrl'.tr,
                icon: Icons.lan_outlined,
                readOnly: true,
                onTap: () => _showServerDialog(context),
                suffix: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  onPressed: () => _handleQrScan(context),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'userEmail'.tr,
                icon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: 'userPassword'.tr,
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          onTap: onTap,
          readOnly: readOnly,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: theme.colorScheme.onSurface.withOpacity(0.03),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'loginLogin'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () => Get.toNamed('/register'),
          child: Text('loginRegister'.tr),
        ),
        Text('|', style: TextStyle(color: theme.colorScheme.outlineVariant)),
        TextButton(
          onPressed: () => Get.toNamed('/reset-password'),
          child: Text('loginReset'.tr),
        ),
      ],
    );
  }

  Widget _buildTopActions(ThemeData theme) {
    return Positioned(
      top: 10,
      right: 10,
      child: SafeArea(
        child: IconButton(
          onPressed: () => _showLanguageDialog(context),
          icon: Icon(Icons.translate_rounded, color: theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildBottomInfo(ThemeData theme, ThemeProvider themeProvider) {
    return Positioned(
      bottom: 20,
      left: 24,
      right: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'v $_version',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          Row(
            children: [
              _buildThemeDot(
                themeProvider,
                AppThemePreset.obsidian,
                const Color(0xFF1A1A1A),
              ),
              _buildThemeDot(
                themeProvider,
                AppThemePreset.deepSea,
                const Color(0xFF0D1B2A),
              ),
              _buildThemeDot(
                themeProvider,
                AppThemePreset.mint,
                const Color(0xFF52B788),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeDot(
    ThemeProvider provider,
    AppThemePreset preset,
    Color color,
  ) {
    final isSelected = provider.activePreset == preset;
    return GestureDetector(
      onTap: () => provider.setPreset(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: isSelected ? 22 : 18,
        height: isSelected ? 22 : 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
      ),
    );
  }
}

// === 伺服器選擇彈窗組件 ===
class _ServerPickerSheet extends StatefulWidget {
  final Function(String) onSelected;
  const _ServerPickerSheet({required this.onSelected});

  @override
  State<_ServerPickerSheet> createState() => _ServerPickerSheetState();
}

class _ServerPickerSheetState extends State<_ServerPickerSheet> {
  final _textController = TextEditingController();
  String _inputQuery = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allServers = AppConstants.officialServers;
    
    // 過濾列表
    final filteredServers = allServers
        .where((s) => s.toLowerCase().contains(_inputQuery.toLowerCase()))
        .toList();

    // 判斷是否顯示「手動輸入」選項
    // 如果輸入框不為空，且不完全等於預設列表中的某一項，就顯示手動輸入按鈕
    bool showCustomOption = _inputQuery.isNotEmpty && !allServers.contains(_inputQuery);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // 確保鍵盤不遮擋
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          bottom: true,
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildHandle(), // 頂部灰色橫條
              const SizedBox(height: 16),
              Text('ServerUrl'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              // 搜尋與輸入框
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: TextField(
                  controller: _textController,
                  onChanged: (value) => setState(() => _inputQuery = value),
                  decoration: InputDecoration(
                    hintText: 'http://your-server-ip:8082',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    suffixIcon: _inputQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () {
                            widget.onSelected(_inputQuery);
                            Navigator.pop(context);
                          },
                        )
                      : null,
                    filled: true,
                    fillColor: theme.colorScheme.onSurface.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    // 如果有手動輸入內容，顯示一個特殊的「使用自定義」項目
                    if (showCustomOption)
                      ListTile(
                        leading: const Icon(Icons.add_link, color: Colors.blue),
                        title: Text('Use custom URL'.tr),
                        subtitle: Text(_inputQuery),
                        onTap: () {
                          widget.onSelected(_inputQuery);
                          Navigator.pop(context);
                        },
                      ),
                    
                    if (showCustomOption) const Divider(),

                    // 原始列表
                    ...filteredServers.map((url) => ListTile(
                      title: Text(url, style: const TextStyle(fontSize: 14)),
                      leading: const Icon(Icons.dns_outlined, size: 18),
                      onTap: () {
                        widget.onSelected(url);
                        Navigator.pop(context);
                      },
                    )).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40, height: 4,
      decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
    );
  }
}

// === 語言選擇彈窗組件 ===
class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet();

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allLangs = LocalizationService.langs;
    final allLocales = LocalizationService.locales;

    final filteredIndices = <int>[];
    for (int i = 0; i < allLangs.length; i++) {
      if (allLangs[i].toLowerCase().contains(_searchQuery.toLowerCase())) {
        filteredIndices.add(i);
      }
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          bottom: true,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'loginLanguage'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'sharedSearch'.tr,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.colorScheme.onSurface.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: filteredIndices.length,
                  separatorBuilder: (context, index) => Divider(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                  itemBuilder: (context, index) {
                    final idx = filteredIndices[index];
                    return ListTile(
                      title: Text(allLangs[idx]),
                      onTap: () async {
                        await LocalizationService.saveLocale(allLocales[idx]);
                        Get.updateLocale(allLocales[idx]);
                        if (mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
