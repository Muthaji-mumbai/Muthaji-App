import 'package:uuid/uuid.dart';
import '../models/user.dart';

class UserService {
  static final List<User> _users = [];
  static final _uuid = Uuid();

  // Initialize with some mock data
  static void initializeMockData() {
    if (_users.isEmpty) {
      _users.addAll([
        User(
          id: '1',
          name: 'Admin User',
          email: 'admin@example.com',
          phone: '+1234567890',
          role: UserRole.admin,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
        User(
          id: '2',
          name: 'Employee User',
          email: 'employee@example.com',
          phone: '+1234567891',
          role: UserRole.employee,
          createdAt: DateTime.now().subtract(const Duration(days: 20)),
        ),
        User(
          id: '3',
          name: 'Client User',
          email: 'client@example.com',
          phone: '+1234567892',
          role: UserRole.client,
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
        ),
        User(
          id: '4',
          name: 'John Doe',
          email: 'john@example.com',
          phone: '+1234567893',
          role: UserRole.client,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
        User(
          id: '5',
          name: 'Jane Smith',
          email: 'jane@example.com',
          phone: '+1234567894',
          role: UserRole.client,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ]);
    }
  }

  // Get all users
  static List<User> getAllUsers() {
    initializeMockData();
    return List.from(_users);
  }

  // Get users by role
  static List<User> getUsersByRole(UserRole role) {
    initializeMockData();
    return _users.where((user) => user.role == role).toList();
  }

  // Get user by ID
  static User? getUserById(String userId) {
    initializeMockData();
    try {
      return _users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  // Get user by email
  static User? getUserByEmail(String email) {
    initializeMockData();
    try {
      return _users.firstWhere((user) => user.email == email);
    } catch (e) {
      return null;
    }
  }

  // Create new user (for employees creating clients)
  static User createUser({
    required String name,
    required String email,
    required String phone,
    required UserRole role,
  }) {
    // Check if email already exists
    if (getUserByEmail(email) != null) {
      throw Exception('User with this email already exists');
    }

    final user = User(
      id: _uuid.v4(),
      name: name,
      email: email,
      phone: phone,
      role: role,
      createdAt: DateTime.now(),
    );

    _users.add(user);
    return user;
  }

  // Update user
  static User? updateUser(String userId, {
    String? name,
    String? email,
    String? phone,
    bool? isActive,
  }) {
    final userIndex = _users.indexWhere((user) => user.id == userId);
    if (userIndex != -1) {
      final updatedUser = _users[userIndex].copyWith(
        name: name,
        email: email,
        phone: phone,
        isActive: isActive,
      );
      _users[userIndex] = updatedUser;
      return updatedUser;
    }
    return null;
  }

  // Delete user
  static bool deleteUser(String userId) {
    final userIndex = _users.indexWhere((user) => user.id == userId);
    if (userIndex != -1) {
      _users.removeAt(userIndex);
      return true;
    }
    return false;
  }

  // Search users
  static List<User> searchUsers(String query) {
    initializeMockData();
    if (query.isEmpty) return getAllUsers();
    
    final lowercaseQuery = query.toLowerCase();
    return _users.where((user) =>
      user.name.toLowerCase().contains(lowercaseQuery) ||
      user.email.toLowerCase().contains(lowercaseQuery) ||
      user.phone.contains(query)
    ).toList();
  }

  // Get user statistics
  static Map<String, dynamic> getUserStatistics() {
    initializeMockData();
    
    final totalUsers = _users.length;
    final activeUsers = _users.where((user) => user.isActive).length;
    final adminUsers = _users.where((user) => user.role == UserRole.admin).length;
    final employeeUsers = _users.where((user) => user.role == UserRole.employee).length;
    final clientUsers = _users.where((user) => user.role == UserRole.client).length;

    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'adminUsers': adminUsers,
      'employeeUsers': employeeUsers,
      'clientUsers': clientUsers,
    };
  }

  // Get recent users
  static List<User> getRecentUsers({int limit = 5}) {
    initializeMockData();
    final sortedUsers = List<User>.from(_users);
    sortedUsers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedUsers.take(limit).toList();
  }
}
