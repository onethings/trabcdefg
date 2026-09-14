import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/command_screen.dart';
import 'package:trabcdefg/screens/device_details_screen.dart';
import 'package:trabcdefg/screens/monthly_mileage_screen.dart';
import 'package:trabcdefg/screens/settings/add_device_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class DeviceDetailPanel extends StatefulWidget {
  final api.Device device;
  final api.Position position;
  final String address;
  final String formattedDate;
  final VoidCallback onMoreOptionsPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onRefresh;

  const DeviceDetailPanel({super.key, required this.device, required this.position, required this.address, required this.formattedDate, required this.onMoreOptionsPressed, required this.onDeletePressed, required this.onRefresh});

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  height: 4,
                  width: 36,
                  decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),

                // Header (Name, Info, Status Tags)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.device.name ?? 'Unknown Device'.tr,
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

                const SizedBox(height: 12),

                // Status Grid：資料驅動 —— 有資料的項目才顯示（一列 3 個，
                // 超過自動換列），沒資料的直接隱藏，維持面板簡潔。
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: _buildStatusRows(context)),
                  ),
                ),

                const SizedBox(height: 12),

                // Address Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.location_solid, size: 14, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.address,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons (Conditionally Visible)
                if (_isExpanded) ...[const SizedBox(height: 16), _buildAppleActionButtons(context)],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(height: 24, width: 0.5, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1));
  }

  /// 一列放 3 個項目，超過就換列（列內沿用原本的細分隔線語彙）。
  List<Widget> _buildStatusRows(BuildContext context) {
    final items = _buildStatusItems(context);
    final children = <Widget>[];

    for (var i = 0; i < items.length; i += 3) {
      if (i > 0) children.add(const SizedBox(height: 12));
      final rowItems = items.skip(i).take(3).toList();
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
  List<Widget> _buildStatusItems(BuildContext context) {
    final items = <Widget>[];

    // 1) 車速：直接採用回傳值（單位依伺服器設定，不在此換算）
    final speed = widget.position.speed;
    items.add(_buildStatusItem(context, Icons.speed_rounded, '${speed?.toStringAsFixed(0) ?? 0} ${'sharedKmh'.tr}', 'positionSpeed'.tr));

    // 2) 電量
    final battery = _getAttribute(widget.position, 'batteryLevel');
    if (battery is num) {
      items.add(_buildStatusItem(context, CupertinoIcons.battery_charging, '${battery.toStringAsFixed(0)}%', 'positionBattery'.tr));
    }

    // 3) 點火狀態
    final ignition = _getAttribute(widget.position, 'ignition');
    if (ignition is bool) {
      items.add(_buildStatusItem(context, CupertinoIcons.power, ignition ? 'sharedOn'.tr : 'sharedOff'.tr, 'positionIgnition'.tr));
    }

    // 4) 當日里程（今日 summary.distance，單位公尺）
    final todayDistance = _dailySummary?.distance;
    if (todayDistance != null && todayDistance > 0) {
      items.add(_buildStatusItem(context, Icons.route_rounded, '${(todayDistance / 1000).toStringAsFixed(1)} ${'sharedKm'.tr}', 'dashboardTotalDistance'.tr));
    }

    // 5) 當日點火時數（summary.engineHours 單位是毫秒）
    final engineHours = _dailySummary?.engineHours;
    if (engineHours != null && engineHours > 0) {
      items.add(_buildStatusItem(context, CupertinoIcons.timer, _formatEngineHours(engineHours), 'reportEngineHours'.tr));
    }

    // 6) 總里程（優先 odometer，部分裝置只回報 totalDistance）
    final odometer = _getAttribute(widget.position, 'odometer') ?? _getAttribute(widget.position, 'totalDistance');
    if (odometer is num && odometer > 0) {
      items.add(_buildStatusItem(context, CupertinoIcons.gauge, '${(odometer / 1000).toStringAsFixed(0)} ${'sharedKm'.tr}', 'deviceTotalDistance'.tr));
    }

    // 7) 海拔（公尺；0 或 null 視為沒資料）
    final altitude = widget.position.altitude;
    if (altitude is num && altitude != 0) {
      items.add(_buildStatusItem(context, Icons.terrain_rounded, '${altitude.toStringAsFixed(0)} ${'sharedMeters'.tr}', 'positionAltitude'.tr));
    }

    // 8) 油量（油箱剩餘油位，公升）
    final fuel = _getAttribute(widget.position, 'fuel') ?? _getAttribute(widget.position, 'fuelLevel');
    if (fuel is num && fuel > 0) {
      items.add(_buildStatusItem(context, Icons.local_gas_station_rounded, '${fuel.toStringAsFixed(1)} ${'sharedLiter'.tr}', 'dashboardFuelLevel'.tr));
    }

    // 9) 當日油耗（今日 summary.spentFuel，公升）——跟「油量」是兩件事，
    //    有資料就兩個都顯示：油箱還剩多少 vs 今天用掉多少。
    final spentFuel = _dailySummary?.spentFuel;
    if (spentFuel != null && spentFuel > 0) {
      items.add(_buildStatusItem(context, CupertinoIcons.drop, '${spentFuel.toStringAsFixed(1)} ${'sharedLiter'.tr}', 'dashboardSpentFuel'.tr));
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

  Widget _buildStatusItem(BuildContext context, IconData icon, String value, String label) {
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildHeaderActionIcons(BuildContext context) {
    return Row(
      children: [
        _buildCircleIcon(context, Icons.route_rounded, () => _navigateToMileage(context)),
        const SizedBox(width: 8),
        _buildCircleIcon(context, CupertinoIcons.refresh, widget.onRefresh),
        const SizedBox(width: 8),
        Consumer<TraccarProvider>(
          builder: (context, provider, child) {
            final isFavorite = provider.isFavorite(widget.device.id!);
            return _buildCircleIcon(context, isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart, () => provider.toggleFavorite(widget.device.id!), color: isFavorite ? Colors.red : null);
          },
        ),
        const SizedBox(width: 8),
        _buildCircleIcon(context, _isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down, _toggleExpanded),
      ],
    );
  }

  Widget _buildCircleIcon(BuildContext context, IconData icon, VoidCallback onTap, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color ?? Theme.of(context).colorScheme.onSurface),
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
          _buildActionItem(context, CupertinoIcons.location_north, () => _navigateToGoogleMaps()),
          _buildActionItem(context, CupertinoIcons.info_circle, () => _navigateToDetails(context)),
          _buildActionItem(context, CupertinoIcons.paperplane, () => _navigateToCommand(context)),
          _buildActionItem(context, CupertinoIcons.ellipsis, widget.onMoreOptionsPressed),
          _buildActionItem(context, CupertinoIcons.pencil, () => _navigateToEdit(context)),
          _buildActionItem(context, CupertinoIcons.trash, widget.onDeletePressed, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, VoidCallback onTap, {Color? color}) {
    return IconButton(
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
      _showMapMessage('No GPS Signal'.tr);
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

    _showMapMessage('Could not open maps'.tr);
  }

  void _showMapMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  dynamic _getAttribute(api.Position pos, String key) {
    return (pos.attributes as Map<String, dynamic>?)?[key];
  }
}
