// add_computed_attribute_screen.dart
//  A screen to add a new computed attribute in the TracDefg app.
import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class AddComputedAttributeScreen extends StatefulWidget {
  const AddComputedAttributeScreen({super.key});

  @override
  _AddComputedAttributeScreenState createState() => _AddComputedAttributeScreenState();
}

class _AddComputedAttributeScreenState extends State<AddComputedAttributeScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _description;
  String? _attribute;
  String? _expression;
  String? _type = 'String'; // Default type

  void _saveAttribute() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final newAttribute = api.Attribute(
        description: _description!,
        attribute: _attribute!,
        expression: _expression!,
        type: _type!,
      );

      try {
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
        // Correct way to instantiate AttributesApi with the authenticated client
        final attributesApi = api.AttributesApi(traccarProvider.apiClient);
        await attributesApi.attributesComputedPost(newAttribute);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('sharedComputedAttribute'.tr + ' ' + 'sharedSaved'.tr)),
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
        title: Text('sharedAdd'.tr + ' ' + 'sharedComputedAttribute'.tr),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'sharedDescription'.tr),
                  onSaved: (value) {
                    _description = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'sharedAttribute'.tr + ' (' + 'sharedRequired'.tr + ')'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'sharedAttribute'.tr + ' ' + 'sharedRequired'.tr;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _attribute = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'sharedExpression'.tr + ' (' + 'sharedRequired'.tr + ')'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'sharedExpression'.tr + ' ' + 'sharedRequired'.tr;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _expression = value;
                  },
                ),
                const SizedBox(height: 20),
                Text('sharedType'.tr),
                DropdownButtonFormField<String>(
                  value: _type,
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
                      _type = newValue;
                    });
                  },
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
              onPressed: _saveAttribute,
              child: Text('sharedSave'.tr),
            ),
          ],
        ),
      ),
    );
  }
}