// computed_attributes_screen.dart
// A screen to display and manage computed attributes in the TracDefg app.
import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/screens/settings/add_computed_attribute_screen.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class ComputedAttributesScreen extends StatefulWidget {
  const ComputedAttributesScreen({super.key});

  @override
  _ComputedAttributesScreenState createState() => _ComputedAttributesScreenState();
}

class _ComputedAttributesScreenState extends State<ComputedAttributesScreen> {
  late Future<List<api.Attribute>?> _computedAttributesFuture;

  @override
  void initState() {
    super.initState();
    _fetchComputedAttributes();
  }

  void _fetchComputedAttributes() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    // Correct way to instantiate AttributesApi with the authenticated client
    final attributesApi = api.AttributesApi(traccarProvider.apiClient);
    setState(() {
      _computedAttributesFuture = attributesApi.attributesComputedGet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sharedComputedAttributes'.tr),
      ),
      body: FutureBuilder<List<api.Attribute>?>(
        future: _computedAttributesFuture,
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
                final attribute = snapshot.data![index];
                return ListTile(
                  title: Text(attribute.description ?? 'sharedNoDescription'.tr),
                  subtitle: Text(
                      '${'sharedAttribute'.tr}: ${attribute.attribute} | ${'sharedExpression'.tr}: ${attribute.expression} | ${'sharedType'.tr}: ${attribute.type}'),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newAttribute = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddComputedAttributeScreen(),
            ),
          );
          if (newAttribute != null) {
            _fetchComputedAttributes();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}