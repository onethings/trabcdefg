import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/src/generated_api/api.dart';
import 'package:get/get.dart';

class AuthService {
  // FIX: Removed 'final' to allow the client to be updated
  ApiClient apiClient;

  AuthService({required this.apiClient});
  
  // FIX: Method to replace the entire ApiClient instance
  void updateApiClient(ApiClient newClient) {
    apiClient = newClient;
  }

  Future<void> login(String email, String password) async {
    try {
      final sessionApi = SessionApi(apiClient);
      
      final response = await sessionApi.sessionPostWithHttpInfo(email, password);
      
      final setCookieHeader = response.headers['set-cookie'];
      if (setCookieHeader == null) {
        throw Exception('Login failed: Session cookie not found.');
      }
      
      final jSessionId = setCookieHeader
          .split(';')
          .firstWhere((s) => s.startsWith('JSESSIONID='), orElse: () => '')
          .split('=')
          .last;
      
      if (jSessionId.isEmpty) {
        throw Exception('Login failed: Invalid session cookie.');
      }
      
      // Save the session ID for auto-login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jSessionId', jSessionId);
      await prefs.setString('userJson', response.body);
    } on ApiException catch (e) {
      if (e.code == 401) {
        throw Exception('Invalid email or password.');
      }
      throw Exception('Login failed: ${e.message}');
    }
  }

  Future<void> logout() async {
    // Clear the session ID from storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jSessionId');
  }
}