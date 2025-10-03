// add_group_screen.dart

import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class AddGroupScreen extends StatefulWidget {
  const AddGroupScreen({super.key});

  @override
  _AddGroupScreenState createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _groupName;
  String? _groupExtra;
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

  void _saveGroup() async {
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

      final newGroup = api.Group(name: _groupName!, attributes: attributesMap);

      try {
        final traccarProvider = Provider.of<TraccarProvider>(
          context,
          listen: false,
        );
        // Correct way to instantiate GroupsApi with the authenticated client
        final groupsApi = api.GroupsApi(traccarProvider.apiClient);
        await groupsApi.groupsPost(newGroup);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('sharedSaved'.tr)));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add group: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sharedAdd'.tr + ' ' + 'groupDialog'.tr)),
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
                      return 'Please enter a group name.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _groupName = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'sharedExtra'.tr),
                  onSaved: (value) {
                    _groupExtra = value;
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
      floatingActionButton: FloatingActionButton(
        onPressed: _saveGroup,
        child: const Icon(Icons.save),
      ),
    );
  }
}
