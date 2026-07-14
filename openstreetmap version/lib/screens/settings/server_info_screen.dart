// server_info_screen.dart
// Displays Traccar server information and version.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class ServerInfoScreen extends StatefulWidget {
  const ServerInfoScreen({super.key});

  @override
  State<ServerInfoScreen> createState() => _ServerInfoScreenState();
}

class _ServerInfoScreenState extends State<ServerInfoScreen> {
  api.Server? _server;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchServerInfo();
  }

  Future<void> _fetchServerInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
      final serverApi = api.ServerApi(traccarProvider.apiClient);
      final server = await serverApi.getServer();
      if (mounted) {
        setState(() {
          _server = server;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch server info: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sharedInfoTitle'.tr)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('${'errorGeneral'.tr}: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: _fetchServerInfo, icon: const Icon(Icons.refresh), label: Text('sharedRetry'.tr)),
            ],
          ),
        ),
      );
    }

    if (_server == null) {
      return Center(child: Text('sharedNoData'.tr));
    }

    final server = _server!;
    final attributes = server.attributes as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _fetchServerInfo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(''),
          _buildInfoTile(Icons.cloud, 'ServerUrl'.tr, Provider.of<TraccarProvider>(context, listen: false).apiClient.basePath),
          _buildInfoTile(Icons.tag, 'settingsServerVersion'.tr, server.version ?? 'N/A'),
          _buildInfoTile(Icons.map, 'Map', server.map ?? 'N/A'),
          _buildInfoTile(Icons.link, 'Bing Key', server.bingKey?.isNotEmpty == true ? '••••${server.bingKey!.substring(server.bingKey!.length - 4)}' : 'N/A'),
          _buildInfoTile(Icons.layers, 'Map URL', server.mapUrl ?? 'N/A'),

          const Divider(height: 32),
          _buildSectionHeader('serverTitle'.tr),

          _buildInfoTile(Icons.person_add, 'serverRegistration'.tr, server.registration == true ? 'sharedYes'.tr : 'sharedNo'.tr, valueColor: server.registration == true ? Colors.green : null),
          _buildInfoTile(Icons.lock, 'serverReadonly'.tr, server.readonly == true ? 'sharedYes'.tr : 'sharedNo'.tr, valueColor: server.readonly == true ? Colors.orange : null),
          _buildInfoTile(Icons.devices_other, 'Device Readonly', server.deviceReadonly == true ? 'sharedYes'.tr : 'sharedNo'.tr, valueColor: server.deviceReadonly == true ? Colors.orange : null),
          _buildInfoTile(Icons.terminal, 'Limit Commands', server.limitCommands == true ? 'sharedYes'.tr : 'sharedNo'.tr, valueColor: server.limitCommands == true ? Colors.orange : null),

          const Divider(height: 32),
          _buildSectionHeader('sharedLocation'.tr),

          _buildInfoTile(Icons.public, 'positionLatitude'.tr, server.latitude?.toStringAsFixed(6) ?? 'N/A'),
          _buildInfoTile(Icons.public, 'positionLongitude'.tr, server.longitude?.toStringAsFixed(6) ?? 'N/A'),
          _buildInfoTile(Icons.zoom_in, 'serverZoom'.tr, server.zoom?.toString() ?? 'N/A'),

          if (attributes.isNotEmpty) ...[const Divider(height: 32), _buildSectionHeader('sharedExtra'.tr), ...attributes.entries.map((entry) => _buildInfoTile(Icons.info_outline, entry.key.toString(), entry.value.toString()))],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.tr,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, {Color? valueColor}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor ?? Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}
