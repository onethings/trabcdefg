// lib/screens/device_list_screen.dart
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:trabcdefg/providers/settings_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/command_screen.dart';
import 'package:trabcdefg/screens/notifications_screen.dart';
import 'package:trabcdefg/screens/settings/add_device_screen.dart';
import 'package:trabcdefg/services/feedback.dart';
import 'package:trabcdefg/services/map_navigation.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/status_utils.dart';
import 'package:trabcdefg/widgets/offline_address_service.dart';
import 'package:trabcdefg/widgets/skeleton.dart';
import 'package:trabcdefg/widgets/state_views.dart';
import 'package:url_launcher/url_launcher.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedStatus = 0;
  bool _showMileage = false;
  int _mileageDays = 1; // 1 = today, 3 = last 3 days
  final Map<int, double> _mileageMap = {}; // deviceId -> distance in km
  final bool _isLoadingMileage = false;
  final Map<String, String> _addressCache = {};

  @override
  void initState() {
    super.initState();
    _loadMileagePreference();
    // 註解：_setupTimeagoLocales() 已建議移至 main.dart 執行全域註冊，此處不再重複呼叫
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  // 讀取里程偏好
  Future<void> _loadMileagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showMileage = prefs.getBool('showMileage') ?? false;
      _mileageDays = prefs.getInt('mileageDays') ?? 1;
    });
    if (_showMileage) {
      _fetchMileageData();
    }
  }

  // 切換里程顯示
  Future<void> _toggleMileage() async {
    final prefs = await SharedPreferences.getInstance();
    final newShowMileage = !_showMileage;
    await prefs.setBool('showMileage', newShowMileage);

    if (!mounted) return;
    setState(() {
      _showMileage = newShowMileage;
    });

    final provider = context.read<TraccarProvider>();
    if (_showMileage) {
      provider.clearMileageMap();
      _fetchMileageData();
    }
  }

  // 設定里程天數
  Future<void> _setMileageDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mileageDays', days);

    if (!mounted) return;
    setState(() {
      _mileageDays = days;
    });

    final provider = context.read<TraccarProvider>();
    provider.clearMileageMap();
    if (_showMileage) {
      _fetchMileageData();
    }
  }

  // 簡化後的呼叫方法
  Future<void> _fetchMileageData() async {
    final traccarProvider = context.read<TraccarProvider>();
    await traccarProvider.fetchMileageData(_mileageDays);
  }

  // 下拉重新整理（provider.loadError 會反映載入失敗）
  Future<void> _refresh() async {
    try {
      await context.read<TraccarProvider>().fetchInitialData();
      if (_showMileage) {
        _mileageMap.clear();
        await _fetchMileageData();
      }
    } catch (_) {
      // provider.loadError surfaces the state; nothing else to do here
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final traccarProvider = Provider.of<TraccarProvider>(context);
    final bool simpleMode = context.watch<SettingsProvider>().simpleMode;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(simpleMode),
            // 篩選 chip 與里程量測在簡易模式收起來，搜尋框仍可找車。
            if (!simpleMode) _buildFilterAndToggle(traccarProvider),
            Expanded(child: _buildBody(traccarProvider, simpleMode)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TraccarProvider provider, bool simpleMode) {
    if (provider.isLoading && provider.devices.isEmpty) {
      return const _DeviceListSkeleton();
    }

    final now = DateTime.now().toUtc();

    final filteredDevices = provider.devices.where((device) {
      final matchesQuery = (device.name ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final position = provider.getPosition(device.id!);
      final effectiveStatus = resolveDeviceStatus(device, position, now);

      final String? filterStatus = _getStatusText(_selectedStatus);
      final bool matchesFilter = (_selectedStatus == 0) || (_selectedStatus == 4 && provider.isFavorite(device.id!)) || (filterStatus == effectiveStatus);
      return matchesQuery && matchesFilter;
    }).toList();

    // 排序：愛心放在最上面
    filteredDevices.sort((a, b) {
      final aFav = provider.isFavorite(a.id!);
      final bFav = provider.isFavorite(b.id!);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    });

    return RefreshIndicator(
      onRefresh: _refresh,
      child: provider.devices.isEmpty
          ? (provider.loadError != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 100),
                    children: [
                      const SizedBox(height: 80),
                      ErrorState(message: 'sharedError'.tr, retryLabel: 'sharedRetry'.tr, onRetry: _refresh),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 100),
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.directions_car_outlined,
                        title: 'dashboardNoDevices'.tr,
                        hint: 'deviceEmptyHint'.tr,
                        action: TextButton(onPressed: () => Get.to(() => const AddDeviceScreen()), child: Text('sharedAdd'.tr)),
                      ),
                    ],
                  ))
          : filteredDevices.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 100),
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'sharedNoData'.tr,
                  hint: 'deviceFilteredEmptyHint'.tr,
                  action: TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _selectedStatus = 0);
                    },
                    child: Text('sharedClearFilters'.tr),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 100),
              itemCount: filteredDevices.length,
              itemBuilder: (context, index) {
                final device = filteredDevices[index];
                final position = provider.getPosition(device.id!);
                return _buildDeviceCard(device, position, provider, now, simpleMode);
              },
            ),
    );
  }

  Widget _buildDeviceCard(api.Device device, api.Position? position, TraccarProvider provider, DateTime now, bool simpleMode) {
    final isFavorite = provider.isFavorite(device.id!);
    final theme = Theme.of(context);
    final status = resolveDeviceStatus(device, position, now);
    final statusLabel = switch (status) {
      'online' => 'deviceStatusOnline'.tr,
      'offline' => 'deviceStatusOffline'.tr,
      _ => 'deviceStatusUnknown'.tr,
    };
    final statusColor = switch (status) {
      'online' => const Color(0xFF1B9A59),
      'offline' => theme.colorScheme.outline,
      _ => Colors.orange.shade700,
    };
    final attributes = position?.attributes is Map<String, dynamic> ? position!.attributes as Map<String, dynamic> : <String, dynamic>{};
    final bool isIgnitionOn = attributes['ignition'] == true;
    final double speedKmH = (position?.speed ?? 0.0) * 1.852;
    final DateTime? lastUpdate = position?.fixTime?.toUtc() ?? device.lastUpdate?.toUtc();
    final isStale = status == 'offline';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.read<MapNavigation>().focusDevice(device.id!),
        onLongPress: () => _showCardActions(device, position),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(CupertinoIcons.car_fill, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                device.name ?? '...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                            if (!simpleMode)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'sharedFavorite'.tr,
                                padding: const EdgeInsets.only(left: 8),
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                icon: Icon(isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart, color: isFavorite ? theme.colorScheme.error : theme.colorScheme.outline, size: 20),
                                onPressed: () => provider.toggleFavorite(device.id!),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: theme.textTheme.bodySmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AccTimerBadge(speed: speedKmH, isStale: isStale, isOn: isIgnitionOn, lastUpdate: lastUpdate, baseColor: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(CupertinoIcons.location_solid, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 7),
                  Expanded(child: _buildAddressWidget(position?.latitude, position?.longitude)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: theme.colorScheme.outline),
                  const SizedBox(width: 5),
                  Expanded(child: _DeviceTimeAgoText(lastUpdate: lastUpdate)),
                  if (_showMileage) _buildMileageWidget(device.id!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The card's secondary actions, on long press.
  ///
  /// A [CupertinoContextMenu] would be the nearer-to-iOS shape, but its press
  /// preview is inserted into the root overlay and only removed once its
  /// animation reaches dismissed. Focusing a device switches tabs in the same
  /// frame, which mutes this tab's tickers, so the preview froze and stayed
  /// painted over the map.
  Future<void> _showCardActions(api.Device device, api.Position? position) async {
    HapticFeedback.mediumImpact();
    final bool simpleMode = context.read<SettingsProvider>().simpleMode;
    final _CardAction? action = await showModalBottomSheet<_CardAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _cardAction(sheetContext, CupertinoIcons.map, 'actionNavigate'.tr, _CardAction.navigate),
            // 分享與下指令會改動外部狀態，簡易模式不提供。
            if (!simpleMode) _cardAction(sheetContext, CupertinoIcons.share, 'sharedShare'.tr, _CardAction.share),
            if (!simpleMode) _cardAction(sheetContext, CupertinoIcons.paperplane, 'commandTitle'.tr, _CardAction.command),
          ],
        ),
      ),
    );

    switch (action) {
      case _CardAction.navigate:
        await _navigateToPosition(position);
      case _CardAction.share:
        await _sharePosition(device, position);
      case _CardAction.command:
        await _openCommandScreen(device);
      case null:
        break;
    }
  }

  Widget _cardAction(BuildContext sheetContext, IconData icon, String label, _CardAction action) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface),
      title: Text(label),
      onTap: () => Navigator.of(sheetContext).pop(action),
    );
  }

  String? _googleMapsLink(api.Position? position) {
    final lat = position?.latitude?.toDouble();
    final lng = position?.longitude?.toDouble();
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) return null;
    return 'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  }

  Future<void> _navigateToPosition(api.Position? position) async {
    final link = _googleMapsLink(position);
    if (link == null) {
      FeedbackService.info('mapNoPositions'.tr, context: context);
      return;
    }
    final launched = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!launched && mounted) FeedbackService.info('deviceOpenMapsFailed'.tr, context: context);
  }

  Future<void> _sharePosition(api.Device device, api.Position? position) async {
    final link = _googleMapsLink(position);
    if (link == null) {
      FeedbackService.info('mapNoPositions'.tr, context: context);
      return;
    }
    final deviceName = device.name ?? 'sharedDevice'.tr;
    await SharePlus.instance.share(ShareParams(text: '$deviceName — $link'));
  }

  Future<void> _openCommandScreen(api.Device device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', device.id!);
    if (device.name != null) {
      await prefs.setString('selectedDeviceName', device.name!);
    }
    if (!mounted) return;
    Get.to(() => const CommandScreen());
  }

  Widget _buildAddressWidget(num? lat, num? lon) {
    if (lat == null || lon == null) {
      return _addressText('sharedNoData'.tr);
    }
    final cacheKey = "${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}";
    if (_addressCache.containsKey(cacheKey)) {
      return _addressText(_addressCache[cacheKey]!);
    }
    return FutureBuilder<String>(future: _getAddressAsync(lat, lon, cacheKey), builder: (context, snapshot) => _addressText(snapshot.data ?? '...'));
  }

  Future<String> _getAddressAsync(num lat, num lon, String cacheKey) async {
    final address = await OfflineAddressService.getAddress(lat.toDouble(), lon.toDouble());
    if (mounted) {
      setState(() {
        _addressCache[cacheKey] = address;
      });
    }
    return address;
  }

  Widget _addressText(String text) => Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis);

  Widget _buildMileageWidget(int deviceId) {
    final traccarProvider = Provider.of<TraccarProvider>(context);
    final mileage = traccarProvider.mileageMap[deviceId];
    if (mileage == null) return const SizedBox.shrink();

    final mileageLabel = _mileageDays == 1 ? 'dashboardTodayDistance'.tr : '${'dashboardTodayDistance'.tr} (3 ${'sharedDays'.tr})';

    return Row(
      children: [
        Icon(Icons.route_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          '$mileageLabel: ${mileage.toStringAsFixed(1)} ${'sharedKm'.tr}',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFilterAndToggle(TraccarProvider provider) {
    final now = DateTime.now().toUtc();
    final counts = List<int>.filled(5, 0);
    for (final device in provider.devices) {
      counts[0]++;
      final status = resolveDeviceStatus(device, provider.getPosition(device.id!), now);
      switch (status) {
        case 'online':
          counts[1]++;
        case 'offline':
          counts[2]++;
        default:
          counts[3]++;
      }
      if (provider.isFavorite(device.id!)) counts[4]++;
    }
    final labels = ['deviceStatusAll'.tr, 'deviceStatusOnline'.tr, 'deviceStatusOffline'.tr, 'deviceStatusUnknown'.tr, 'deviceStatusFavorite'.tr];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final selected = _selectedStatus == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${labels[index]}  ${counts[index]}'),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant),
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onSelected: (_) => setState(() => _selectedStatus = index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(bool simpleMode) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 10),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'sharedSearchDevices'.tr,
                  prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                  suffixIcon: _searchQuery.isEmpty ? null : IconButton(onPressed: _searchController.clear, tooltip: 'sharedClear'.tr, icon: const Icon(Icons.close_rounded, size: 18)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            // 里程量測、天數、通知在簡易模式收起來，只留下找車用的搜尋。
            if (!simpleMode) ...[
              IconButton(
                onPressed: _toggleMileage,
                tooltip: 'dashboardTodayDistance'.tr,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: _isLoadingMileage ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_showMileage ? Icons.route : Icons.route_outlined, color: _showMileage ? theme.colorScheme.primary : null),
              ),
              if (_showMileage)
                PopupMenuButton<int>(
                  tooltip: 'dashboardTodayDistance'.tr,
                  onSelected: _setMileageDays,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: Icon(Icons.calendar_month_outlined, color: theme.colorScheme.primary),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 18, color: _mileageDays == 1 ? theme.colorScheme.primary : Colors.transparent),
                          const SizedBox(width: 8),
                          Text('dashboardTodayDistance'.tr),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 3,
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 18, color: _mileageDays == 3 ? theme.colorScheme.primary : Colors.transparent),
                          const SizedBox(width: 8),
                          Text('${'dashboardTodayDistance'.tr} (3 ${'sharedDays'.tr})'),
                        ],
                      ),
                    ),
                  ],
                ),
              IconButton(
                onPressed: () => Get.to(() => const NotificationsScreen()),
                tooltip: 'sharedNotifications'.tr,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(CupertinoIcons.bell, size: 22),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _getStatusText(int index) => [null, 'online', 'offline', 'unknown', 'favorite'][index];
}

enum _CardAction { navigate, share, command }

class _DeviceTimeAgoText extends StatefulWidget {
  final DateTime? lastUpdate;

  const _DeviceTimeAgoText({required this.lastUpdate});

  @override
  State<_DeviceTimeAgoText> createState() => _DeviceTimeAgoTextState();
}

class _DeviceTimeAgoTextState extends State<_DeviceTimeAgoText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastSeen = widget.lastUpdate == null ? '--' : timeago.format(widget.lastUpdate!, locale: Get.locale?.languageCode ?? 'zh');

    return Text(lastSeen, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, fontSize: 11));
  }
}

class _AccTimerBadge extends StatefulWidget {
  final double speed;
  final bool isStale;
  final bool isOn;
  final DateTime? lastUpdate;
  final Color baseColor;

  const _AccTimerBadge({required this.speed, required this.isStale, required this.isOn, required this.lastUpdate, required this.baseColor});

  @override
  _AccTimerBadgeState createState() => _AccTimerBadgeState();
}

class _AccTimerBadgeState extends State<_AccTimerBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    if (widget.isOn && !widget.isStale && widget.lastUpdate != null) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(_AccTimerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOn && !widget.isStale && widget.lastUpdate != null) {
      _startTimerIfNeeded();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMoving = !widget.isStale && widget.speed > 2;
    String timerText = "";
    if (!widget.isStale && widget.isOn && widget.lastUpdate != null && !isMoving) {
      final now = DateTime.now().toUtc();
      final d = now.difference(widget.lastUpdate!);
      timerText = " ${d.inMinutes} m ${d.inSeconds % 60}s";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: (isMoving ? Colors.green : widget.baseColor).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(
        isMoving ? "${widget.speed.toStringAsFixed(0)} ${'sharedKmh'.tr}" : (widget.isStale ? 'deviceStatusOfflineUpper'.tr : (widget.isOn ? "${'deviceStatusAccOn'.tr}$timerText" : 'alarmParking'.tr)),
        style: TextStyle(color: isMoving ? Colors.green : widget.baseColor, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

class _DeviceListSkeleton extends StatelessWidget {
  const _DeviceListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 100),
      children: List.generate(5, (_) => _skeletonCard(context)),
    );
  }

  Widget _skeletonCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                SkeletonBox(width: 44, height: 44, radius: 14),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [SkeletonBox(height: 16, width: 120), Spacer(), SkeletonBox(width: 20, height: 20, radius: 10)]),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12, width: 90),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SkeletonBox(height: 12, width: 220),
            const SizedBox(height: 8),
            const SkeletonBox(height: 10, width: 140),
          ],
        ),
      ),
    );
  }
}
