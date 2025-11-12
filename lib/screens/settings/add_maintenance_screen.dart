// add_maintenance_screen.dart
// A screen to add a new maintenance entry in the TracDefg app.
import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class AddMaintenanceScreen extends StatefulWidget {
  const AddMaintenanceScreen({super.key});

  @override
  _AddMaintenanceScreenState createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _name;
  String? _type;
  num? _start;
  num? _period;
  final Map<String, dynamic> _attributes = {};
  final TextEditingController _attributeNameController = TextEditingController();
  final TextEditingController _attributeValueController = TextEditingController();
  String _attributeType = 'String';

  void _addAttribute() {
    if (_attributeNameController.text.isNotEmpty && _attributeValueController.text.isNotEmpty) {
      setState(() {
        dynamic value;
        switch (_attributeType) {
          case 'Number':
            value = num.tryParse(_attributeValueController.text);
            break;
          case 'Boolean':
            value = _attributeValueController.text.toLowerCase() == 'true';
            break;
          default:
            value = _attributeValueController.text;
        }
        _attributes[_attributeNameController.text] = value;
        _attributeNameController.clear();
        _attributeValueController.clear();
      });
    }
  }

  void _saveMaintenance() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final newMaintenance = api.Maintenance(
        name: _name,
        type: _type,
        start: _start,
        period: _period,
        attributes: _attributes,
      );

      try {
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
        // Correct way to instantiate MaintenanceApi with the authenticated client
        final maintenanceApi = api.MaintenanceApi(traccarProvider.apiClient);
        await maintenanceApi.maintenancePost(newMaintenance);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('sharedMaintenance'.tr + ' ' + 'sharedSaved'.tr)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('errorGeneral'.tr + ': $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sharedAdd'.tr + ' ' + 'sharedMaintenance'.tr),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'sharedName'.tr + ' (' + 'sharedRequired'.tr + ')'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'sharedName'.tr + ' ' + 'sharedRequired'.tr;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _name = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'sharedType'.tr),
                  onSaved: (value) {
                    _type = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'maintenanceStart'.tr),
                  keyboardType: TextInputType.number,
                  onSaved: (value) {
                    _start = num.tryParse(value!);
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'maintenancePeriod'.tr),
                  keyboardType: TextInputType.number,
                  onSaved: (value) {
                    _period = num.tryParse(value!);
                  },
                ),
                const SizedBox(height: 20),
                Text('sharedAttributes'.tr),
                ..._attributes.entries.map((entry) {
                  return ListTile(
                    title: Text('${entry.key}: ${entry.value}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _attributes.remove(entry.key);
                        });
                      },
                    ),
                  );
                }),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _attributeNameController,
                        decoration: InputDecoration(labelText: 'sharedAttribute'.tr + ' ' + 'sharedName'.tr),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _attributeValueController,
                        decoration: InputDecoration(labelText: 'sharedAttribute'.tr + ' ' + 'stateValue'.tr),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _attributeType,
                      items: <String>['String', 'Number', 'Boolean'].map((String value) {
                        String translatedValue;
                        if (value == 'String') {
                          translatedValue = 'sharedTypeString'.tr;
                        } else if (value == 'Number') {
                          translatedValue = 'sharedTypeNumber'.tr;
                        } else {
                          translatedValue = 'sharedTypeBoolean'.tr;
                        }
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(translatedValue),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _attributeType = newValue!;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addAttribute,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('sharedCancel'.tr),
            ),
            ElevatedButton(
              onPressed: _saveMaintenance,
              child: Text('sharedSave'.tr),
            ),
          ],
        ),
      ),
    );
  }
}