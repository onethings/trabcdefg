
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/command_screen.dart';
import 'package:trabcdefg/screens/device_details_screen.dart';
import 'package:trabcdefg/screens/history_route_screen.dart';
import 'package:trabcdefg/screens/monthly_mileage_screen.dart';
import 'package:trabcdefg/screens/settings/add_device_screen.dart';
import 'package:trabcdefg/services/feedback.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/glass_settings.dart';
import 'package:trabcdefg/widgets/simple_mode.dart';

/// 面板導覽要照亮的區塊。由呼叫端建立並傳入，面板本身不認識導覽。
class DevicePanelHelperKeys {
  final GlobalKey header = GlobalKey();
  final GlobalKey status = GlobalKey();
  final GlobalKey address = GlobalKey();
}

class DeviceDetailPanel extends StatefulWidget {
  final api.Device device;
  final api.Position position;
  final String address;
  final String formattedDate;
  final VoidCallback onMoreOptionsPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onRefresh;

  /// 有給才掛座標；其他呼叫端不必理會。
  final DevicePanelHelperKeys? helperKeys;

  const DeviceDetailPanel({super.key, required this.device, required this.position, required this.address, required this.formattedDate, required this.onMoreOptionsPressed, required this.onDeletePressed, required this.onRefresh, this.helperKeys});

  @override
  State<DeviceDetailPanel> createState() => _DeviceDetailPanelState();
}

class _DeviceDetailPanelState extends State<DeviceDetailPanel> {
  bool _isExpanded = false;
  bool _isLoadingPreference = true;

  /// 今日統計（當日里程 / 當日點火時數），來自 Reports Summary。
  /// 抓不到就保持 null → 對應欄位自動隱藏。
  api.ReportSummary? _dailySummary;

  @override
  void initState() {
    super.initState();
    _loadPreference();
    _loadDailySummary();
  }

  @override
  void didUpdateWidget(DeviceDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切換裝置時要重新抓當日統計，否則會顯示上一台的數字
    if (oldWidget.device.id != widget.device.id) {
      _dailySummary = null;
      _loadDailySummary();
    }
  }

  /// 抓「今天」的統計摘要（當日里程、引擎時數）。
  /// 為什麼要另開 API？因為 Position 只有瞬時資料，
  /// 當日累計里程/點火時數只有 Reports 才拿得到。
  Future<void> _loadDailySummary() async {
    final deviceId = widget.device.id;
    if (deviceId == null) return;

    try {
      final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day).toUtc();
      final summaries = await api.ReportsApi(traccarProvider.apiClient).getReportsSummary(from, now.toUtc(), deviceId: [deviceId]);
      if (!mounted) return;
      setState(() {
        _dailySummary = (summaries != null && summaries.isNotEmpty) ? summaries.first : null;
      });
    } catch (e) {
      debugPrint('Failed to load daily summary: $e');
      if (mounted) setState(() => _dailySummary = null);
    }
  }

  Future<void> _loadPreference() async {
    try {
      final box = await Hive.openBox('user_preferences');
      if (mounted) {
        setState(() {
          _isExpanded = box.get('detail_panel_expanded', defaultValue: false);
          _isLoadingPreference = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load preference: $e');
      if (mounted) {
        setState(() => _isLoadingPreference = false);
      }
    }
  }

  Future<void> _toggleExpanded() async {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    try {
      final box = await Hive.openBox('user_preferences');
      await box.put('detail_panel_expanded', _isExpanded);
    } catch (e) {
      debugPrint('Failed to save preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPreference) {
      return const SizedBox.shrink(); // Prevent visual jumping before preference loads
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool simpleMode = isSimpleMode(context);
    // 簡易模式字級是 1.4 倍：左右內距收窄、區塊間距與容器內距縮小，盡量把空間留給內容。
    final double sidePadding = simpleMode ? 12 : 16;
    final double sectionGap = simpleMode ? 8 : 12;
    final double containerPadding = simpleMode ? 10 : 12;
    // 內容超過 55% 畫面高度就改為滾動，字放大後不會被裁掉。
    final double maxBodyHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
      child: GlassContainer(
        shape: const LiquidRoundedSuperellipse(borderRadius: 24),
        quality: GlassQuality.standard,
        platformViewBackdrop: true,
        settings: mapGlassSettings(context),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxBodyHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar：簡易模式不需要（面板不可拖曳），省下空白。
                if (!simpleMode) ...[
                  Container(
                    height: 4,
                    width: 36,
                    decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Header (Name, Info, Status Tags)
                _maybeKeyed(
                  widget.helperKeys?.header,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.device.name ?? 'deviceUnknown'.tr,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: Theme.of(context).colorScheme.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(widget.formattedDate, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        _buildHeaderActionIcons(context),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: sectionGap),

                // Status Grid：資料驅動 —— 有資料的項目才顯示，沒資料的直接隱藏。
                // 一律每列 3 項把格子填滿；簡易模式字大，數值與標籤允許 2 行不截字。
                _maybeKeyed(
                  widget.helperKeys?.status,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    child: Container(
                      padding: EdgeInsets.all(containerPadding),
                      decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: _buildStatusRows(context, columns: 3, maxLines: simpleMode ? 2 : 1)),
                    ),
                  ),
                ),

                SizedBox(height: sectionGap),

                // Address Row
                _maybeKeyed(
                  widget.helperKeys?.address,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.location_solid, size: 14, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.address,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            maxLines: simpleMode ? 3 : null,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons (Conditionally Visible)
                // 簡易模式整條動作列不渲染，刪除設備按鈕因此看不到也按不到。
                if (_isExpanded)
                  AdvancedOnly(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildAppleActionButtons(context),
                    ),
                  ),
                // 簡易模式只留兩顆大按鍵：左邊導覽、右邊軌跡回放；其餘動作列藏起來。
                if (simpleMode) ...[
                  SizedBox(height: sectionGap),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    child: _buildSimpleActionButtons(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 導覽座標由呼叫端決定要不要掛；沒給就原樣回傳，面板不多長一層。
  Widget _maybeKeyed(Key? key, Widget child) => key == null ? child : KeyedSubtree(key: key, child: child);

  Widget _buildStatusDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(height: 24, width: 0.5, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1));
  }

  /// 每列 [columns] 個項目，超過就換列（列內沿用原本的細分隔線語彙）。
  /// [maxLines] 控制數值與標籤最多幾行：簡易模式字大，給到 2 行才不會被截掉。
  List<Widget> _buildStatusRows(BuildContext context, {required int columns, required int maxLines}) {
    final items = _buildStatusItems(context, maxLines: maxLines);
    final children = <Widget>[];

    for (var i = 0; i < items.length; i += columns) {
      if (i > 0) children.add(const SizedBox(height: 12));
      final rowItems = items.skip(i).take(columns).toList();
      children.add(
        Row(
          children: [
            for (var j = 0; j < rowItems.length; j++) ...[if (j > 0) _buildStatusDivider(context), Expanded(child: rowItems[j])],
          ],
        ),
      );
    }

    return children;
  }

  /// 狀態項目清單：只有「真的有資料」的才產生 widget。
  /// 規則：null 或 0 一律視為沒資料（GPS 沒回報時就是 0，顯示 0 沒有意義）。
  List<Widget> _buildStatusItems(BuildContext context, {required int maxLines}) {
    final items = <Widget>[];

    // 1) 車速：直接採用回傳值（單位依伺服器設定，不在此換算）
    final speed = widget.position.speed;
    items.add(_buildStatusItem(context, Icons.speed_rounded, '${speed?.toStringAsFixed(0) ?? 0} ${'sharedKmh'.tr}', 'positionSpeed'.tr, maxLines: maxLines));

    // 2) 電量
    final battery = _getAttribute(widget.position, 'batteryLevel');
    if (battery is num) {
      items.add(_buildStatusItem(context, CupertinoIcons.battery_charging, '${battery.toStringAsFixed(0)}%', 'positionBattery'.tr, maxLines: maxLines));
    }

    // 3) 點火狀態
    final ignition = _getAttribute(widget.position, 'ignition');
    if (ignition is bool) {
      items.add(_buildStatusItem(context, CupertinoIcons.power, ignition ? 'sharedOn'.tr : 'sharedOff'.tr, 'positionIgnition'.tr, maxLines: maxLines));
    }

    // 4) 當日里程（今日 summary.distance，單位公尺）
    final todayDistance = _dailySummary?.distance;
    if (todayDistance != null && todayDistance > 0) {
      items.add(_buildStatusItem(context, Icons.route_rounded, '${(todayDistance / 1000).toInt()} ${'sharedKm'.tr}', 'dashboardTodayDistance'.tr, maxLines: maxLines));
    }
    
    // 5) 當日點火時數（summary.engineHours 單位是毫秒）
    final engineHours = _dailySummary?.engineHours;
    if (engineHours != null && engineHours > 0) {
      items.add(_buildStatusItem(context, CupertinoIcons.timer, _formatEngineHours(engineHours), 'reportEngineHours'.tr, maxLines: maxLines));
    }

    // 6) 總里程（優先 odometer，部分裝置只回報 totalDistance）
    final odometer = _getAttribute(widget.position, 'odometer') ?? _getAttribute(widget.position, 'totalDistance');
    if (odometer is num && odometer > 0) {
      items.add(_buildStatusItem(context, CupertinoIcons.gauge, '${(odometer / 1000).toStringAsFixed(0)} ${'sharedKm'.tr}', 'deviceTotalDistance'.tr, maxLines: maxLines));
    }

    // 7) 海拔（公尺；0 或 null 視為沒資料）
    final altitude = widget.position.altitude;
    if (altitude is num && altitude != 0) {
      items.add(_buildStatusItem(context, Icons.terrain_rounded, '${altitude.toStringAsFixed(0)} ${'sharedMeters'.tr}', 'positionAltitude'.tr, maxLines: maxLines));
    }

    // 8) 油量（油箱剩餘油位，公升）
    final fuel = _getAttribute(widget.position, 'fuel') ?? _getAttribute(widget.position, 'fuelLevel');
    if (fuel is num && fuel > 0) {
      items.add(_buildStatusItem(context, Icons.local_gas_station_rounded, '${fuel.toStringAsFixed(1)} ${'sharedLiter'.tr}', 'dashboardFuelLevel'.tr, maxLines: maxLines));
    }

    // 9) 當日油耗（今日 summary.spentFuel，公升）——跟「油量」是兩件事，
    //    有資料就兩個都顯示：油箱還剩多少 vs 今天用掉多少。
    final spentFuel = _dailySummary?.spentFuel;
    if (spentFuel != null && spentFuel > 0) {
      items.add(_buildStatusItem(context, CupertinoIcons.drop, '${spentFuel.toStringAsFixed(1)} ${'sharedLiter'.tr}', 'dashboardSpentFuel'.tr, maxLines: maxLines));
    }

    return items;
  }

  /// 引擎時數：summary 回傳毫秒；不滿 1 小時就用分鐘顯示，讀起來更直覺。
  String _formatEngineHours(num milliseconds) {
    if (milliseconds < 3600000) {
      return '${(milliseconds / 60000).toStringAsFixed(0)} ${'sharedMinute'.tr}';
    }
    return '${(milliseconds / 3600000).toStringAsFixed(1)} ${'sharedHour'.tr}';
  }

  Widget _buildStatusItem(BuildContext context, IconData icon, String value, String label, {required int maxLines}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            // Flexible + ellipsis：避免長數字（例：12450 公里）撐破排版
            Flexible(
              child: Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildHeaderActionIcons(BuildContext context) {
    // 簡易模式只留重新整理；里程報表、我的最愛、展開動作列屬進階。
    if (isSimpleMode(context)) {
      return Row(
        children: [_buildCircleIcon(context, CupertinoIcons.refresh, widget.onRefresh, semanticsLabel: 'sharedRefresh'.tr)],
      );
    }
    return Row(
      children: [
        _buildCircleIcon(context, Icons.route_rounded, () => _navigateToMileage(context), semanticsLabel: 'monthlyMileageTitle'.tr),
        const SizedBox(width: 8),
        _buildCircleIcon(context, CupertinoIcons.refresh, widget.onRefresh, semanticsLabel: 'sharedRefresh'.tr),
        const SizedBox(width: 8),
        Consumer<TraccarProvider>(
          builder: (context, provider, child) {
            final isFavorite = provider.isFavorite(widget.device.id!);
            return _buildCircleIcon(context, isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart, () => provider.toggleFavorite(widget.device.id!), color: isFavorite ? Colors.red : null, semanticsLabel: 'sharedFavorite'.tr);
          },
        ),
        const SizedBox(width: 8),
        _buildCircleIcon(context, _isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down, _toggleExpanded, semanticsLabel: 'sharedMore'.tr),
      ],
    );
  }

  Widget _buildSimpleActionButtons(BuildContext context) {
    // 標文字用 FittedBox(scaleDown)：兩顆按鍵平分寬度、字級 1.4 倍，
    // 長語系（Navigate 等）也不會斷字換行，只會等比縮小到剛好放得下。
    Widget label(String key) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(key.tr, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    );

    final ButtonStyle style = ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _navigateToGoogleMaps,
            icon: const Icon(CupertinoIcons.location_north, size: 20),
            label: label('actionNavigate'),
            style: style,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _navigateToHistoryRoute(context),
            icon: const Icon(CupertinoIcons.play_circle_fill, size: 20),
            label: label('reportReplay'),
            style: style,
          ),
        ),
      ],
    );
  }

  /// 開啟今天時段的軌跡回放。HistoryRouteScreen 從 prefs 讀裝置與時間範圍。
  Future<void> _navigateToHistoryRoute(BuildContext context) async {
    final deviceId = widget.device.id;
    if (deviceId == null) return;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', deviceId);
    await prefs.setString('selectedDeviceName', widget.device.name ?? '');
    await prefs.setString('historyFrom', from.toUtc().toIso8601String());
    await prefs.setString('historyTo', to.toUtc().toIso8601String());

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => const HistoryRouteScreen()));
  }

  Widget _buildCircleIcon(BuildContext context, IconData icon, VoidCallback onTap, {Color? color, String? semanticsLabel}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The 44x44 box is the touch target; the visible circle stays 34pt.
    return Semantics(
      button: true,
      label: semanticsLabel ?? '',
      child: SizedBox(
        width: 44,
        height: 44,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: color ?? Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', widget.device.id!);
    await prefs.setString('selectedDeviceName', widget.device.name!);
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const DeviceDetailsScreen()));
    }
  }

  Widget _buildAppleActionButtons(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionItem(context, CupertinoIcons.location_north, () => _navigateToGoogleMaps(), tooltip: 'actionNavigate'.tr),
          _buildActionItem(context, CupertinoIcons.info_circle, () => _navigateToDetails(context), tooltip: 'sharedInfo'.tr),
          _buildActionItem(context, CupertinoIcons.paperplane, () => _navigateToCommand(context), tooltip: 'commandTitle'.tr),
          _buildActionItem(context, CupertinoIcons.ellipsis, widget.onMoreOptionsPressed, tooltip: 'sharedMore'.tr),
          _buildActionItem(context, CupertinoIcons.pencil, () => _navigateToEdit(context), tooltip: 'sharedEdit'.tr),
          _buildActionItem(context, CupertinoIcons.trash, widget.onDeletePressed, color: Colors.red, tooltip: 'sharedDelete'.tr),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, VoidCallback onTap, {Color? color, String? tooltip}) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 22, color: color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
      onPressed: onTap,
    );
  }

  void _navigateToMileage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', widget.device.id!);
    await prefs.setString('selectedDeviceName', widget.device.name!);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => const MonthlyMileageScreen()));
    }
  }

  void _navigateToCommand(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CommandScreen()));
  }

  void _navigateToEdit(BuildContext context) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddDeviceScreen(device: widget.device)));
    if (result != null) widget.onRefresh();
  }

  Future<void> _navigateToGoogleMaps() async {
    final lat = widget.position.latitude?.toDouble();
    final lng = widget.position.longitude?.toDouble();

    // No valid GPS fix yet -> tell the user instead of silently doing nothing.
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      _showMapMessage('deviceNoGps'.tr);
      return;
    }

    final latStr = lat.toStringAsFixed(6);
    final lngStr = lng.toStringAsFixed(6);

    // Android -> Google Maps, iOS -> Apple Maps (draw route to the position).
    final uris = <Uri>[];
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      uris.addAll([Uri.parse('maps:?daddr=$latStr,$lngStr'), Uri.parse('http://maps.apple.com/?daddr=$latStr,$lngStr')]);
    } else {
      uris.addAll([
        Uri.parse('google.navigation:q=$latStr,$lngStr&mode=d'),
        Uri.parse('geo:0,0?q=$latStr,$lngStr'),
        Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '$latStr,$lngStr', 'travelmode': 'driving'}),
      ]);
    }

    for (final uri in uris) {
      try {
        // Don't gate on canLaunchUrl: it can return false on Android 11+ when
        // the scheme isn't declared in <queries>, even though launchUrl works.
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (e) {
        debugPrint('Could not launch $uri: $e');
      }
    }

    _showMapMessage('deviceOpenMapsFailed'.tr);
  }

  void _showMapMessage(String message) {
    if (!mounted) return;
    FeedbackService.info(message, context: context);
  }

  dynamic _getAttribute(api.Position pos, String key) {
    return (pos.attributes as Map<String, dynamic>?)?[key];
  }
}
