// saved_commands_screen.dart
// A screen to display and manage saved commands in the TracDefg app.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/settings/add_saved_command_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/widgets/state_views.dart';

class SavedCommandsScreen extends StatefulWidget {
  const SavedCommandsScreen({super.key});

  @override
  State<SavedCommandsScreen> createState() => _SavedCommandsScreenState();
}

class _SavedCommandsScreenState extends State<SavedCommandsScreen> {
  late Future<List<api.Command>?> _commandsFuture;

  @override
  void initState() {
    super.initState();
    _fetchCommands();
  }

  Future<void> _fetchCommands() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    // Correct way to instantiate CommandsApi with the authenticated client
    final commandsApi = api.CommandsApi(traccarProvider.apiClient);
    setState(() {
      _commandsFuture = commandsApi.getCommands();
    });
    return _commandsFuture.then((_) {}).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(middle: Text('sharedSavedCommands'.tr)),
      body: FutureBuilder<List<api.Command>?>(
        future: _commandsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: Text('sharedLoading'.tr));
          } else if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _fetchCommands,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 160),
                  ErrorState(message: 'errorUnexpected'.trParams({'error': snapshot.error.toString()}), retryLabel: 'sharedRetry'.tr, onRetry: _fetchCommands),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              onRefresh: _fetchCommands,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 160),
                  EmptyState(icon: CupertinoIcons.paperplane, title: 'sharedNoData'.tr, hint: 'sharedRefresh'.tr),
                ],
              ),
            );
          } else {
            return RefreshIndicator(
              onRefresh: _fetchCommands,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final command = snapshot.data![index];
                  final attributes = command.attributes;
                  bool isSms = false;
                  if (attributes != null && attributes is Map) {
                    isSms = attributes['sendSms'] == true;
                  }
                  return ListTile(title: Text(command.description ?? 'sharedNoDescription'.tr), subtitle: Text('${'sharedType'.tr}: ${command.type ?? 'N/A'} | ${'sharedSendSms'.tr}: ${isSms ? 'sharedYes'.tr : 'sharedNo'.tr}'));
                },
              ),
            );
          }
        },
      ),
      floatingActionButton: Padding(
        // 用 Padding 上移：Transform 只改變繪製位置，會讓可點擊區域與畫面位置錯開。
        padding: const EdgeInsets.only(bottom: 45),
        child: FloatingActionButton(
          onPressed: () async {
            final newCommand = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddSavedCommandScreen()));
            if (newCommand != null) {
              _fetchCommands();
            }
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
    );
  }
}
