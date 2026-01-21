import 'package:shared_preferences/shared_preferences.dart';

class LoginService {
  static const String _firstNameKey = 'user_first_name';
  static const String _lastNameKey = 'user_last_name';
  static const String _birthdateKey = 'user_birthdate';
  static const String _isLoginCompleteKey = 'is_login_complete';

  // Check if login is completed
  static Future<bool> isLoginComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoginCompleteKey) ?? false;
  }

  // Save login data
  static Future<void> saveLoginData({
    required String firstName,
    required String lastName,
    required String birthdate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_firstNameKey, firstName);
    await prefs.setString(_lastNameKey, lastName);
    await prefs.setString(_birthdateKey, birthdate);
    await prefs.setBool(_isLoginCompleteKey, true);
  }

  // Get saved login data
  static Future<Map<String, String?>> getLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'firstName': prefs.getString(_firstNameKey),
      'lastName': prefs.getString(_lastNameKey),
      'birthdate': prefs.getString(_birthdateKey),
    };
  }

  // Clear login data (for testing/logout)
  static Future<void> clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstNameKey);
    await prefs.remove(_lastNameKey);
    await prefs.remove(_birthdateKey);
    await prefs.remove(_isLoginCompleteKey);
  }
}
