import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  // Check if user has specific role
  bool hasRole(UserRole role) {
    return _currentUser?.role == role;
  }

  // Check if user has any of the specified roles
  bool hasAnyRole(List<UserRole> roles) {
    return _currentUser != null && roles.contains(_currentUser!.role);
  }

  // Initialize auth state
  Future<void> initializeAuth() async {
    _setLoading(true);
    try {
      final isLoggedIn = await AuthService.checkAuthStatus();
      if (isLoggedIn) {
        _currentUser = AuthService.currentUser;
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to initialize authentication';
    } finally {
      _setLoading(false);
    }
  }

  // Login
  // Login
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final result = await AuthService.login(email, password);
      if (result['success']) {
        _currentUser = AuthService.currentUser;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);
    try {
      await AuthService.logout();
      _currentUser = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to logout';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Update current user
  void updateCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}
