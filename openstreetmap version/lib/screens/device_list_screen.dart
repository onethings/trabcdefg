// lib/screens/device_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/screens/livetracking_map_screen.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:trabcdefg/widgets/OfflineAddressService.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart'; //
import 'package:trabcdefg/l10n/timeago_my.dart'; // 新增 Myanmar TimeAgo

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedStatus = 0;
  bool _isCompactView = false; // 控制樣式切換的變數
  // final OfflineGeocoder _geocoder = OfflineGeocoder();

  // 演算法優化：快取地址減少重複計算
  final Map<String, String> _addressCache = {};
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadViewPreference(); // 初始化時讀取樣式設定
    _setupTimeagoLocales();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });

    // 定時器：每分鐘刷新一次，更新 TimeAgo 與離線狀態
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  // 讀取 Shared Preferences
  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCompactView = prefs.getBool('isCompactView') ?? false;
    });
  }

  // 儲存並切換樣式
  Future<void> _toggleViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCompactView = !_isCompactView;
      prefs.setBool('isCompactView', _isCompactView);
    });
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

  Widget _buildAddressWidget(num? lat, num? lon, {required bool isCompact}) {
    if (lat == null || lon == null) {
      return _addressText('sharedNoData'.tr, isCompact);
    }
    final cacheKey = "${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}";
    if (_addressCache.containsKey(cacheKey)) {
      return _addressText(_addressCache[cacheKey]!, isCompact);
    }
    return FutureBuilder<String>(
      future: _getAddressAsync(lat, lon, cacheKey),
      builder: (context, snapshot) => _addressText(snapshot.data ?? '...', isCompact),
    );
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

  Widget _addressText(String text, bool isCompact) {
    if (isCompact) {
      return Text(
        text,
        style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      return Row(
        children: [
          const Icon(Icons.location_on, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final traccarProvider = Provider.of<TraccarProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(115.0),
          child: Column(children: [_buildSearchBar(), _buildFilterAndToggle()]),
        ),
      ),
      body: _buildBody(traccarProvider),
    );
  }

  Widget _buildBody(TraccarProvider provider) {
    if (provider.isLoading && provider.devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now().toUtc();

    final filteredDevices = provider.devices.where((device) {
      final matchesQuery = (device.name ?? '').toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final position = provider.getPosition(device.id!);
      final DateTime? lastUpdate =
          position?.fixTime?.toUtc() ?? device.lastUpdate?.toUtc();

      // 10 分鐘離線演算法機制
      final bool isStale =
          lastUpdate == null || now.difference(lastUpdate).inMinutes >= 10;
      String effectiveStatus = isStale
          ? 'offline'
          : (device.status ?? 'unknown');

      final String? filterStatus = _getStatusText(_selectedStatus);
      return matchesQuery &&
          (_selectedStatus == 0 || filterStatus == effectiveStatus);
    }).toList();

    if (filteredDevices.isEmpty) return Center(child: Text('sharedNoData'.tr));

    return RefreshIndicator(
      onRefresh: () async => await provider.fetchInitialData(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filteredDevices.length,
        itemBuilder: (context, index) {
          final device = filteredDevices[index];
          final position = provider.getPosition(device.id!);

          // 根據切換狀態決定顯示哪種卡片
          return _isCompactView
              ? _buildCompactListItem(device, position)
              : _buildStandardCard(device, position);
        },
      ),
    );
  }

  // --- 樣式 A: 標準大卡片 ---
  Widget _buildStandardCard(api.Device device, api.Position? position) {
    final Map<String, dynamic> attributes =
        (position?.attributes as Map<String, dynamic>?) ?? {};
    final bool isIgnitionOn = attributes['ignition'] == true;
    final double speedKmH = (position?.speed ?? 0.0) * 1.852;
    final DateTime now = DateTime.now().toUtc();
    final DateTime? lastUpdate =
        position?.fixTime?.toUtc() ?? device.lastUpdate?.toUtc();
    final bool isStale =
        lastUpdate == null || now.difference(lastUpdate).inMinutes >= 10;

    Color statusColor = isStale
        ? Colors.blueGrey.shade300
        : (isIgnitionOn ? const Color(0xFF10B981) : Colors.amber.shade700);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () =>
            Get.to(() => LiveTrackingMapScreen(selectedDevice: device)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car, color: statusColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name ?? '...',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          lastUpdate != null
                              ? timeago.format(
                                  lastUpdate,
                                  locale:
                                      Get.locale?.languageCode ??
                                      'zh', // 改為讀取 GetX 當前語系
                                )
                              : '--',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AccTimerBadge(
                    speed: speedKmH,
                    isStale: isStale,
                    isOn: isIgnitionOn,
                    lastUpdate: lastUpdate,
                    baseColor: statusColor,
                    isCompact: false,
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildAddressWidget(position?.latitude, position?.longitude, isCompact: false),
            ],
          ),
        ),
      ),
    );
  }

  // --- 樣式 B: 緊湊列表 (一頁 9 台) ---
  Widget _buildCompactListItem(api.Device device, api.Position? position) {
    final Map<String, dynamic> attributes =
        (position?.attributes as Map<String, dynamic>?) ?? {};
    final bool isIgnitionOn = attributes['ignition'] == true;
    final double speedKmH = (position?.speed ?? 0.0) * 1.852;
    final DateTime now = DateTime.now().toUtc();
    final DateTime? lastUpdate =
        position?.fixTime?.toUtc() ?? device.lastUpdate?.toUtc();
    final bool isStale =
        lastUpdate == null || now.difference(lastUpdate).inMinutes >= 10;

    Color statusColor = isStale
        ? Colors.grey
        : (isIgnitionOn ? const Color(0xFF10B981) : Colors.orange);

    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () =>
            Get.to(() => LiveTrackingMapScreen(selectedDevice: device)),
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name ?? '...',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    lastUpdate != null
                        ? timeago.format(
                            lastUpdate,
                            locale:
                                Get.locale?.languageCode ??
                                'zh', // 改為讀取 GetX 當前語系
                          )
                        : '--',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: _buildAddressWidget(position?.latitude, position?.longitude, isCompact: true),
            ),
            _AccTimerBadge(
              speed: speedKmH,
              isStale: isStale,
              isOn: isIgnitionOn,
              lastUpdate: lastUpdate,
              baseColor: statusColor,
              isCompact: true,
            ),
          ],
        ),
      ),
    );
  }

  // --- 輔助 Widget: 標籤與按鈕 ---
  Widget _buildFilterAndToggle() {
    final labels = [
      'deviceStatusAll'.tr,
      'deviceStatusOnline'.tr,
      'deviceStatusOffline'.tr,
      'deviceStatusUnknown'.tr,
    ];
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: labels.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: _selectedStatus == i
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  selected: _selectedStatus == i,
                  onSelected: (_) => setState(() => _selectedStatus = i),
                  selectedColor: Colors.blueAccent,
                ),
              ),
            ),
          ),
        ),
        // 切換樣式按鈕
        IconButton(
          icon: Icon(
            _isCompactView
                ? Icons.view_agenda_outlined
                : Icons.view_headline_rounded,
            color: Colors.blueAccent,
          ),
          onPressed: _toggleViewMode,
          tooltip: "切換顯示樣式",
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'sharedSearchDevices'.tr,
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  String? _getStatusText(int index) =>
      [null, 'online', 'offline', 'unknown'][index];
}

// --- 獨立的 ACC 計時器 Widget，只有這個小區塊每秒更新 ---
class _AccTimerBadge extends StatefulWidget {
  final double speed;
  final bool isStale;
  final bool isOn;
  final DateTime? lastUpdate;
  final Color baseColor;
  final bool isCompact;

  const _AccTimerBadge({
    Key? key,
    required this.speed,
    required this.isStale,
    required this.isOn,
    required this.lastUpdate,
    required this.baseColor,
    required this.isCompact,
  }) : super(key: key);

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
    return widget.isCompact ? _buildCompact() : _buildStandard();
  }

  Widget _buildStandard() {
    bool isMoving = !widget.isStale && widget.speed > 2;
    String timerText = "";
    if (!widget.isStale && widget.isOn && widget.lastUpdate != null && !isMoving) {
      final now = DateTime.now().toUtc();
      final d = now.difference(widget.lastUpdate!);
      timerText = " ${d.inMinutes} m ${d.inSeconds % 60}s";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isMoving ? Colors.green : widget.baseColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isMoving
            ? "${widget.speed.toStringAsFixed(0)} km/h"
            : (widget.isStale ? "OFFLINE" : "ACC ON$timerText"),
        style: TextStyle(
          color: isMoving ? Colors.green : widget.baseColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildCompact() {
    if (widget.isStale) {
      return const Padding(
        padding: EdgeInsets.only(right: 8),
        child: Text(
          "OFFLINE",
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (widget.speed > 2) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          "${widget.speed.toStringAsFixed(0)} km/h",
          style: const TextStyle(
            fontSize: 10,
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    String timeStr = "";
    if (widget.isOn && widget.lastUpdate != null) {
      final now = DateTime.now().toUtc();
      final d = now.difference(widget.lastUpdate!);
      timeStr = "\n${d.inMinutes}m ${d.inSeconds % 60}s";
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        "ACC ON$timeStr",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          color: widget.baseColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
