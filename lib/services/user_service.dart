import '../models/user.dart';
import 'api_service.dart';
import '../constants/app_constants.dart';

class UserService {
  // Update FCM token for a user
  static Future<bool> updateFcmToken({
    required String userId,
    required String fcmtoken,
    String? token,
  }) async {
    try {
      final response = await ApiService.patch(
        '${AppConstants.usersEndpoint}/$userId',
        body: {'fcmtoken': fcmtoken},
        token: token,
      );

      return response['success'] == true;
    } catch (e) {
      throw Exception('Error updating FCM token: $e');
    }
  }

  // Get all users
  static Future<List<User>> getAllUsers(String token) async {
    try {
      final response = await ApiService.get(
        AppConstants.usersEndpoint,
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> usersData = response['data'];
        return usersData.map((userData) => User.fromJson(userData)).toList();
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch users');
      }
    } catch (e) {
      throw Exception('Error fetching users: $e');
    }
  }

  // Create new user
  static Future<User> createUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    required String address,
    String? token,
  }) async {
    try {
      final response = await ApiService.post(
        AppConstants.usersEndpoint,
        body: {
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'role': role.toString().split('.').last,
          'address': address,
        },
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        return User.fromJson(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to create user');
      }
    } catch (e) {
      throw Exception('Error creating user: $e');
    }
  }

  // Update user
  static Future<User> updateUser({
    required String userId,
    required Map<String, dynamic> updateData,
    String? token,
    
  }) async {
    try {
      final response = await ApiService.patch(
        '${AppConstants.usersEndpoint}/$userId',
        body: updateData,
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        return User.fromJson(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to update user');
      }
    } catch (e) {
      throw Exception('Error updating user: $e');
    }
  }

  // Delete user
  static Future<bool> deleteUser({
    required String userId,
    String? token,
  }) async {
    try {
      final response = await ApiService.delete(
        '${AppConstants.usersEndpoint}/$userId',
        token: token,
      );

      return response['success'] == true;
    } catch (e) {
      throw Exception('Error deleting user: $e');
    }
  }

  // Get user by ID
  static Future<User> getUserById({
    required String userId,
    String? token,
  }) async {
    try {
      final response = await ApiService.get(
        '${AppConstants.usersEndpoint}/$userId',
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        return User.fromJson(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch user');
      }
    } catch (e) {
      throw Exception('Error fetching user: $e');
    }
  }

  // Get users by role
  static Future<List<User>> getUsersByRole(UserRole role, String? token) async {
    try {
      final allUsers = await getAllUsers(token ?? '');
      return allUsers.where((user) => user.role == role).toList();
    } catch (e) {
      throw Exception('Error fetching users by role: $e');
    }
  }

  // Mock methods for backward compatibility (fallback)
  static Map<String, dynamic> getUserStatistics() {
    return {'totalUsers': 0, 'activeUsers': 0};
  }

  static List<User> getRecentUsers() {
    return [];
  }
}
