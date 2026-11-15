// lib/screens/register_screen.dart
// A screen that allows users to register a new account.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/feedback.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final usersApi = api.UsersApi(Provider.of<TraccarProvider>(context, listen: false).apiClient);

      final newUser = api.User(name: _nameController.text, email: _emailController.text, password: _passwordController.text);

      await usersApi.postUsers(newUser);

      if (mounted) {
        FeedbackService.success('registerSuccess'.tr, context: context);
        Navigator.of(context).pop();
      }
    } on api.ApiException catch (e) {
      if (mounted) {
        String errorMessage = 'API error: Status Code ${e.code}, Details: ${e.toString()}';
        FeedbackService.error(errorMessage, context: context);
      }
    } catch (e) {
      if (mounted) {
        FeedbackService.error('errorUnexpected'.trParams({'error': e.toString()}), context: context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(middle: Text('loginRegister'.tr)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'sharedName'.tr),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'userEmail'.tr),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'userPassword'.tr),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _register, child: Text('loginRegister'.tr)),
          ],
        ),
      ),
    );
  }
}
