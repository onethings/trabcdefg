// saved_commands_screen.dart
// A screen to display and manage saved commands in the TracDefg app.
import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/screens/settings/add_saved_command_screen.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class SavedCommandsScreen extends StatefulWidget {
  const SavedCommandsScreen({super.key});

  @override
  _SavedCommandsScreenState createState() => _SavedCommandsScreenState();
}

class _SavedCommandsScreenState extends State<SavedCommandsScreen> {
  late Future<List<api.Command>?> _commandsFuture;

  @override
  void initState() {
    super.initState();
    _fetchCommands();
  }

  void _fetchCommands() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    // Correct way to instantiate CommandsApi with the authenticated client
    final commandsApi = api.CommandsApi(traccarProvider.apiClient);
    setState(() {
      _commandsFuture = commandsApi.commandsGet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sharedSavedCommands'.tr),
      ),
      body: FutureBuilder<List<api.Command>?>(
        future: _commandsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: Text('sharedLoading'.tr));
          } else if (snapshot.hasError) {
            return Center(child: Text('errorGeneral'.tr + ': ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('sharedNoData'.tr));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final command = snapshot.data![index];
                final attributes = command.attributes;
                bool isSms = false;
                if (attributes != null && attributes is Map) {
                  isSms = (attributes as Map)['sendSms'] == true;
                }
                return ListTile(
                  title: Text(command.description ?? 'sharedNoDescription'.tr),
                  subtitle: Text(
                      '${'sharedType'.tr}: ${command.type ?? 'N/A'} | ${'sharedSendSms'.tr}: ${isSms ? 'sharedYes'.tr : 'sharedNo'.tr}'),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newCommand = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSavedCommandScreen(),
            ),
          );
          if (newCommand != null) {
            _fetchCommands();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}