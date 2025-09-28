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
      // Validate input parameters
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }
      if (fcmtoken.isEmpty) {
        throw Exception('FCM token is required');
      }
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      final response = await ApiService.patch(
        '${AppConstants.usersEndpoint}/$userId',
        body: {'fcmtoken': fcmtoken},
        token: token,
      );

      if (response['success'] == true) {
        return true;
      } else {
        final errorMessage =
            response['message'] ?? 'Failed to update FCM token';
        throw Exception(errorMessage);
      }
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Network error')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timed out. Please try again.');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (errorMessage.contains('404')) {
        throw Exception('User not found.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to update this user.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error updating FCM token: ${e.toString()}');
    }
  }

  // Get all users
  static Future<List<User>> getAllUsers(String token) async {
    try {
      // Validate token
      if (token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      final response = await ApiService.get(
        AppConstants.usersEndpoint,
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          final List<dynamic> usersData = response['data'];
          return usersData.map((userData) {
            try {
              return User.fromJson(userData);
            } catch (e) {
              throw Exception('Failed to parse user data: ${e.toString()}');
            }
          }).toList();
        } catch (e) {
          throw Exception('Failed to parse users data: ${e.toString()}');
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to fetch users';
        throw Exception(errorMessage);
      }
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Network error')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timed out. Please try again.');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to view users.');
      } else if (errorMessage.contains('404')) {
        throw Exception('Users not found.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error fetching users: ${e.toString()}');
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
      // Validate input parameters
      if (name.isEmpty) {
        throw Exception('Name is required');
      }
      if (email.isEmpty) {
        throw Exception('Email is required');
      }
      if (!email.contains('@')) {
        throw Exception('Please enter a valid email address');
      }
      if (password.isEmpty) {
        throw Exception('Password is required');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }
      if (phone.isEmpty) {
        throw Exception('Phone number is required');
      }
      if (address.isEmpty) {
        throw Exception('Address is required');
      }
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      final response = await ApiService.post(
        AppConstants.usersEndpoint,
        body: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'phone': phone.trim(),
          'role': role.toString().split('.').last,
          'address': address.trim(),
        },
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          return User.fromJson(response['data']);
        } catch (e) {
          throw Exception('Failed to parse created user data: ${e.toString()}');
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to create user';
        throw Exception(errorMessage);
      }
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Network error')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timed out. Please try again.');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (errorMessage.contains('400')) {
        throw Exception('Invalid user data. Please check your input.');
      } else if (errorMessage.contains('409')) {
        throw Exception('User with this email already exists.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to create users.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error creating user: ${e.toString()}');
    }
  }

  // Update user
  static Future<User> updateUser({
    required String userId,
    required Map<String, dynamic> updateData,
    String? token,
  }) async {
    try {
      // Validate input parameters
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }
      if (updateData.isEmpty) {
        throw Exception('Update data is required');
      }
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      // Validate email if provided
      if (updateData.containsKey('email')) {
        final email = updateData['email']?.toString();
        if (email != null && email.isNotEmpty && !email.contains('@')) {
          throw Exception('Please enter a valid email address');
        }
      }

      // Validate password if provided
      if (updateData.containsKey('password')) {
        final password = updateData['password']?.toString();
        if (password != null && password.isNotEmpty && password.length < 6) {
          throw Exception('Password must be at least 6 characters long');
        }
      }

      final response = await ApiService.patch(
        '${AppConstants.usersEndpoint}/$userId',
        body: updateData,
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          return User.fromJson(response['data']);
        } catch (e) {
          throw Exception('Failed to parse updated user data: ${e.toString()}');
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to update user';
        throw Exception(errorMessage);
      }
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Network error')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timed out. Please try again.');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (errorMessage.contains('404')) {
        throw Exception('User not found.');
      } else if (errorMessage.contains('400')) {
        throw Exception('Invalid user data. Please check your input.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to update this user.');
      } else if (errorMessage.contains('409')) {
        throw Exception('User with this email already exists.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error updating user: ${e.toString()}');
    }
  }

  // Delete user
  static Future<bool> deleteUser({
    required String userId,
    String? token,
  }) async {
    try {
      // Validate input parameters
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      final response = await ApiService.delete(
        '${AppConstants.usersEndpoint}/$userId',
        token: token,
      );

      if (response['success'] == true) {
        return true;
      } else {
        final errorMessage = response['message'] ?? 'Failed to delete user';
        throw Exception(errorMessage);
      }
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Network error')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timed out. Please try again.');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (errorMessage.contains('404')) {
        throw Exception('User not found.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to delete this user.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error deleting user: ${e.toString()}');
    }
  }

  // Get user by ID
  static Future<User> getUserById({
    required String userId,
    String? token,
  }) async {
    try {
      // Validate input parameters
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      final response = await ApiService.get(
        '${AppConstants.usersEndpoint}/$userId',
        token: token,
      );

      if (response['success'] == true && response['data'] != null) {
        try {
          return User.fromJson(response['data']);
        } catch (e) {
          throw Exception('Failed to parse user data: ${e.toString()}');
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to fetch user';
        throw Exception(errorMessage);
      }
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Network error')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timed out. Please try again.');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (errorMessage.contains('404')) {
        throw Exception('User not found.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to view this user.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Unexpected error fetching user: ${e.toString()}');
    }
  }

  // Get users by role
  static Future<List<User>> getUsersByRole(UserRole role, String? token) async {
    try {
      // Validate input parameters
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is required');
      }

      final allUsers = await getAllUsers(token);
      return allUsers.where((user) => user.role == role).toList();
    } on Exception catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Network error')) {
        throw Exception(
          'Network connection failed. Please check your internet connection.',
        );
      } else if (errorMessage.contains('timeout')) {
        throw Exception('Request timed out. Please try again.');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized')) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (errorMessage.contains('403')) {
        throw Exception('You do not have permission to view users.');
      } else if (errorMessage.contains('404')) {
        throw Exception('No users found with the specified role.');
      } else if (errorMessage.contains('500')) {
        throw Exception('Server error. Please try again later.');
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception(
        'Unexpected error fetching users by role: ${e.toString()}',
      );
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
