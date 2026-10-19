// lib/screens/device_list_screen.dart
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; //
import 'package:timeago/timeago.dart' as timeago;
import 'package:trabcdefg/l10n/timeago_my.dart'; // 新增 Myanmar TimeAgo
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/livetracking_map_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/widgets/offline_address_service.dart';

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
  bool _isLoadingMileage = false;
  // final OfflineGeocoder _geocoder = OfflineGeocoder();

  // 演算法優化：快取地址減少重複計算
  final Map<String, String> _addressCache = {};
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMileagePreference();
    _setupTimeagoLocales();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });

    // 定時器：每分鐘刷新一次，更新 TimeAgo 與離線狀態
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  // 讀取里程偏好
  Future<void> _loadMileagePreference() async {
    final prefs = await SharedPreferences.getInstance();
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
    setState(() {
      _showMileage = !_showMileage;
      prefs.setBool('showMileage', _showMileage);
      if (_showMileage) {
        _mileageMap.clear();
        _fetchMileageData();
      }
    });
  }

  // 設定里程天數 (1=今天, 3=最近3天)
  Future<void> _setMileageDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mileageDays = days;
      prefs.setInt('mileageDays', days);
      _mileageMap.clear();
      if (_showMileage) {
        _fetchMileageData();
      }
    });
  }

  // 取得今天 (或最近3天) 的里程
  Future<void> _fetchMileageData() async {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    if (traccarProvider.devices.isEmpty) return;

    setState(() => _isLoadingMileage = true);

    try {
      final reportsApi = api.ReportsApi(traccarProvider.apiClient);
      final deviceIds = traccarProvider.devices.map((d) => d.id!).toList();

      if (deviceIds.isEmpty) return;

      final now = DateTime.now().toUtc();
      final from = _mileageDays == 1 ? DateTime(now.year, now.month, now.day).toUtc() : DateTime(now.year, now.month, now.day - 2).toUtc();
      final to = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc();

      final summaries = await reportsApi.getReportsSummary(from, to, deviceId: deviceIds);

      if (summaries != null) {
        final newMap = <int, double>{};
        for (var s in summaries) {
          if (s.deviceId != null && s.distance != null) {
            newMap[s.deviceId!] = (s.distance! / 1000); // meters -> km
          }
        }
        if (mounted) {
          setState(() {
            _mileageMap.clear();
            _mileageMap.addAll(newMap);
            _isLoadingMileage = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMileage = false);
      }
    } catch (e) {
      debugPrint('Failed to fetch mileage: $e');
      if (mounted) setState(() => _isLoadingMileage = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setupTimeagoLocales() {
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    timeago.setLocaleMessages('az', timeago.AzMessages());
    timeago.setLocaleMessages('bn', timeago.BnMessages());
    timeago.setLocaleMessages('ca', timeago.CaMessages());
    timeago.setLocaleMessages('cs', timeago.CsMessages());
    timeago.setLocaleMessages('da', timeago.DaMessages());
    timeago.setLocaleMessages('de', timeago.DeMessages());
    timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
    timeago.setLocaleMessages('et', timeago.EtMessages());
    timeago.setLocaleMessages('fa', timeago.FaMessages());
    timeago.setLocaleMessages('fi', timeago.FiMessages());
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    timeago.setLocaleMessages('he', timeago.HeMessages());
    timeago.setLocaleMessages('hi', timeago.HiMessages());
    timeago.setLocaleMessages('hr', timeago.HrMessages());
    timeago.setLocaleMessages('hu', timeago.HuMessages());
    timeago.setLocaleMessages('id', timeago.IdMessages());
    timeago.setLocaleMessages('it', timeago.ItMessages());
    timeago.setLocaleMessages('ja', timeago.JaMessages());
    timeago.setLocaleMessages('km', timeago.KmMessages());
    timeago.setLocaleMessages('ko', timeago.KoMessages());
    timeago.setLocaleMessages('lv', timeago.LvMessages());
    timeago.setLocaleMessages('mn', timeago.MnMessages());
    timeago.setLocaleMessages('nl', timeago.NlMessages());
    timeago.setLocaleMessages('pl', timeago.PlMessages());
    timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
    timeago.setLocaleMessages('ro', timeago.RoMessages());
    timeago.setLocaleMessages('ru', timeago.RuMessages());
    timeago.setLocaleMessages('sr', timeago.SrMessages());
    timeago.setLocaleMessages('sv', timeago.SvMessages());
    timeago.setLocaleMessages('ta', timeago.TaMessages());
    timeago.setLocaleMessages('th', timeago.ThMessages());
    timeago.setLocaleMessages('tk', timeago.TkMessages());
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    timeago.setLocaleMessages('uk', timeago.UkMessages());
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    timeago.setLocaleMessages('zh', timeago.ZhMessages());
    timeago.setLocaleMessages('my', MyMessages()); // 關鍵修正：註冊 Myanmar 語系
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

  Widget _addressText(String text) => Text(
    text,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  @override
  Widget build(BuildContext context) {
    final traccarProvider = Provider.of<TraccarProvider>(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(),
            _buildFilterAndToggle(traccarProvider),
            Expanded(child: _buildBody(traccarProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TraccarProvider provider) {
    if (provider.isLoading && provider.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now().toUtc();

    final filteredDevices = provider.devices.where((device) {
      final matchesQuery = (device.name ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final position = provider.getPosition(device.id!);
      final effectiveStatus = _deviceStatus(device, position, now);

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
      return 0; // 保持原有順序（通常是 API 返回的順序）
    });

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchInitialData();
        if (_showMileage) {
          _mileageMap.clear();
          await _fetchMileageData();
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
        itemCount: filteredDevices.isEmpty ? 1 : filteredDevices.length,
        itemBuilder: (context, index) {
          if (filteredDevices.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 40, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('sharedNoData'.tr, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              ),
            );
          }
          final device = filteredDevices[index];
          final position = provider.getPosition(device.id!);
          return _buildDeviceCard(device, position, provider, now);
        },
      ),
    );
  }

  String _deviceStatus(api.Device device, api.Position? position, DateTime now) {
    final lastUpdate = position?.fixTime?.toUtc() ?? device.lastUpdate?.toUtc();
    if (lastUpdate == null || now.difference(lastUpdate).inMinutes >= 10) return 'offline';
    final status = device.status;
    return status == 'online' || status == 'offline' ? status! : 'unknown';
  }

  Widget _buildDeviceCard(api.Device device, api.Position? position, TraccarProvider provider, DateTime now) {
    final isFavorite = provider.isFavorite(device.id!);
    final theme = Theme.of(context);
    final status = _deviceStatus(device, position, now);
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
    final lastSeen = lastUpdate == null ? '--' : timeago.format(lastUpdate, locale: Get.locale?.languageCode ?? 'zh');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.to(() => LiveTrackingMapScreen(selectedDevice: device)),
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
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.only(left: 8),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                  Expanded(
                    child: Text(lastSeen, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, fontSize: 11)),
                  ),
                  if (_showMileage) _buildMileageWidget(device.id!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 里程顯示 Widget ---
  Widget _buildMileageWidget(int deviceId) {
    final mileage = _mileageMap[deviceId];
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
      final status = _deviceStatus(device, provider.getPosition(device.id!), now);
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

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
                  suffixIcon: _searchQuery.isEmpty ? null : IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.close_rounded, size: 18)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton(
              onPressed: _toggleMileage,
              tooltip: 'dashboardTodayDistance'.tr,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
          ],
        ),
      ),
    );
  }

  String? _getStatusText(int index) => [null, 'online', 'offline', 'unknown', 'favorite'][index];
}

// --- 獨立的 ACC 計時器 Widget，只有這個小區塊每秒更新 ---
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
