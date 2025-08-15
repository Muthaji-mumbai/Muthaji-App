import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';
import '../constants/app_constants.dart';

class AuthService {
  static const String _userKey = 'user';
  static const String _tokenKey = 'token';

  static User? _currentUser;
  static String? _currentToken;

  static User? get currentUser => _currentUser;
  static String? get currentToken => _currentToken;
  static bool get isLoggedIn => _currentUser != null;

  // Login method using real API
  static Future<bool> login(String email, String password) async {
    try {
      final response = await ApiService.post(
        AppConstants.loginEndpoint,
        body: {'email': email, 'password': password},
      );

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];

        // Create user from API response
        _currentUser = User.fromJson(userData);
        _currentToken = userData['token'];

        // Save to local storage
        await _saveUserToStorage();
        return true;
      } else {
        throw Exception(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Logout method
  static Future<void> logout() async {
    _currentUser = null;
    _currentToken = null;

    // Clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
  }

  // Check if user is logged in on app start
  static Future<bool> checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      final token = prefs.getString(_tokenKey);

      if (userJson != null && token != null) {
        final userData = json.decode(userJson);
        _currentUser = User.fromJson(userData);
        _currentToken = token;
        return true;
      }
    } catch (e) {
      print('Error checking auth status: $e');
    }
    return false;
  }

  // Save user to local storage
  static Future<void> _saveUserToStorage() async {
    if (_currentUser != null && _currentToken != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json.encode(_currentUser!.toJson()));
      await prefs.setString(_tokenKey, _currentToken!);
    }
  }

  // Check if current user has specific role
  static bool hasRole(UserRole role) {
    return _currentUser?.role == role;
  }

  // Check if current user has any of the specified roles
  static bool hasAnyRole(List<UserRole> roles) {
    return _currentUser != null && roles.contains(_currentUser!.role);
  }

  // Get user by role for demo purposes (fallback)
  static User getDemoUser(UserRole role) {
    return User(
      id: role.toString(),
      name: 'Demo ${role.toString().split('.').last}',
      email: 'demo@example.com',
      phone: '+1234567890',
      role: role,
      createdAt: DateTime.now(),
    );
  }
}
