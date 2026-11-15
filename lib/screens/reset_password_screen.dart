// lib/screens/reset_password_screen.dart
// A screen that allows users to reset their password by entering their email address.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/api_config.dart';
import 'package:trabcdefg/services/feedback.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final String email = _emailController.text;
    final apiConfig = ApiConfig.fromApiClient(
      context.read<TraccarProvider>().apiClient,
    );
    final Uri url = apiConfig.uri('/password/reset');

    final navigator = Navigator.of(context);

    try {
      final response = await http.post(url, headers: <String, String>{'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'}, body: 'email=${Uri.encodeComponent(email)}');

      if (response.statusCode == 200) {
        if (!mounted) return;
        FeedbackService.success('resetLinkSent'.tr, context: context);

        Future.delayed(const Duration(seconds: 2), () {
          // 這裡直接呼叫先前存好的 navigator，且此時畫面尚未 pop，安全度大幅提升
          // 若想絕對萬無一失，這裡依然可以加上 if (context.mounted)
          if (context.mounted) {
            navigator.pop();
          }
        });
      } else {
        String errorMessage = 'Failed to send reset link. Please try again.';
        if (response.statusCode == 404) {
          errorMessage = 'Email not found. Please check your email address.';
        }
        if (!mounted) return;
        FeedbackService.error(errorMessage, context: context);
      }
    } catch (e) {
      if (!mounted) return;
      FeedbackService.error('errorCheckConnection'.tr, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(middle: Text('loginReset'.tr)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'userEmail'.tr),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _resetPassword, child: Text('resetSendLink'.tr)),
          ],
        ),
      ),
    );
  }
}
