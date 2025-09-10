enum UserRole { customer, employee, admin }

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;
  final String? token;
  final String? address;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.isActive = true,
    this.token,
    this.address,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'User', // Default name if not provided
      email: json['email'] ?? '',
      phone: json['phone'] ?? '', // Default empty phone if not provided
      role: _parseRole(json['role']),
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      isActive: json['isActive'] ?? true,
      token: json['token'],
      address: json['address'],
    );
  }

  static UserRole _parseRole(String? role) {
    if (role == null) return UserRole.customer;

    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'employee':
        return UserRole.employee;
      case 'customer':
      case 'client':
        return UserRole.customer;
      default:
        return UserRole.customer;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'token': token,
      'address': address,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
    String? token,
    String? address,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      token: token ?? this.token,
      address: address ?? this.address,
    );
  }
}
