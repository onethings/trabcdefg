// add_driver_screen.dart

import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});

  @override
  _AddDriverScreenState createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _name;
  String? _uniqueId;
  final List<Map<String, dynamic>> _attributes = [];

  void _addAttribute() {
    setState(() {
      _attributes.add({'name': '', 'type': 'String', 'value': ''});
    });
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes.removeAt(index);
    });
  }

  void _saveDriver() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      Map<String, Object> attributesMap = {};
      for (var attr in _attributes) {
        Object value;
        switch (attr['type']) {
          case 'Number':
            value = double.tryParse(attr['value']) ?? 0.0;
            break;
          case 'Boolean':
            value = attr['value'] == 'true';
            break;
          default:
            value = attr['value'] as String;
            break;
        }
        attributesMap[attr['name']] = value;
      }

      final newDriver = api.Driver(
        name: _name!,
        uniqueId: _uniqueId!,
        attributes: attributesMap,
      );

      try {
        final traccarProvider = Provider.of<TraccarProvider>(
          context,
          listen: false,
        );
        final driversApi = api.DriversApi(traccarProvider.apiClient);
        await driversApi.driversPost(newDriver);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('sharedSaved'.tr)));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add driver: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sharedAdd'.tr + ' ' + 'sharedDriver'.tr)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText:
                        'sharedName'.tr + ' (' + 'sharedRequired'.tr + ')',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name.'.tr;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _name = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText:
                        'positionDriverUniqueId'.tr +
                        ' (' +
                        'sharedRequired'.tr +
                        ')',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an identifier.'.tr;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _uniqueId = value;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'sharedAttributes'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ..._attributes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final attribute = entry.value;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText:
                                        'sharedAttribute'.tr +
                                        ' ' +
                                        'sharedName'.tr,
                                  ),
                                  initialValue: attribute['name'],
                                  onSaved: (value) {
                                    attribute['name'] = value!;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              DropdownButton<String>(
                                value: attribute['type'],
                                onChanged: (String? newValue) {
                                  setState(() {
                                    attribute['type'] = newValue!;
                                  });
                                },
                                items: <String>['String', 'Number', 'Boolean']
                                    .map<DropdownMenuItem<String>>((
                                      String value,
                                    ) {
                                      String translatedValue;
                                      switch (value) {
                                        case 'String':
                                          translatedValue =
                                              'sharedTypeString'.tr;
                                          break;
                                        case 'Number':
                                          translatedValue =
                                              'sharedTypeNumber'.tr;
                                          break;
                                        case 'Boolean':
                                          translatedValue =
                                              'sharedTypeBoolean'.tr;
                                          break;
                                        default:
                                          translatedValue = value;
                                      }
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(translatedValue),
                                      );
                                    })
                                    .toList(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle),
                                onPressed: () => _removeAttribute(index),
                              ),
                            ],
                          ),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'stateValue'.tr,
                            ),
                            initialValue: attribute['value'],
                            onSaved: (value) {
                              attribute['value'] = value!;
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                ElevatedButton.icon(
                  onPressed: _addAttribute,
                  icon: const Icon(Icons.add),
                  label: Text('sharedAdd'.tr + ' ' + 'sharedAttribute'.tr),
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
              onPressed: _saveDriver,
              child: Text('sharedSave'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
