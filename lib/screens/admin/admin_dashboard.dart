import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../dashboard_screen.dart';
import 'user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic> _orderStats = {};
  Map<String, dynamic> _userStats = {};
  List<Order> _recentOrders = [];
  List<User> _recentUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token != null) {
        // Load real user data
        final users = await UserService.getAllUsers(token);
        final totalUsers = users.length;
        final activeUsers = users.where((u) => u.isActive).length;
        final adminUsers = users.where((u) => u.role == UserRole.admin).length;
        final employeeUsers =
            users.where((u) => u.role == UserRole.employee).length;
        final clientUsers =
            users.where((u) => u.role == UserRole.client).length;

        _userStats = {
          'totalUsers': totalUsers,
          'activeUsers': activeUsers,
          'adminUsers': adminUsers,
          'employeeUsers': employeeUsers,
          'clientUsers': clientUsers,
        };

        // Get recent users (last 5)
        _recentUsers = users.take(5).toList();

        // Load real order data
        final orderStats = await OrderService.getOrderStatistics(token);
        final allOrders = await OrderService.getAllOrders(token);

        _orderStats = orderStats;
        _recentOrders = allOrders.take(5).toList();
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      // Set default values on error
      _userStats = {
        'totalUsers': 0,
        'activeUsers': 0,
        'adminUsers': 0,
        'employeeUsers': 0,
        'clientUsers': 0,
      };
      _recentUsers = [];
      _orderStats = {
        'totalOrders': 0,
        'pendingOrders': 0,
        'inProgressOrders': 0,
        'completedOrders': 0,
        'cancelledOrders': 0,
        'totalRevenue': 0.0,
      };
      _recentOrders = [];
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;

    return DashboardScaffold(
      title: 'Soloshine by muthaji - Admin Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadDashboardData,
        ),
      ],
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () async => _loadDashboardData(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Section
                      _buildWelcomeSection(currentUser!),

                      const SizedBox(height: AppConstants.spacingL),

                      // Quick Actions
                      _buildQuickActions(),

                      const SizedBox(height: AppConstants.spacingL),

                      // Statistics Overview
                      _buildStatisticsOverview(),

                      const SizedBox(height: AppConstants.spacingL),

                      // Recent Orders
                      _buildRecentOrders(),

                      const SizedBox(height: AppConstants.spacingL),

                      // Recent Users
                      _buildRecentUsers(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildWelcomeSection(User user) {
    final displayName =
        user.name.isNotEmpty ? user.name : user.email.split('@')[0];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConstants.secondaryColor, AppConstants.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $displayName!',
            style: AppConstants.headingMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'You have full access to manage the entire system',
            style: AppConstants.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),
        if (isMobile)
          // Stack buttons vertically on mobile
          Column(
            children: [
              CustomButton(
                onPressed: () {
                  // Navigate to order management
                },
                text: 'Manage Orders',
                icon: Icons.shopping_cart,
                backgroundColor: AppConstants.primaryColor,
                isFullWidth: true,
              ),
              const SizedBox(height: AppConstants.spacingM),
              CustomButton(
                onPressed: () {
                  // Navigate to user management
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserManagementScreen(),
                    ),
                  );
                },
                text: 'Manage Users',
                icon: Icons.people,
                backgroundColor: AppConstants.successColor,
                isFullWidth: true,
              ),
              const SizedBox(height: AppConstants.spacingM),
              CustomButton(
                onPressed: () {
                  // Navigate to reports
                },
                text: 'View Reports',
                icon: Icons.analytics,
                backgroundColor: AppConstants.accentColor,
                isFullWidth: true,
              ),
              const SizedBox(height: AppConstants.spacingM),
              CustomButton(
                onPressed: () {
                  // Navigate to settings
                },
                text: 'Settings',
                icon: Icons.settings,
                backgroundColor: AppConstants.secondaryColor,
                isFullWidth: true,
              ),
            ],
          )
        else
          // Show buttons in a grid on tablet/desktop
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      onPressed: () {
                        // Navigate to order management
                      },
                      text: 'Manage Orders',
                      icon: Icons.shopping_cart,
                      backgroundColor: AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: CustomButton(
                      onPressed: () {
                        // Navigate to user management
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserManagementScreen(),
                          ),
                        );
                      },
                      text: 'Manage Users',
                      icon: Icons.people,
                      backgroundColor: AppConstants.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingM),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      onPressed: () {
                        // Navigate to reports
                      },
                      text: 'View Reports',
                      icon: Icons.analytics,
                      backgroundColor: AppConstants.accentColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: CustomButton(
                      onPressed: () {
                        // Navigate to settings
                      },
                      text: 'Settings',
                      icon: Icons.settings,
                      backgroundColor: AppConstants.secondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatisticsOverview() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System Overview', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),

        if (isMobile)
          // Stack cards vertically on mobile
          Column(
            children: [
              _buildStatCard(
                'Total Orders',
                _orderStats['totalOrders']?.toString() ?? '0',
                Icons.shopping_cart,
                AppConstants.primaryColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Total Revenue',
                '\$${_orderStats['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                Icons.attach_money,
                AppConstants.successColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Pending Orders',
                _orderStats['pendingOrders']?.toString() ?? '0',
                Icons.pending,
                AppConstants.warningColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Completed Orders',
                _orderStats['completedOrders']?.toString() ?? '0',
                Icons.check_circle,
                AppConstants.successColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Total Users',
                _userStats['totalUsers']?.toString() ?? '0',
                Icons.people,
                AppConstants.accentColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Active Users',
                _userStats['activeUsers']?.toString() ?? '0',
                Icons.person,
                AppConstants.secondaryColor,
              ),
            ],
          )
        else
          // Show cards in a grid on tablet/desktop
          Column(
            children: [
              // Order Statistics
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Orders',
                      _orderStats['totalOrders']?.toString() ?? '0',
                      Icons.shopping_cart,
                      AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Total Revenue',
                      '\$${_orderStats['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                      Icons.attach_money,
                      AppConstants.successColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.spacingM),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Pending Orders',
                      _orderStats['pendingOrders']?.toString() ?? '0',
                      Icons.pending,
                      AppConstants.warningColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Completed Orders',
                      _orderStats['completedOrders']?.toString() ?? '0',
                      Icons.check_circle,
                      AppConstants.successColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.spacingM),

              // User Statistics
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Users',
                      _userStats['totalUsers']?.toString() ?? '0',
                      Icons.people,
                      AppConstants.accentColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Active Users',
                      _userStats['activeUsers']?.toString() ?? '0',
                      Icons.person,
                      AppConstants.secondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Orders', style: AppConstants.headingSmall),
            TextButton(
              onPressed: () {
                // Navigate to all orders
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (_recentOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            decoration: BoxDecoration(
              color: AppConstants.surfaceColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(
                color: AppConstants.textSecondaryColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 48,
                  color: AppConstants.textSecondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: AppConstants.spacingM),
                Text('No orders yet', style: AppConstants.bodyLarge),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Orders will appear here when created',
                  style: AppConstants.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._recentOrders.map((order) => _buildOrderCard(order)),
      ],
    );
  }

  Widget _buildRecentUsers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Users', style: AppConstants.headingSmall),
            TextButton(
              onPressed: () {
                // Navigate to all users
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (_recentUsers.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            decoration: BoxDecoration(
              color: AppConstants.surfaceColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(
                color: AppConstants.textSecondaryColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: AppConstants.textSecondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: AppConstants.spacingM),
                Text('No users yet', style: AppConstants.bodyLarge),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Users will appear here when registered',
                  style: AppConstants.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._recentUsers.map((user) => _buildUserCard(user)),
      ],
    );
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: Icon(
              Icons.shopping_cart,
              color: _getStatusColor(order.status),
              size: 20,
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.description,
                  style: AppConstants.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Client: ${order.clientName}',
                  style: AppConstants.bodyMedium.copyWith(
                    color: AppConstants.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${order.amount.toStringAsFixed(2)}',
                style: AppConstants.bodyLarge.copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: AppConstants.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Text(
                  _getStatusText(order.status),
                  style: AppConstants.bodySmall.copyWith(
                    color: _getStatusColor(order.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRoleColor(user.role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: Icon(
              _getRoleIcon(user.role),
              color: _getRoleColor(user.role),
              size: 20,
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: AppConstants.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.email,
                  style: AppConstants.bodyMedium.copyWith(
                    color: AppConstants.textSecondaryColor,
                  ),
                ),
                if (user.phone.isNotEmpty)
                  Text(
                    'Phone: ${user.phone}',
                    style: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondaryColor,
                    ),
                  ),
                if (user.address != null && user.address!.isNotEmpty)
                  Text(
                    'Address: ${user.address}',
                    style: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
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
              const SizedBox(height: AppConstants.spacingXS),
              Text(
                'Joined: ${_formatDate(user.createdAt)}',
                style: AppConstants.bodySmall.copyWith(
                  color: AppConstants.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: AppConstants.spacingS),
          Text(value, style: AppConstants.headingSmall.copyWith(color: color)),
          const SizedBox(height: AppConstants.spacingXS),
          Text(
            title,
            style: AppConstants.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppConstants.warningColor;
      case OrderStatus.confirmed:
        return AppConstants.accentColor;
      case OrderStatus.inProgress:
        return AppConstants.secondaryColor;
      case OrderStatus.completed:
        return AppConstants.successColor;
      case OrderStatus.cancelled:
        return AppConstants.errorColor;
    }
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.employee:
        return 'Employee';
      case UserRole.client:
        return 'Client';
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
