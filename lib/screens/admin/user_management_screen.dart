import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/user_service.dart';
import '../../models/user.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('No authentication token available');
      }

      final users = await UserService.getAllUsers(token);
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<User> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;

    return _users.where((user) {
      final query = _searchQuery.toLowerCase();
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.phone.contains(query) ||
          user.role.toString().toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      body: Column(
        children: [
          // Search and Add User Section
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: AppConstants.surfaceColor,
              boxShadow: AppConstants.cardShadow,
            ),
            child: Column(
              children: [
                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: AppConstants.backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusM,
                            ),
                            borderSide: BorderSide(
                              color: AppConstants.textSecondaryColor
                                  .withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusM,
                            ),
                            borderSide: BorderSide(
                              color: AppConstants.textSecondaryColor
                                  .withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusM,
                            ),
                            borderSide: const BorderSide(
                              color: AppConstants.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    CustomButton(
                      onPressed: () => _showAddUserDialog(context),
                      text: 'Add User',
                      icon: Icons.person_add,
                      backgroundColor: AppConstants.successColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _buildErrorWidget()
                    : _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppConstants.errorColor),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            'Error loading users',
            style: AppConstants.headingSmall.copyWith(
              color: AppConstants.errorColor,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            _error!,
            style: AppConstants.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingM),
          CustomButton(
            onPressed: _loadUsers,
            text: 'Retry',
            icon: Icons.refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppConstants.textSecondaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              _searchQuery.isEmpty
                  ? 'No users found'
                  : 'No users match your search',
              style: AppConstants.headingSmall,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'Add your first user to get started',
                style: AppConstants.bodyMedium,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
          child: Icon(_getRoleIcon(user.role), color: _getRoleColor(user.role)),
        ),
        title: Text(
          user.name,
          style: AppConstants.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            if (user.phone.isNotEmpty) Text('Phone: ${user.phone}'),
            if (user.address != null && user.address!.isNotEmpty)
              Text('Address: ${user.address}'),
            Container(
              margin: const EdgeInsets.only(top: AppConstants.spacingXS),
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingS,
                vertical: AppConstants.spacingXS,
              ),
              decoration: BoxDecoration(
                color: _getRoleColor(user.role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              child: Text(
                _getRoleText(user.role),
                style: AppConstants.bodySmall.copyWith(
                  color: _getRoleColor(user.role),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditUserDialog(context, user);
                break;
              case 'delete':
                _showDeleteUserDialog(context, user);
                break;
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: AppConstants.accentColor),
                      SizedBox(width: AppConstants.spacingS),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: AppConstants.errorColor),
                      SizedBox(width: AppConstants.spacingS),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddUserDialog(),
    ).then((_) => _loadUsers());
  }

  void _showEditUserDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    ).then((_) => _loadUsers());
  }

  void _showDeleteUserDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete User'),
            content: Text('Are you sure you want to delete ${user.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteUser(user);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppConstants.errorColor,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteUser(User user) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('No authentication token available');
      }

      await UserService.deleteUser(userId: user.id, token: token);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} deleted successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.employee:
        return 'Employee';
      case UserRole.client:
        return 'Customer';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppConstants.errorColor;
      case UserRole.employee:
        return AppConstants.accentColor;
      case UserRole.client:
        return AppConstants.primaryColor;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.employee:
        return Icons.work;
      case UserRole.client:
        return Icons.person;
    }
  }
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  UserRole _selectedRole = UserRole.client;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('No authentication token available');
      }

      await UserService.createUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        address: _addressController.text.trim(),
        token: token,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User created successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating user: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New User'),
      content: SizedBox(
        width:
            ResponsiveValue<double>(
              context,
              defaultValue: 400,
              conditionalValues: [
                const Condition.equals(name: MOBILE, value: double.infinity),
                const Condition.equals(name: TABLET, value: 500),
                const Condition.equals(name: DESKTOP, value: 400),
              ],
            ).value!,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Full Name',
                  hintText: 'Enter full name',
                  prefixIcon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingM),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  hintText: 'Enter email address',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingM),
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Password',
                  hintText: 'Enter password',
                  prefixIcon: Icons.lock,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingM),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone',
                  hintText: 'Enter phone number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingM),
                CustomTextField(
                  controller: _addressController,
                  labelText: 'Address',
                  hintText: 'Enter address',
                  prefixIcon: Icons.location_on,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingM),
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.work),
                  ),
                  items:
                      UserRole.values.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(_getRoleText(role)),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CustomButton(
          onPressed: _isLoading ? null : _createUser,
          text: _isLoading ? 'Creating...' : 'Create User',
          isLoading: _isLoading,
          backgroundColor: AppConstants.successColor,
        ),
      ],
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.employee:
        return 'Employee';
      case UserRole.client:
        return 'Customer';
    }
  }
}

class EditUserDialog extends StatefulWidget {
  final User user;

  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  UserRole _selectedRole = UserRole.client;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
    _emailController.text = widget.user.email;
    _phoneController.text = widget.user.phone;
    _addressController.text = widget.user.address ?? '';
    _selectedRole = widget.user.role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('No authentication token available');
      }

      final updateData = <String, dynamic>{};

      if (_nameController.text.trim() != widget.user.name) {
        updateData['name'] = _nameController.text.trim();
      }
      if (_emailController.text.trim() != widget.user.email) {
        updateData['email'] = _emailController.text.trim();
      }
      if (_phoneController.text.trim() != widget.user.phone) {
        updateData['phone'] = _phoneController.text.trim();
      }
      if (_addressController.text.trim() != (widget.user.address ?? '')) {
        updateData['address'] = _addressController.text.trim();
      }
      if (_selectedRole != widget.user.role) {
        updateData['role'] = _selectedRole.toString().split('.').last;
      }

      if (updateData.isNotEmpty) {
        await UserService.updateUser(
          userId: widget.user.id,
          updateData: updateData,
          token: token,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.user.name} updated successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.user.name}'),
      content: SizedBox(
        width:
            ResponsiveValue<double>(
              context,
              defaultValue: 400,
              conditionalValues: [
                const Condition.equals(name: MOBILE, value: double.infinity),
                const Condition.equals(name: TABLET, value: 500),
                const Condition.equals(name: DESKTOP, value: 400),
              ],
            ).value!,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Full Name',
                  hintText: 'Enter full name',
                  prefixIcon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingM),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  hintText: 'Enter email address',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingM),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone',
                  hintText: 'Enter phone number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingM),
                CustomTextField(
                  controller: _addressController,
                  labelText: 'Address',
                  hintText: 'Enter address',
                  prefixIcon: Icons.location_on,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacingM),
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.work),
                  ),
                  items:
                      UserRole.values.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(_getRoleText(role)),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CustomButton(
          onPressed: _isLoading ? null : _updateUser,
          text: _isLoading ? 'Updating...' : 'Update User',
          isLoading: _isLoading,
          backgroundColor: AppConstants.accentColor,
        ),
      ],
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.employee:
        return 'Employee';
      case UserRole.client:
        return 'Customer';
    }
  }
}
