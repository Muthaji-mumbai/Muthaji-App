import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const String _userKey = 'user';
  static const String _tokenKey = 'token';

  // Mock users for demo purposes
  static final List<User> _mockUsers = [
    User(
      id: '1',
      name: 'Admin User',
      email: 'admin@example.com',
      phone: '+1234567890',
      role: UserRole.admin,
      createdAt: DateTime.now(),
    ),
    User(
      id: '2',
      name: 'Employee User',
      email: 'employee@example.com',
      phone: '+1234567891',
      role: UserRole.employee,
      createdAt: DateTime.now(),
    ),
    User(
      id: '3',
      name: 'Client User',
      email: 'client@example.com',
      phone: '+1234567892',
      role: UserRole.client,
      createdAt: DateTime.now(),
    ),
  ];

  static User? _currentUser;
  static String? _currentToken;

  static User? get currentUser => _currentUser;
  static String? get currentToken => _currentToken;
  static bool get isLoggedIn => _currentUser != null;

  // Login method
  static Future<bool> login(String email, String password) async {
    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 1));

    // Find user by email
    final user = _mockUsers.firstWhere(
      (user) => user.email == email,
      orElse: () => throw Exception('User not found'),
    );

    // In real app, verify password here
    if (password == 'password') {
      _currentUser = user;
      _currentToken = 'mock_token_${user.id}';
      
      // Save to local storage
      await _saveUserToStorage();
      return true;
    }

    throw Exception('Invalid credentials');
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

  // Get user by role for demo purposes
  static User getDemoUser(UserRole role) {
    return _mockUsers.firstWhere((user) => user.role == role);
  }

  // Check if current user has specific role
  static bool hasRole(UserRole role) {
    return _currentUser?.role == role;
  }

  // Check if current user has any of the specified roles
  static bool hasAnyRole(List<UserRole> roles) {
    return _currentUser != null && roles.contains(_currentUser!.role);
  }
}
