import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:soloshine/screens/employee/manage_orders_screen.dart';
import 'package:soloshine/services/dashboard_service.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../dashboard_screen.dart';
import 'user_management_screen.dart';
import '../client/create_order_screen.dart';

// View switching: dashboard, orders, reports
enum _AdminView { dashboard, orders, reports }

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
  Map<String, dynamic> _dashboardStats = {};
  List<Order> _allOrders = [];
  List<User> _recentUsers = [];
  bool _isLoading = true;
  _AdminView _currentView = _AdminView.dashboard;
  int _chartDays = 14; // default last 14 days

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
        // Load dashboard statistics
        final dashboardStats =
            await AdminDashboardService.getDashboardStatistics(token);
        _dashboardStats = dashboardStats;

        // Load user data
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

        // Load order data
        final orderStats = await OrderService.getOrderStatistics(token);
        final allOrders = await OrderService.getAllOrders(token);

        _orderStats = orderStats;
        _allOrders = allOrders;
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
      _dashboardStats = {
        'orderTypeCounts': {'single': 0, 'bulk': 0, 'total': 0},
        'statusCounts': {
          'pending': 0,
          'inProgress': 0,
          'completed': 0,
          'cancelled': 0,
        },
      };
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;

    return DashboardScaffold(
      logo: Image.asset(
        'assets/icons/logo.png',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
      title: 'Muthaji - Admin',
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
                child: Builder(
                  builder: (context) {
                    switch (_currentView) {
                      case _AdminView.dashboard:
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Welcome Section
                            _buildWelcomeSection(currentUser!),
                            const SizedBox(height: AppConstants.spacingL),
                            // Pie Charts
                            _buildPieChartsSection(),
                            const SizedBox(height: AppConstants.spacingL),
                            // Orders by Date Chart
                            _buildOrdersByDateChart(
                              days: _chartDays,
                              allOrders: _allOrders,
                              onDaysChanged: (days) {
                                setState(() {
                                  _chartDays = days;
                                });
                              },
                            ),
                            const SizedBox(height: AppConstants.spacingL),
                            // Quick Actions
                            _buildQuickActions(),
                            const SizedBox(height: AppConstants.spacingL),
                            // Statistics Overview
                            _buildStatisticsOverview(),
                            const SizedBox(height: AppConstants.spacingL),
                            // Recent Users
                            _buildRecentUsers(),
                          ],
                        );
                      case _AdminView.orders:
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopBar('All Orders'),
                            const SizedBox(height: AppConstants.spacingM),
                            _buildAllOrdersView(),
                          ],
                        );
                      case _AdminView.reports:
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopBar('Reports'),
                            const SizedBox(height: AppConstants.spacingM),
                            _buildReportsView(),
                          ],
                        );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButtons: [
        FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateOrderScreen(),
              ),
            );
            if (!mounted) return;
            if (result == true) {
              _loadDashboardData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order created successfully'),
                  backgroundColor: AppConstants.successColor,
                ),
              );
            }
          },
          backgroundColor: AppConstants.successColor,
          tooltip: 'Create New Order',
          child: const Icon(Icons.add_shopping_cart),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(User user) {
    final displayName = user.email.split('@')[0];
    print("user.name: $displayName");
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusL),
      child: Stack(
        children: [
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
          Positioned(
            right: -10,
            bottom: -10,
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/icons/logo.png',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $displayName!',
                    style: AppConstants.headingMedium.copyWith(
                      color: const Color.fromARGB(255, 230, 225, 225),
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

  Widget _buildPieChartsSection() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final orderTypeCounts =
        _dashboardStats['orderTypeCounts'] ??
        {'single': 0, 'bulk': 0, 'total': 0};
    final statusCounts =
        _dashboardStats['statusCounts'] ??
        {'pending': 0, 'inProgress': 0, 'completed': 0, 'cancelled': 0};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Statistics', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),
        isMobile
            ? Column(
              children: [
                _buildPieChart(
                  title: 'Order Status',
                  data: [
                    PieChartSectionData(
                      color: AppConstants.warningColor,
                      value: statusCounts['pending'].toDouble(),
                      title: 'Pending',
                      radius: 50,
                      titleStyle: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppConstants.secondaryColor,
                      value: statusCounts['inProgress'].toDouble(),
                      title: 'In Progress',
                      radius: 50,
                      titleStyle: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppConstants.successColor,
                      value: statusCounts['completed'].toDouble(),
                      title: 'Completed',
                      radius: 50,
                      titleStyle: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppConstants.errorColor,
                      value: statusCounts['cancelled'].toDouble(),
                      title: 'Cancelled',
                      radius: 50,
                      titleStyle: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingL),
                _buildPieChart(
                  title: 'Single Orders',
                  data: [
                    PieChartSectionData(
                      color: AppConstants.primaryColor,
                      value: orderTypeCounts['single'].toDouble(),
                      title: 'Single',
                      radius: 50,
                      titleStyle: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppConstants.surfaceColor,
                      value:
                          orderTypeCounts['total'].toDouble() -
                          orderTypeCounts['single'].toDouble(),
                      title: 'Others',
                      radius: 50,
                      titleStyle: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingL),
                _buildPieChart(
                  title: 'Bulk Orders',
                  data: [
                    PieChartSectionData(
                      color: AppConstants.accentColor,
                      value: orderTypeCounts['bulk'].toDouble(),
                      title: 'Bulk',
                      radius: 50,
                      titleStyle: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppConstants.surfaceColor,
                      value:
                          orderTypeCounts['total'].toDouble() -
                          orderTypeCounts['bulk'].toDouble(),
                      title: 'Others',
                      radius: 50,
                      titleStyle: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            )
            : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPieChart(
                    title: 'Order Status',
                    data: [
                      PieChartSectionData(
                        color: AppConstants.warningColor,
                        value: statusCounts['pending'].toDouble(),
                        title: 'Pending',
                        radius: 60,
                        titleStyle: AppConstants.bodySmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: AppConstants.secondaryColor,
                        value: statusCounts['inProgress'].toDouble(),
                        title: 'In Progress',
                        radius: 60,
                        titleStyle: AppConstants.bodySmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: AppConstants.successColor,
                        value: statusCounts['completed'].toDouble(),
                        title: 'Completed',
                        radius: 60,
                        titleStyle: AppConstants.bodySmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: AppConstants.errorColor,
                        value: statusCounts['cancelled'].toDouble(),
                        title: 'Cancelled',
                        radius: 60,
                        titleStyle: AppConstants.bodySmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: _buildPieChart(
                    title: 'Single Orders',
                    data: [
                      PieChartSectionData(
                        color: AppConstants.primaryColor,
                        value: orderTypeCounts['single'].toDouble(),
                        title: 'Single',
                        radius: 60,
                        titleStyle: AppConstants.bodySmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: AppConstants.surfaceColor,
                        value:
                            orderTypeCounts['total'].toDouble() -
                            orderTypeCounts['single'].toDouble(),
                        title: 'Others',
                        radius: 60,
                        titleStyle: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: _buildPieChart(
                    title: 'Bulk Orders',
                    data: [
                      PieChartSectionData(
                        color: AppConstants.accentColor,
                        value: orderTypeCounts['bulk'].toDouble(),
                        title: 'Bulk',
                        radius: 60,
                        titleStyle: AppConstants.bodySmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: AppConstants.surfaceColor,
                        value:
                            orderTypeCounts['total'].toDouble() -
                            orderTypeCounts['bulk'].toDouble(),
                        title: 'Others',
                        radius: 60,
                        titleStyle: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildPieChart({
    required String title,
    required List<PieChartSectionData> data,
  }) {
    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    final isEmpty = total == 0;

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
          Text(title, style: AppConstants.headingSmall),
          const SizedBox(height: AppConstants.spacingM),
          SizedBox(
            height: 150,
            child:
                isEmpty
                    ? Center(
                      child: Text(
                        'No data available',
                        style: AppConstants.bodyMedium.copyWith(
                          color: AppConstants.textSecondaryColor,
                        ),
                      ),
                    )
                    : PieChart(
                      PieChartData(
                        sections: data,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
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
          Column(
            children: [
              CustomButton(
                onPressed: () {
                  // setState(() => _currentView = _AdminView.orders);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageOrdersScreen(),
                    ),
                  );
                },
                text: 'Manage Orders',
                icon: Icons.shopping_cart,
                backgroundColor: AppConstants.primaryColor,
                isFullWidth: true,
              ),
              const SizedBox(height: AppConstants.spacingM),
              CustomButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateOrderScreen(),
                    ),
                  );
                  if (!mounted) return;
                  if (result == true) {
                    _loadDashboardData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order created successfully'),
                        backgroundColor: AppConstants.successColor,
                      ),
                    );
                  }
                },
                text: 'Create Order',
                icon: Icons.add_shopping_cart,
                backgroundColor: AppConstants.successColor,
                isFullWidth: true,
              ),
              const SizedBox(height: AppConstants.spacingM),
              CustomButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserManagementScreen(),
                    ),
                  );
                },
                text: 'Manage Users',
                icon: Icons.people,
                backgroundColor: AppConstants.accentColor,
                isFullWidth: true,
              ),
              const SizedBox(height: AppConstants.spacingM),
              CustomButton(
                onPressed: () {
                  setState(() => _currentView = _AdminView.reports);
                },
                text: 'View Reports',
                icon: Icons.analytics,
                backgroundColor: AppConstants.secondaryColor,
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
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      onPressed: () {
                        setState(() => _currentView = _AdminView.orders);
                      },
                      text: 'Manage Orders',
                      icon: Icons.shopping_cart,
                      backgroundColor: AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: CustomButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateOrderScreen(),
                          ),
                        );
                        if (!mounted) return;
                        if (result == true) {
                          _loadDashboardData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order created successfully'),
                              backgroundColor: AppConstants.successColor,
                            ),
                          );
                        }
                      },
                      text: 'Create Order',
                      icon: Icons.add_shopping_cart,
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserManagementScreen(),
                          ),
                        );
                      },
                      text: 'Manage Users',
                      icon: Icons.people,
                      backgroundColor: AppConstants.accentColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: CustomButton(
                      onPressed: () {
                        setState(() => _currentView = _AdminView.reports);
                      },
                      text: 'View Reports',
                      icon: Icons.analytics,
                      backgroundColor: AppConstants.secondaryColor,
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
                        // Navigate to settings
                      },
                      text: 'Settings',
                      icon: Icons.settings,
                      backgroundColor: AppConstants.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildOrdersByDateChart({
    int days = 14,
    required List<Order> allOrders,
    required Function(int) onDaysChanged,
  }) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final Map<DateTime, int> counts = {
      for (int i = 0; i < days; i++)
        DateTime(start.year, start.month, start.day).add(Duration(days: i)): 0,
    };

    for (final o in allOrders) {
      final d = (o.orderDate ?? o.createdAt);
      final key = DateTime(d.year, d.month, d.day);
      if (key.isAfter(start.subtract(const Duration(days: 1))) &&
          key.isBefore(now.add(const Duration(days: 1)))) {
        if (counts.containsKey(key)) counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final entries =
        counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxY =
        (entries
            .map((e) => e.value)
            .fold<int>(0, (p, c) => c > p ? c : p)).toDouble();
    final spots = <FlSpot>[];
    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value.toDouble()));
    }

    String _labelFor(DateTime d) => '${d.day}/${d.month}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final chartHeight = isMobile ? screenWidth * 0.6 : 220.0;
        final chartWidth = days * (isMobile ? 30.0 : 40.0);
        final step = (days / (isMobile ? 4 : 7)).ceil();

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
                  Text('Orders Over Time', style: AppConstants.headingSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppConstants.textSecondaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: days,
                        items:
                            const [7, 14, 30, 90]
                                .map(
                                  (d) => DropdownMenuItem<int>(
                                    value: d,
                                    child: Text('Last $d days'),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            onDaysChanged(val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              SizedBox(
                height: chartHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width:
                        chartWidth > constraints.maxWidth
                            ? chartWidth
                            : constraints.maxWidth,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: (maxY == 0 ? 1 : maxY) * 1.2,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY > 0 ? maxY / 5 : 1,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: maxY > 0 ? maxY / 5 : 1,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: AppConstants.bodySmall,
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 ||
                                    idx >= entries.length ||
                                    idx % step != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _labelFor(entries[idx].key),
                                    style: AppConstants.bodySmall.copyWith(
                                      fontSize: isMobile ? 10 : 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppConstants.primaryColor,
                            barWidth: isMobile ? 2 : 3,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppConstants.primaryColor.withOpacity(
                                0.12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(String title) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _currentView = _AdminView.dashboard),
        ),
        Text(title, style: AppConstants.headingSmall),
      ],
    );
  }

  Widget _buildAllOrdersView() {
    if (_allOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          boxShadow: AppConstants.cardShadow,
        ),
        child: Center(
          child: Text('No orders found', style: AppConstants.bodyLarge),
        ),
      );
    }
    return Column(children: _allOrders.map((o) => _buildOrderCard(o)).toList());
  }

  Widget _buildReportsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatisticsOverview(),
        const SizedBox(height: AppConstants.spacingL),
        _buildPieChartsSection(),
        const SizedBox(height: AppConstants.spacingL),
        _buildOrdersByDateChart(
          days: _chartDays,
          allOrders: _allOrders,
          onDaysChanged: (days) {
            setState(() {
              _chartDays = days;
            });
          },
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
          Column(
            children: [
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
                      'Pending Orders',
                      _orderStats['pendingOrders']?.toString() ?? '0',
                      Icons.pending,
                      AppConstants.warningColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingM),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Completed Orders',
                      _orderStats['completedOrders']?.toString() ?? '0',
                      Icons.check_circle,
                      AppConstants.successColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Total Users',
                      _userStats['totalUsers']?.toString() ?? '0',
                      Icons.people,
                      AppConstants.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingM),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Active Users',
                      _userStats['activeUsers']?.toString() ?? '0',
                      Icons.person,
                      AppConstants.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ],
          ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
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
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingS,
          ),
          leading: Container(
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
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id.substring(0, 8)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppConstants.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppConstants.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Client: ${order.clientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondaryColor,
                      ),
                    ),
                  ],
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
          childrenPadding: const EdgeInsets.fromLTRB(
            AppConstants.spacingM,
            0,
            AppConstants.spacingM,
            AppConstants.spacingM,
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Created: ${_formatDate(order.createdAt)}',
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondaryColor,
                  ),
                ),
                if (order.updatedAt != null)
                  Text(
                    'Updated: ${_formatDate(order.updatedAt!)}',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondaryColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            if (order.orderType != null || order.orderDate != null)
              Row(
                children: [
                  if (order.orderType != null)
                    Text(
                      'Type: ${order.orderType!}',
                      style: AppConstants.bodySmall,
                    ),
                  if (order.orderType != null && order.orderDate != null)
                    const SizedBox(width: AppConstants.spacingL),
                  if (order.orderDate != null)
                    Text(
                      'Order Date: ${_formatDate(order.orderDate!)}',
                      style: AppConstants.bodySmall,
                    ),
                ],
              ),
            if (order.ornamentDetails.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'Ornament Details',
                style: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              ...order.ornamentDetails.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(d.name, style: AppConstants.bodyMedium),
                      ),
                      Text(
                        '${d.material} • ${d.purity}',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      Text(
                        '${d.weight}g x ${d.quantity}',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'Notes',
                style: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXS),
              Text(order.notes!, style: AppConstants.bodySmall),
            ],
            if (order.images.isNotEmpty || order.pdfs.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingM),
              if (order.images.isNotEmpty) ...[
                Text(
                  'Images',
                  style: AppConstants.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                _buildImageThumbnails(order.images),
                const SizedBox(height: AppConstants.spacingS),
              ],
              if (order.pdfs.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text('${order.pdfs.length} PDF(s)'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Widget _buildImageThumbnails(List<String> urls) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final url = urls[index];
          return GestureDetector(
            onTap: () => _showImagePreview(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
              child: Image.network(
                url,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
        separatorBuilder:
            (_, __) => const SizedBox(width: AppConstants.spacingS),
        itemCount: urls.length,
      ),
    );
  }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.all(AppConstants.spacingM),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.network(url, fit: BoxFit.contain),
            ),
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
