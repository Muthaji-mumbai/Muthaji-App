import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
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

// Small chip used in the welcome banner
class _WelcomeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WelcomeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingS,
        vertical: AppConstants.spacingXS,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppConstants.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic> _orderStats = {};
  Map<String, dynamic> _userStats = {};
  List<Order> _recentOrders = [];
  List<Order> _allOrders = [];
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
        _allOrders = allOrders;
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
      title: 'Muthaji - Admin Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadDashboardData,
        ),
      ],
      body: Stack(
        children: [
          // Background image layer
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
              color: Colors.white.withOpacity(0.85),
              colorBlendMode: BlendMode.srcOver,
            ),
          ),
          // Foreground content
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            RefreshIndicator(
              onRefresh: () async => _loadDashboardData(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                physics: const AlwaysScrollableScrollPhysics(),
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

                    // Orders by Date Chart
                    _buildOrdersByDateChart(days: 14, allOrders: _allOrders),

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
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(User user) {
    final displayName =
        user.name.isNotEmpty ? user.name : user.email.split('@')[0];

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusL),
      child: Stack(
        children: [
          // Gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.primaryColor,
                  AppConstants.secondaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppConstants.cardShadow,
            ),
          ),
          // Subtle logo watermark
          Positioned(
            right: -10,
            bottom: -10,
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/icons/logo.jpg',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Foreground content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $displayName!',
                    style:
                        AppConstants.headingMedium.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'You have full access to manage the entire system',
                    style: AppConstants.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  Wrap(
                    spacing: AppConstants.spacingS,
                    runSpacing: AppConstants.spacingS,
                    children: const [
                      _WelcomeChip(icon: Icons.security, label: 'Admin Access'),
                      _WelcomeChip(icon: Icons.analytics, label: 'Insights'),
                      _WelcomeChip(icon: Icons.settings, label: 'Settings'),
                    ],
                  ),
                ],
              ),
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

  Widget _buildOrdersByDateChart({int days = 14, required List<Order> allOrders}) {
    // Prepare date buckets for last `days` days
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final Map<DateTime, int> counts = {
      for (int i = 0; i < days; i++)
        DateTime(start.year, start.month, start.day).add(Duration(days: i)): 0,
    };

        for (final o in allOrders) {
      final d = (o.orderDate ?? o.createdAt);
      final key = DateTime(d.year, d.month, d.day);
      if (key.isAfter(start.subtract(const Duration(days: 1))) && key.isBefore(now.add(const Duration(days: 1)))) {
        if (counts.containsKey(key)) counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxY = (entries.map((e) => e.value).fold<int>(0, (p, c) => c > p ? c : p)).toDouble();
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < entries.length; i++) {
      final v = entries[i].value.toDouble();
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: v,
              width: 12,
              borderRadius: BorderRadius.circular(4),
              color: AppConstants.primaryColor,
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: (maxY == 0 ? 1 : maxY),
                color: AppConstants.secondaryColor.withOpacity(0.25),
              ),
            ),
          ],
        ),
      );
    }

    String _labelFor(DateTime d) => '${d.day}/${d.month}';

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Orders (last $days days)', style: AppConstants.headingSmall),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= entries.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _labelFor(entries[idx].key),
                            style: AppConstants.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: barGroups,
                maxY: (maxY == 0 ? 1 : maxY) * 1.2,
              ),
            ),
          ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Row(
        children: [
          // Accent bar
          Container(
            width: 5,
            height: 84,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.radiusM),
                bottomLeft: Radius.circular(AppConstants.radiusM),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppConstants.bodyMedium.copyWith(
                            color: AppConstants.textSecondaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppConstants.spacingXS),
                        Text(
                          value,
                          style: AppConstants.headingSmall.copyWith(
                            color: AppConstants.textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
