import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:soloshine/screens/admin/categorycreatescreen.dart';
import 'package:soloshine/screens/employee/manage_orders_screen.dart';
import 'package:soloshine/services/dashboard_service.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../models/user.dart';
import '../../models/order.dart';
import '../dashboard_screen.dart';
import '../client/create_order_screen.dart';
import 'user_management_screen.dart';

enum _AdminView { dashboard, reports }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic> _orderStats = {};
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _dashboardStats = {};
  // Removed unused _allOrders to satisfy lints
  List<User> _recentUsers = [];
  List<Order> _allOrders = [];
  bool _isLoading = true;
  bool _isLoadingGraphData = false;
  _AdminView _currentView = _AdminView.dashboard;
  int _chartDays = 7;

  // Chart visibility toggles
  bool _showSingleOrders = true;
  bool _showBulkOrders = true;
  bool _showTotalOrders = true;

  // Real data for the charts from API
  List<FlSpot> _singleOrdersData = [];
  List<FlSpot> _bulkOrdersData = [];
  List<FlSpot> _totalOrdersData = [];
  List<Map<String, dynamic>> _graphData = [];

  // Party/User filtering for reports
  String? _selectedUserId;

  String? _selectedUserName;
  List<User> _allUsers = [];
  bool _loadingUsers = false;
  bool _isLoadingOrders = false;

  // Date filtering for reports
  DateTime? _startDate;
  DateTime? _endDate;

  // Navigation bar for switching views
  Widget _buildNavigationBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingL),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentView = _AdminView.dashboard),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacingM,
                  horizontal: AppConstants.spacingL,
                ),
                decoration: BoxDecoration(
                  color:
                      _currentView == _AdminView.dashboard
                          ? AppConstants.primaryColor
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.dashboard,
                      color:
                          _currentView == _AdminView.dashboard
                              ? Colors.white
                              : AppConstants.textSecondaryColor,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Dashboard',
                      style: AppConstants.bodyMedium.copyWith(
                        color:
                            _currentView == _AdminView.dashboard
                                ? Colors.white
                                : AppConstants.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentView = _AdminView.reports),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacingM,
                  horizontal: AppConstants.spacingL,
                ),
                decoration: BoxDecoration(
                  color:
                      _currentView == _AdminView.reports
                          ? AppConstants.primaryColor
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics,
                      color:
                          _currentView == _AdminView.reports
                              ? Colors.white
                              : AppConstants.textSecondaryColor,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Reports',
                      style: AppConstants.bodyMedium.copyWith(
                        color:
                            _currentView == _AdminView.reports
                                ? Colors.white
                                : AppConstants.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadGraphData();
    _loadUsers(); // Load users for party filtering
  }

  Future<void> _loadGraphData() async {
    setState(() {
      _isLoadingGraphData = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token != null) {
        // Calculate date range based on selected days
        final endDate = DateTime.now();
        final startDate = endDate.subtract(Duration(days: _chartDays - 1));

        // Format dates as YYYY-MM-DD
        final startDateStr =
            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
        final endDateStr =
            '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

        final graphData = await AdminDashboardService.getGraphData(
          token,
          startDateStr,
          endDateStr,
        );

        if (!mounted) return;

        setState(() {
          _graphData = graphData;
          _processGraphData();
        });
      }
    } catch (e) {
      print('Error loading graph data: $e');
      // Set empty data on error
      if (mounted) {
        setState(() {
          _graphData = [];
          _singleOrdersData = [];
          _bulkOrdersData = [];
          _totalOrdersData = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGraphData = false;
        });
      }
    }
  }

  void _processGraphData() {
    _singleOrdersData = [];
    _bulkOrdersData = [];
    _totalOrdersData = [];

    for (int i = 0; i < _graphData.length; i++) {
      final data = _graphData[i];
      _singleOrdersData.add(
        FlSpot(i.toDouble(), (data['singleOrders'] ?? 0).toDouble()),
      );
      _bulkOrdersData.add(
        FlSpot(i.toDouble(), (data['bulkOrders'] ?? 0).toDouble()),
      );
      _totalOrdersData.add(
        FlSpot(i.toDouble(), (data['totalOrders'] ?? 0).toDouble()),
      );
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token != null) {
        final dashboardStats =
            await AdminDashboardService.getDashboardStatistics(token);
        _dashboardStats = dashboardStats;

        final users = await UserService.getAllUsers(token);
        _userStats = {
          'totalUsers': users.length,
          'activeUsers': users.where((u) => u.isActive).length,
          'adminUsers': users.where((u) => u.role == UserRole.admin).length,
          'employeeUsers':
              users.where((u) => u.role == UserRole.employee).length,
          'clientUsers': users.where((u) => u.role == UserRole.customer).length,
        };
        _recentUsers = users.take(5).toList();

        final orderStats = await OrderService.getOrderStatistics(token);
        final allOrders = await OrderService.getAllOrders(token);
        _orderStats = orderStats;
        _allOrders = allOrders;
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      // Set default values as in original code
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
        'WaxOrders': 0,
        'DCOrders': 0,
        'CastedOrders': 0,
        'cancelledOrders': 0,
        'completedOrders': 0,
        'Delivered': 0,
        'Partial Delivery': 0,
        'PendingDisp': 0,
        'totalRevenue': 0.0,
      };
      _dashboardStats = {
        'orderTypeCounts': {'single': 0, 'bulk': 0, 'total': 0},
        'statusCounts': {
          'pending': 0,
          'Wax': 0,
          'DC': 0,
          'cancelled': 0,
          'Delivered': 0,
        },
      };
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;
      if (token != null) {
        final users = await UserService.getAllUsers(token);
        // Show only customers for party selection
        setState(() {
          _allUsers = users.where((u) => u.role == UserRole.customer).toList();
          _loadingUsers = false;
        });
      }
    } catch (e) {
      setState(() => _loadingUsers = false);
      // Silently fail for user loading as it's not critical
    }
  }

  Future<void> _loadOrdersWithPartyFilter() async {
    setState(() {
      _isLoadingOrders = true; // Show loader
    });
    try {
      print('Selected party ID: $_selectedUserId');
      print('Selected party name: $_selectedUserName');
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token != null) {
        final allOrders = await OrderService.getAllOrders(
          token,
          partyname: _selectedUserId,
          startDate: _startDate,
          endDate: _endDate,
        );
        print('Fetched orders: $allOrders');
        if (!mounted) return;

        setState(() {
          _allOrders = allOrders;
          _isLoadingOrders = false; // Hide loader after data is loaded
        });
      }
    } catch (e) {
      print('Error loading orders with party filter: $e');
      if (mounted) {
        setState(() {
          _isLoadingOrders = false; // Hide loader on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final initialDate =
        isStartDate
            ? (_startDate ?? DateTime.now())
            : (_endDate ?? DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = pickedDate;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });
      await _loadOrdersWithPartyFilter(); // Reload orders with new dates
    }
  }

  void _clearDateFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadOrdersWithPartyFilter(); // Reload orders without date filters
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
          onPressed: () {
            _loadDashboardData();
            _loadGraphData();
          },
        ),
      ],
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
              color: Colors.white.withOpacity(0.85),
              colorBlendMode: BlendMode.srcOver,
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            RefreshIndicator(
              onRefresh: () async {
                await _loadDashboardData();
                await _loadGraphData();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentView == _AdminView.dashboard) ...[
                      // _buildWelcomeSection(currentUser!),
                      const SizedBox(height: AppConstants.spacingL),
                    ],
                    // Graph at the top
                    _buildOrderTrendsChart(),
                    const SizedBox(height: AppConstants.spacingL),
                    _buildNavigationBar(),
                    Builder(
                      builder: (context) {
                        switch (_currentView) {
                          case _AdminView.dashboard:
                            return _buildDashboardView();
                          case _AdminView.reports:
                            return _buildReportsView();
                        }
                      },
                    ),
                  ],
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

  Widget _buildOrderTrendsChart() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? AppConstants.spacingS : AppConstants.spacingM,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(159, 71, 214, 105),
            const Color.fromARGB(255, 75, 145, 77),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.all(
              isMobile ? AppConstants.spacingM : AppConstants.spacingL,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryColor.withOpacity(
                                    0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.trending_up,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacingS),
                              Flexible(
                                child: Text(
                                  'Order Analytics',
                                  style: AppConstants.headingMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: isMobile ? 18 : 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spacingXS),
                          Text(
                            'Track your business performance',
                            style: AppConstants.bodySmall.copyWith(
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingM,
                        vertical: AppConstants.spacingS,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusM,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _chartDays,
                          dropdownColor: const Color(0xFF1E293B),
                          style: AppConstants.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                          items:
                              const [7, 14, 30, 90]
                                  .map(
                                    (d) => DropdownMenuItem<int>(
                                      value: d,
                                      child: Text('$d days'),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _chartDays = val);
                              _loadGraphData();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingL),

                // Quick Stats Row
                // _buildQuickStatsRow(isMobile),
              ],
            ),
          ),

          // Chart Section
          Container(
            height: isMobile ? 280 : 320,
            padding: EdgeInsets.symmetric(
              horizontal:
                  isMobile ? AppConstants.spacingS : AppConstants.spacingM,
            ),
            child:
                _isLoadingGraphData
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppConstants.primaryColor,
                      ),
                    )
                    : _buildInteractiveLineChart(darkStyle: true),
          ),

          // Legend Section
          Container(
            padding: EdgeInsets.all(
              isMobile ? AppConstants.spacingM : AppConstants.spacingL,
            ),
            child:
                isMobile
                    ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactLegendButton(
                                'Single',
                                Colors.white,
                                _showSingleOrders,
                                () => setState(
                                  () => _showSingleOrders = !_showSingleOrders,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingS),
                            Expanded(
                              child: _buildCompactLegendButton(
                                'Bulk',
                                AppConstants.accentColor,
                                _showBulkOrders,
                                () => setState(
                                  () => _showBulkOrders = !_showBulkOrders,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.spacingS),
                        _buildCompactLegendButton(
                          'Total Orders',
                          AppConstants.secondaryColor,
                          _showTotalOrders,
                          () => setState(
                            () => _showTotalOrders = !_showTotalOrders,
                          ),
                        ),
                      ],
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCompactLegendButton(
                          'Single Orders',
                          AppConstants.primaryColor,
                          _showSingleOrders,
                          () => setState(
                            () => _showSingleOrders = !_showSingleOrders,
                          ),
                        ),
                        _buildCompactLegendButton(
                          'Bulk Orders',
                          AppConstants.accentColor,
                          _showBulkOrders,
                          () => setState(
                            () => _showBulkOrders = !_showBulkOrders,
                          ),
                        ),
                        _buildCompactLegendButton(
                          'Total Orders',
                          AppConstants.secondaryColor,
                          _showTotalOrders,
                          () => setState(
                            () => _showTotalOrders = !_showTotalOrders,
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLegendButton(
    String label,
    Color color,
    bool isVisible,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingM,
          vertical: AppConstants.spacingS,
        ),
        decoration: BoxDecoration(
          color:
              isVisible
                  ? color.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(
            color: isVisible ? color : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isVisible ? color : Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            Flexible(
              child: Text(
                label,
                style: AppConstants.bodySmall.copyWith(
                  color: isVisible ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveLineChart({bool darkStyle = false}) {
    List<LineChartBarData> lineBarsData = [];

    if (_showSingleOrders) {
      lineBarsData.add(
        LineChartBarData(
          spots: _singleOrdersData,
          isCurved: true,
          color: Colors.white,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter:
                (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: AppConstants.primaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppConstants.primaryColor.withValues(alpha: 0.25),
                AppConstants.primaryColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      );
    }

    if (_showBulkOrders) {
      lineBarsData.add(
        LineChartBarData(
          spots: _bulkOrdersData,
          isCurved: true,
          color: Colors.orange,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter:
                (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: AppConstants.accentColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppConstants.accentColor.withOpacity(0.25),
                AppConstants.accentColor.withOpacity(0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      );
    }

    if (_showTotalOrders) {
      lineBarsData.add(
        LineChartBarData(
          spots: _totalOrdersData,
          isCurved: true,
          color: AppConstants.secondaryColor,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter:
                (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4.5,
                  color: AppConstants.secondaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    if (lineBarsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _graphData.isEmpty
                  ? Icons.bar_chart_outlined
                  : Icons.visibility_off,
              size: 48,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              _graphData.isEmpty ? 'No data available' : 'No data visible',
              style: AppConstants.bodyLarge.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _graphData.isEmpty
                  ? 'No orders found for the selected period'
                  : 'Toggle the buttons below to show data',
              style: AppConstants.bodyMedium.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return LineChart(
      LineChartData(
        lineBarsData: lineBarsData,
        minX: 0,
        maxX: (_graphData.length - 1).toDouble(),
        minY: 0,
        maxY: _getMaxY(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _getYInterval(),
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: AppConstants.bodySmall.copyWith(
                    color:
                        darkStyle
                            ? Colors.white70
                            : AppConstants.textSecondaryColor,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _getXInterval(),
              getTitlesWidget: (value, meta) {
                final dayIndex = value.toInt();
                if (dayIndex < 0 || dayIndex >= _graphData.length)
                  return const SizedBox();

                // Use actual date from API data
                final dateStr = _graphData[dayIndex]['date'] as String?;
                if (dateStr != null) {
                  final date = DateTime.parse(dateStr);
                  return Text(
                    '${date.day}/${date.month}',
                    style: AppConstants.bodySmall.copyWith(
                      color:
                          darkStyle
                              ? Colors.white70
                              : AppConstants.textSecondaryColor,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: true,
          horizontalInterval: _getYInterval(),
          getDrawingHorizontalLine: (value) {
            final c =
                darkStyle
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2);
            return FlLine(color: c, strokeWidth: 1);
          },
          getDrawingVerticalLine: (value) {
            final c =
                darkStyle
                    ? Colors.white.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.15);
            return FlLine(color: c, strokeWidth: 0.5);
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color:
                  darkStyle
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
            ),
            left: BorderSide(
              color:
                  darkStyle
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBorder: BorderSide(color: Colors.grey.withOpacity(0.3)),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                String label = '';
                Color? color = touchedSpot.bar.color;

                if (touchedSpot.barIndex == 0 && _showSingleOrders) {
                  label = 'Single Orders';
                } else if ((touchedSpot.barIndex == 1 &&
                        _showBulkOrders &&
                        !_showSingleOrders) ||
                    (touchedSpot.barIndex == 1 &&
                        _showBulkOrders &&
                        _showSingleOrders)) {
                  label = 'Bulk Orders';
                } else if (_showTotalOrders) {
                  label = 'Total Orders';
                }

                return LineTooltipItem(
                  '$label\n${touchedSpot.y.toInt()}',
                  AppConstants.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _getMaxY() {
    double maxY = 0;
    if (_showSingleOrders) {
      maxY = _singleOrdersData.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    }
    if (_showBulkOrders) {
      final bulkMax = _bulkOrdersData
          .map((e) => e.y)
          .reduce((a, b) => a > b ? a : b);
      if (bulkMax > maxY) maxY = bulkMax;
    }
    if (_showTotalOrders) {
      final totalMax = _totalOrdersData
          .map((e) => e.y)
          .reduce((a, b) => a > b ? a : b);
      if (totalMax > maxY) maxY = totalMax;
    }
    return (maxY * 1.1).ceilToDouble(); // Add 10% padding
  }

  double _getYInterval() {
    final maxY = _getMaxY();
    if (maxY <= 10) return 2;
    if (maxY <= 50) return 10;
    if (maxY <= 100) return 20;
    return (maxY / 5).ceilToDouble();
  }

  double _getXInterval() {
    final dataLength = _graphData.length;
    if (dataLength <= 7) return 1;
    if (dataLength <= 30) return (dataLength / 7).ceilToDouble();
    return (dataLength / 10).ceilToDouble();
  }

  Widget _buildDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickActions(), // Moved quick actions higher for better accessibility
        const SizedBox(height: AppConstants.spacingL),
        _buildKPICards(),
        const SizedBox(height: AppConstants.spacingL),
        _buildRecentActivity(),
      ],
    );
  }

  Widget _buildKPICards() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    final kpiData = [
      {
        'title': 'Total Orders',
        'value': _orderStats['totalOrders']?.toString() ?? '0',
        'icon': Icons.shopping_cart,
        'color': AppConstants.primaryColor,
        'subtitle': 'All time',
      },
      {
        'title': 'Active Orders',
        'value':
            ((_orderStats['pendingOrders'] ?? 0) +
                    (_orderStats['WaxOrders'] ?? 0))
                .toString(),
        'icon': Icons.pending_actions,
        'color': AppConstants.warningColor,
        'subtitle': 'Wax',
      },
      {
        'title': 'DC',
        'value': _orderStats['DCOrders']?.toString() ?? '0',
        'icon': Icons.check_circle,
        'color': AppConstants.successColor,
        'subtitle': 'This month',
      },
      {
        'title': 'Total Users',
        'value': _userStats['totalUsers']?.toString() ?? '0',
        'icon': Icons.people,
        'color': AppConstants.accentColor,
        'subtitle': 'Registered',
        'onTap':
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserManagementScreen(),
              ),
            ),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Key Metrics', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),
        isMobile
            ? Column(
              children:
                  kpiData
                      .map(
                        (kpi) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppConstants.spacingM,
                          ),
                          child: _buildKPICard(kpi),
                        ),
                      )
                      .toList(),
            )
            : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppConstants.spacingL, // Increased spacing
              mainAxisSpacing: AppConstants.spacingL,
              childAspectRatio: 3, // Adjusted for better fit
              children: kpiData.map((kpi) => _buildKPICard(kpi)).toList(),
            ),
      ],
    );
  }

  Widget _buildKPICard(Map<String, dynamic> kpi) {
    final hasOnTap = kpi['onTap'] != null;

    return GestureDetector(
      onTap: hasOnTap ? kpi['onTap'] : null,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: AppConstants.cardShadow,
          border:
              hasOnTap
                  ? Border.all(
                    color: (kpi['color'] as Color).withOpacity(0.2),
                    width: 1,
                  )
                  : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: (kpi['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: Icon(
                kpi['icon'] as IconData,
                color: kpi['color'] as Color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kpi['value'] as String,
                    style: AppConstants.headingMedium.copyWith(
                      color: kpi['color'] as Color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    kpi['title'] as String,
                    style: AppConstants.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    kpi['subtitle'] as String,
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (hasOnTap)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppConstants.textSecondaryColor.withOpacity(0.6),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    final actions = [
      {
        'title': 'Manage Orders',
        'subtitle': 'View and update orders',
        'icon': Icons.assignment,
        'color': AppConstants.primaryColor,
        'onTap':
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageOrdersScreen(),
              ),
            ),
      },
      {
        'title': 'User Management',
        'subtitle': 'View and manage users',
        'icon': Icons.people_alt,
        'color': AppConstants.secondaryColor,
        'onTap':
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserManagementScreen(),
              ),
            ),
      },
      {
        'title': 'Create Category',
        'subtitle': 'Add new product category',
        'icon': Icons.category,
        'color': AppConstants.accentColor,
        'onTap': () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateCategoryScreen(),
            ),
          );
          if (!mounted) return;
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Category created successfully'),
                backgroundColor: AppConstants.successColor,
              ),
            );
          }
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),
        isMobile
            ? Column(
              children:
                  actions
                      .map(
                        (action) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppConstants.spacingM,
                          ),
                          child: _buildQuickActionCard(action),
                        ),
                      )
                      .toList(),
            )
            : GridView.count(
              crossAxisCount: 3, // Changed to 3 for desktop to spread out
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppConstants.spacingL,
              mainAxisSpacing: AppConstants.spacingL,
              childAspectRatio: 2.5, // Adjusted aspect ratio
              children:
                  actions
                      .map((action) => _buildQuickActionCard(action))
                      .toList(),
            ),
      ],
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    return GestureDetector(
      onTap: action['onTap'],
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: AppConstants.cardShadow,
          border: Border.all(
            color: (action['color'] as Color).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: (action['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: Icon(action['icon'], color: action['color'], size: 24),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action['title'],
                    style: AppConstants.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    action['subtitle'],
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppConstants.textSecondaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Users', style: AppConstants.headingSmall),
            TextButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserManagementScreen(),
                    ),
                  ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (_recentUsers.isEmpty)
          _buildEmptyState()
        else
          Column(
            children:
                _recentUsers
                    .take(5)
                    .map((user) => _buildRecentUserCard(user))
                    .toList(), // Increased to 5 for more info
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingXL),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
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
          Text(
            'No recent activity',
            style: AppConstants.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'New users will appear here',
            style: AppConstants.bodyMedium.copyWith(
              color: AppConstants.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentUserCard(User user) {
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserManagementScreen(),
            ),
          ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: AppConstants.cardShadow,
          border: Border.all(
            color: AppConstants.accentColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
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
                  ),
                  Text(
                    user.email,
                    style: AppConstants.bodyMedium.copyWith(
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
            const SizedBox(width: AppConstants.spacingS),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppConstants.textSecondaryColor.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsView() {
    print('Rendering Reports - Orders count: ${_allOrders.length}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPartySelectionSection(),
        const SizedBox(height: AppConstants.spacingL),
        if (_isLoadingOrders)
          const Center(
            child: CircularProgressIndicator(color: AppConstants.primaryColor),
          )
        else if (_allOrders.isEmpty)
          const Center(
            child: Text('No orders available for the selected party.'),
          )
        else ...[
          _buildDetailedStatistics(),
          const SizedBox(height: AppConstants.spacingL),
          _buildTypePieChartsSection(),
          const SizedBox(height: AppConstants.spacingL),
          // _buildTypeStatusBarCharts(),
          // const SizedBox(height: AppConstants.spacingL),
          _buildPieChartsSection(),
        ],
      ],
    );
  }

  Widget _buildPartySelectionSection() {
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
            children: [
              Icon(
                Icons.people_outline,
                color: AppConstants.primaryColor,
                size: 20,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                'Party Selection',
                style: AppConstants.headingSmall.copyWith(
                  color: AppConstants.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          _loadingUsers
              ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Loading customers...'),
                  ],
                ),
              )
              : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedUserId,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintText: 'Select a party to filter reports',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'All Parties',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    ..._allUsers.map(
                      (user) => DropdownMenuItem<String>(
                        value: user.id,
                        child: Text(user.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) async {
                    setState(() {
                      _selectedUserId = value;
                      _selectedUserName =
                          value != null
                              ? _allUsers.firstWhere((u) => u.id == value).name
                              : null;
                    });
                    print('Selected User ID: $_selectedUserId');
                    // Reload orders with party filter
                    await _loadOrdersWithPartyFilter();
                  },
                ),
              ),
          const SizedBox(height: AppConstants.spacingM),
          _buildDateFilterSection(),
        ],
      ),
    );
  }

  Widget _buildDateFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.date_range_outlined,
              color: AppConstants.primaryColor,
              size: 16,
            ),
            const SizedBox(width: AppConstants.spacingXS),
            Text(
              'Date Filter',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppConstants.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(isStartDate: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _startDate != null
                              ? '${_startDate!.day.toString().padLeft(2, '0')}/${_startDate!.month.toString().padLeft(2, '0')}/${_startDate!.year}'
                              : 'Start Date',
                          style: TextStyle(
                            color:
                                _startDate != null
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(isStartDate: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _endDate != null
                              ? '${_endDate!.day.toString().padLeft(2, '0')}/${_endDate!.month.toString().padLeft(2, '0')}/${_endDate!.year}'
                              : 'End Date',
                          style: TextStyle(
                            color:
                                _endDate != null
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            IconButton(
              onPressed: _clearDateFilters,
              icon: Icon(Icons.clear, size: 20, color: Colors.grey.shade600),
              tooltip: 'Clear dates',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypePieChartsSection() {
    // Orders are already filtered by party and date from API call
    // No need to filter again - just use _allOrders directly
    var filteredOrders = _allOrders;

    // Compute per type status counts from filtered orders
    int singlePending = 0,
        singleWax = 0,
        singleDC = 0,
        singleCancelled = 0,
        singleCompleted = 0,
        singleDelivered = 0,
        singleCasted = 0,
        singlePendingDisp = 0;

    int singleDelay = 0, singleDue = 0, singlePartialDelivery = 0;
    int bulkPending = 0,
        bulkWax = 0,
        bulkDC = 0,
        bulkCompleted = 0,
        bulkCancelled = 0,
        bulkDelivered = 0,
        bulkCasted = 0,
        bulkPendingDisp = 0;

    int bulkDelay = 0, bulkDue = 0, bulkPartialDelivery = 0;

    for (final o in filteredOrders) {
      final isSingle = (o.orderType ?? '').toLowerCase() == 'single';
      final isBulk = (o.orderType ?? '').toLowerCase() == 'bulk';
      if (!isSingle && !isBulk) continue; // skip unknown types

      void addTo(bool toSingle) {
        switch (o.status) {
          case OrderStatus.pending:
            toSingle ? singlePending++ : bulkPending++;
            break;
          case OrderStatus.Casted:
            toSingle ? singleCasted++ : bulkCasted++;
            break;
          case OrderStatus.Wax:
            toSingle ? singleWax++ : bulkWax++;
            break;
          case OrderStatus.DC:
            toSingle ? singleDC++ : bulkDC++;
            break;
          case OrderStatus.cancelled:
            toSingle ? singleCancelled++ : bulkCancelled++;
            break;
          case OrderStatus.delay:
            toSingle ? singleDelay++ : bulkDelay++;
            break;
          case OrderStatus.due:
            toSingle ? singleDue++ : bulkDue++;
            break;
          case OrderStatus.partialDelivery:
            toSingle ? singlePartialDelivery++ : bulkPartialDelivery++;
            break;
          case OrderStatus.PendingDisp:
            toSingle ? singlePendingDisp++ : bulkPendingDisp++;
            break;
          case OrderStatus.Completed:
            toSingle ? singleCompleted++ : bulkCompleted++;
            break;
          case OrderStatus.Delivered:
            toSingle ? singleDelivered++ : bulkDelivered++;
            break;
        }
      }

      if (isSingle) addTo(true);
      if (isBulk) addTo(false);
    }

    final singleData = [
      {
        'label': 'Pending',
        'value': singlePending.toDouble(),
        'color': AppConstants.warningColor,
      },
      {
        'label': 'Casted',
        'value': singleCasted.toDouble(),
        'color': AppConstants.accentColor,
      },
      {
        'label': 'Wax',
        'value': singleWax.toDouble(),
        'color': AppConstants.secondaryColor,
      },
      {
        'label': 'DC',
        'value': singleDC.toDouble(),
        'color': AppConstants.successColor,
      },
      {
        'label': 'Completed',
        'value': singleCompleted.toDouble(),
        'color': AppConstants.Completed,
      },
      {
        'label': 'Cancelled',
        'value': singleCancelled.toDouble(),
        'color': AppConstants.errorColor,
      },
      {
        'label': 'Delivered',
        'value': singleDelivered.toDouble(),
        'color': AppConstants.deliveredColor,
      },
      {
        'label': 'Pending Disp',
        'value': singlePendingDisp.toDouble(),
        'color': AppConstants.secondaryColor,
      },
    ];

    final bulkData = [
      {
        'label': 'Pending',
        'value': bulkPending.toDouble(),
        'color': AppConstants.warningColor,
      },
      {
        'label': 'Casted',
        'value': bulkCasted.toDouble(),
        'color': AppConstants.accentColor,
      },
      {
        'label': 'Wax',
        'value': bulkWax.toDouble(),
        'color': AppConstants.secondaryColor,
      },
      {
        'label': 'DC',
        'value': bulkDC.toDouble(),
        'color': AppConstants.successColor,
      },
      {
        'label': 'Completed',
        'value': bulkCompleted.toDouble(),
        'color': AppConstants.Completed,
      },
      {
        'label': 'Cancelled',
        'value': bulkCancelled.toDouble(),
        'color': AppConstants.errorColor,
      },
      {
        'label': 'Partial Delivery',
        'value': bulkPartialDelivery.toDouble(),
        'color': AppConstants.partialDeliveryColor,
      },
      {
        'label': 'Delivered',
        'value': bulkDelivered.toDouble(),
        'color': AppConstants.deliveredColor,
      },
      {
        'label': 'Pending Disp',
        'value': bulkPendingDisp.toDouble(),
        'color': AppConstants.secondaryColor,
      },
    ];

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Type Status Distribution',
          style: AppConstants.headingSmall,
        ),
        const SizedBox(height: AppConstants.spacingM),
        isMobile
            ? Column(
              children: [
                _buildPieChart(
                  title: 'Single Orders Status',
                  data: singleData,
                  onItemTap: _onSingleOrderStatusItemTap,
                ),
                const SizedBox(height: AppConstants.spacingL),
                _buildPieChart(
                  title: 'Bulk Orders Status',
                  data: bulkData,
                  onItemTap: _onBulkOrderStatusItemTap,
                ),
              ],
            )
            : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPieChart(
                    title: 'Single Orders Status',
                    data: singleData,
                    onItemTap: _onSingleOrderStatusItemTap,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingL),
                Expanded(
                  child: _buildPieChart(
                    title: 'Bulk Orders Status',
                    data: bulkData,
                    onItemTap: _onBulkOrderStatusItemTap,
                  ),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildTypeStatusBarCharts() {
    // Filter orders by selected party and date range
    var filteredOrders = _allOrders;

    // Filter by party
    if (_selectedUserId != null) {
      filteredOrders =
          filteredOrders
              .where((order) => order.clientId == _selectedUserId)
              .toList();
    }

    // Filter by date range
    if (_startDate != null) {
      filteredOrders =
          filteredOrders.where((order) {
            final orderDate = order.orderDate ?? order.createdAt;
            return orderDate.isAfter(
              _startDate!.subtract(const Duration(days: 1)),
            );
          }).toList();
    }

    if (_endDate != null) {
      filteredOrders =
          filteredOrders.where((order) {
            final orderDate = order.orderDate ?? order.createdAt;
            return orderDate.isBefore(_endDate!.add(const Duration(days: 1)));
          }).toList();
    }

    // Compute per type status counts from filtered orders
    int singlePending = 0,
        singleWax = 0,
        singleDC = 0,
        singleCompleted = 0,
        singleCancelled = 0,
        singleDelivered = 0,
        singleCasted = 0;

    int singleDelay = 0,
        singleDue = 0,
        singlePartialDelivery = 0,
        singlePendingDisp = 0;
    int bulkPending = 0,
        bulkWax = 0,
        bulkDC = 0,
        bulkCancelled = 0,
        bulkCompleted = 0,
        bulkDelivered = 0,
        bulkCasted = 0;
    int bulkDelay = 0,
        bulkDue = 0,
        bulkPartialDelivery = 0,
        bulkPendingDisp = 0;
    for (final o in filteredOrders) {
      final isSingle = (o.orderType ?? '').toLowerCase().contains('single');
      final isBulk = (o.orderType ?? '').toLowerCase().contains('bulk');
      if (!isSingle && !isBulk) continue; // skip unknown types

      void addTo(bool toSingle) {
        switch (o.status) {
          case OrderStatus.pending:
            toSingle ? singlePending++ : bulkPending++;
            break;
          case OrderStatus.Casted:
            toSingle ? singleCasted++ : bulkCasted++;
            break;
          case OrderStatus.Wax:
            toSingle ? singleWax++ : bulkWax++;
            break;
          case OrderStatus.DC:
            toSingle ? singleDC++ : bulkDC++;
            break;
          case OrderStatus.cancelled:
            toSingle ? singleCancelled++ : bulkCancelled++;
            break;
          case OrderStatus.delay:
            toSingle ? singleDelay++ : bulkDelay++;
            break;
          case OrderStatus.due:
            toSingle ? singleDue++ : bulkDue++;
            break;
          case OrderStatus.partialDelivery:
            toSingle ? singlePartialDelivery++ : bulkPartialDelivery++;
            break;
          case OrderStatus.PendingDisp:
            toSingle ? singlePendingDisp++ : bulkPendingDisp++;
            break;
          case OrderStatus.Completed:
            toSingle ? singleCompleted++ : bulkCompleted++;
            break;
          case OrderStatus.Delivered:
            toSingle ? singleDelivered++ : bulkDelivered++;
            break;
        }
      }

      if (isSingle) addTo(true);
      if (isBulk) addTo(false);
    }

    final singleData = [
      {
        'label': 'Pending',
        'value': singlePending.toDouble(),
        'color': AppConstants.warningColor,
      },
      {
        'label': 'Casted',
        'value': singleCasted.toDouble(),
        'color': AppConstants.accentColor,
      },
      {
        'label': 'Wax',
        'value': singleWax.toDouble(),
        'color': AppConstants.secondaryColor,
      },
      {
        'label': 'DC',
        'value': singleDC.toDouble(),
        'color': AppConstants.successColor,
      },
      {
        'label': 'Completed',
        'value': singleCompleted.toDouble(),
        'color': AppConstants.Completed,
      },
      {
        'label': 'Delivered',
        'value': singleDelivered.toDouble(),
        'color': AppConstants.deliveredColor,
      },
      {
        'label': 'Cancelled',
        'value': singleCancelled.toDouble(),
        'color': AppConstants.errorColor,
      },
      {
        'label': 'Partial Delivery',
        'value': singlePartialDelivery.toDouble(),
        'color': AppConstants.partialDeliveryColor,
      },
      {
        'label': 'Pending Disp',
        'value': singlePendingDisp.toDouble(),
        'color': AppConstants.secondaryColor,
      },
    ];

    final bulkData = [
      {
        'label': 'Pending',
        'value': bulkPending.toDouble(),
        'color': AppConstants.warningColor,
      },
      {
        'label': 'Casted',
        'value': bulkCasted.toDouble(),
        'color': AppConstants.accentColor,
      },
      {
        'label': 'Wax',
        'value': bulkWax.toDouble(),
        'color': AppConstants.secondaryColor,
      },
      {
        'label': 'DC',
        'value': bulkDC.toDouble(),
        'color': AppConstants.successColor,
      },
      {
        'label': 'Completed',
        'value': bulkCompleted.toDouble(),
        'color': AppConstants.Completed,
      },
      {
        'label': 'Delivered',
        'value': bulkDelivered.toDouble(),
        'color': AppConstants.deliveredColor,
      },
      {
        'label': 'Cancelled',
        'value': bulkCancelled.toDouble(),
        'color': AppConstants.errorColor,
      },
      {
        'label': 'Partial Delivery',
        'value': bulkPartialDelivery.toDouble(),
        'color': AppConstants.partialDeliveryColor,
      },
      {
        'label': 'Pending Disp',
        'value': bulkPendingDisp.toDouble(),
        'color': AppConstants.secondaryColor,
      },
    ];

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    Widget buildBar(String title, List<Map<String, dynamic>> data) {
      final total = data.fold<double>(
        0,
        (sum, item) => sum + (item['value'] as double),
      );
      return Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: AppConstants.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppConstants.headingSmall),
            const SizedBox(height: AppConstants.spacingM),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  barGroups:
                      data.asMap().entries.map((e) {
                        final idx = e.key;
                        final item = e.value;
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: (item['value'] as double),
                              color: item['color'] as Color,
                              width: 16,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= data.length)
                            return const SizedBox();
                          final label = data[idx]['label'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Transform.rotate(
                              angle: -math.pi / 6, // ~ -30 degrees
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: AppConstants.bodySmall.copyWith(
                                  color: AppConstants.textSecondaryColor,
                                ),
                                overflow: TextOverflow.visible,
                                softWrap: false,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval:
                        total <= 10
                            ? 2
                            : (total <= 50 ? 10 : (total / 5).ceilToDouble()),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return isMobile
        ? Column(
          children: [
            buildBar('Single Orders: Status Breakdown', singleData),
            const SizedBox(height: AppConstants.spacingL),
            buildBar('Bulk Orders: Status Breakdown', bulkData),
          ],
        )
        : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: buildBar('Single Orders: Status Breakdown', singleData),
            ),
            const SizedBox(width: AppConstants.spacingL),
            Expanded(
              child: buildBar('Bulk Orders: Status Breakdown', bulkData),
            ),
          ],
        );
  }

  Widget _buildPieChartsSection() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    // Orders are already filtered by party and date from API call
    // No need to filter again - just use _allOrders directly
    var filteredOrders = _allOrders;

    // Calculate filtered statistics - Fixed order type matching
    final orderTypeCounts = {
      'single':
          filteredOrders
              .where((o) => (o.orderType ?? '').toLowerCase() == 'single')
              .length,
      'bulk':
          filteredOrders
              .where((o) => (o.orderType ?? '').toLowerCase() == 'bulk')
              .length,
      'total': filteredOrders.length,
    };

    final statusCounts = {
      'pending':
          filteredOrders.where((o) => o.status == OrderStatus.pending).length,
      'Wax': filteredOrders.where((o) => o.status == OrderStatus.Wax).length,
      'DC': filteredOrders.where((o) => o.status == OrderStatus.DC).length,
      'Delivered':
          filteredOrders.where((o) => o.status == OrderStatus.Delivered).length,
      'cancelled':
          filteredOrders.where((o) => o.status == OrderStatus.cancelled).length,
      'completed':
          filteredOrders.where((o) => o.status == OrderStatus.Completed).length,
      'casted':
          filteredOrders.where((o) => o.status == OrderStatus.Casted).length,
      'partial delivery':
          filteredOrders
              .where((o) => o.status == OrderStatus.partialDelivery)
              .length,
      'pendingdisp':
          filteredOrders
              .where((o) => o.status == OrderStatus.PendingDisp)
              .length,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Distribution Analysis', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),
        isMobile
            ? Column(
              children: [
                // _buildPieChart(
                //   title: 'Order Status Distribution',
                //   data: [
                //     {
                //       'label': 'Pending',
                //       'value': statusCounts['pending']!.toDouble(),
                //       'color': AppConstants.warningColor,
                //     },
                //     {
                //       'label': 'Wax',
                //       'value': statusCounts['Wax']!.toDouble(),
                //       'color': AppConstants.secondaryColor,
                //     },
                //     {
                //       'label': 'DC',
                //       'value': statusCounts['DC']!.toDouble(),
                //       'color': AppConstants.successColor,
                //     },
                //     {
                //       'label': 'Delivered',
                //       'value': statusCounts['Delivered']!.toDouble(),
                //       'color': AppConstants.deliveredColor,
                //     },
                //     {
                //       'label': 'Cancelled',
                //       'value': statusCounts['cancelled']!.toDouble(),
                //       'color': AppConstants.errorColor,
                //     },
                //     {
                //       'label': 'Completed',
                //       'value': statusCounts['completed']!.toDouble(),
                //       'color': AppConstants.successColor,
                //     },
                //     {
                //       'label': 'Casted',
                //       'value': statusCounts['casted']!.toDouble(),
                //       'color': AppConstants.primaryColor,
                //     },
                //     {
                //       'label': 'Partial Delivery',
                //       'value': statusCounts['partial delivery']!.toDouble(),
                //       'color': AppConstants.warningColor,
                //     },
                //     {
                //       'label': 'Pending Disp',
                //       'value': statusCounts['pendingdisp']!.toDouble(),
                //       'color': AppConstants.secondaryColor,
                //     },
                //   ],
                //   onItemTap: _onStatusItemTap,
                // ),
                // const SizedBox(height: AppConstants.spacingL),
                _buildPieChart(
                  title: 'Order Type Distribution',
                  data: [
                    {
                      'label': 'Single Orders',
                      'value': orderTypeCounts['single']!.toDouble(),
                      'color': AppConstants.primaryColor,
                    },
                    {
                      'label': 'Bulk Orders',
                      'value': orderTypeCounts['bulk']!.toDouble(),
                      'color': AppConstants.accentColor,
                    },
                  ],
                  onItemTap: _onOrderTypeItemTap,
                ),
              ],
            )
            : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expanded(
                //   child: _buildPieChart(
                //     title: 'Order Status Distribution',
                //     data: [
                //       {
                //         'label': 'Pending',
                //         'value': statusCounts['pending']!.toDouble(),
                //         'color': AppConstants.warningColor,
                //       },
                //       {
                //         'label': 'Wax',
                //         'value': statusCounts['Wax']!.toDouble(),
                //         'color': AppConstants.secondaryColor,
                //       },
                //       {
                //         'label': 'DC',
                //         'value': statusCounts['DC']!.toDouble(),
                //         'color': AppConstants.successColor,
                //       },
                //       {
                //         'label': 'Delivered',
                //         'value': statusCounts['Delivered']!.toDouble(),
                //         'color': AppConstants.deliveredColor,
                //       },
                //       {
                //         'label': 'Cancelled',
                //         'value': statusCounts['cancelled']!.toDouble(),
                //         'color': AppConstants.errorColor,
                //       },
                //     ],
                //     onItemTap: _onStatusItemTap,
                //   ),
                // ),
                // const SizedBox(width: AppConstants.spacingL),
                Expanded(
                  child: _buildPieChart(
                    title: 'Order Type Distribution',
                    data: [
                      {
                        'label': 'Single Orders',
                        'value': orderTypeCounts['single']!.toDouble(),
                        'color': AppConstants.primaryColor,
                      },
                      {
                        'label': 'Bulk Orders',
                        'value': orderTypeCounts['bulk']!.toDouble(),
                        'color': AppConstants.accentColor,
                      },
                    ],
                    onItemTap: _onOrderTypeItemTap,
                  ),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildPieChart({
    required String title,
    required List<Map<String, dynamic>> data,
    Function(String label, Map<String, dynamic> item)? onItemTap,
  }) {
    final total = data.fold<double>(0, (sum, item) => sum + item['value']);
    final isEmpty = total == 0;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppConstants.headingSmall),
          const SizedBox(height: AppConstants.spacingL),
          isMobile
              ? Column(
                children: [
                  SizedBox(
                    height: 200,
                    child:
                        isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pie_chart_outline,
                                    size: 48,
                                    color: AppConstants.textSecondaryColor
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: AppConstants.spacingM),
                                  Text(
                                    'No data available',
                                    style: AppConstants.bodyMedium.copyWith(
                                      color: AppConstants.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : PieChart(
                              PieChartData(
                                sections:
                                    data
                                        .asMap()
                                        .entries
                                        .where((e) => e.value['value'] > 0)
                                        .map(
                                          (e) => PieChartSectionData(
                                            color: e.value['color'],
                                            value: e.value['value'],
                                            title:
                                                '${((e.value['value'] / total) * 100).toStringAsFixed(1)}%',
                                            titleStyle: AppConstants.bodySmall
                                                .copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            radius: 80,
                                          ),
                                        )
                                        .toList(),
                                centerSpaceRadius: 50,
                                sectionsSpace: 2,
                              ),
                            ),
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        data
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppConstants.spacingM,
                                ),
                                child: GestureDetector(
                                  onTap:
                                      onItemTap != null
                                          ? () => onItemTap(item['label'], item)
                                          : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color:
                                          onItemTap != null
                                              ? Colors.transparent
                                              : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: item['color'],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: AppConstants.spacingS,
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['label'],
                                                style: AppConstants.bodyMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              Text(
                                                '${item['value'].toInt()} orders',
                                                style: AppConstants.bodySmall
                                                    .copyWith(
                                                      color:
                                                          AppConstants
                                                              .textSecondaryColor,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (onItemTap != null)
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 12,
                                            color:
                                                AppConstants.textSecondaryColor,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 200,
                      child:
                          isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.pie_chart_outline,
                                      size: 48,
                                      color: AppConstants.textSecondaryColor
                                          .withOpacity(0.5),
                                    ),
                                    const SizedBox(
                                      height: AppConstants.spacingM,
                                    ),
                                    Text(
                                      'No data available',
                                      style: AppConstants.bodyMedium.copyWith(
                                        color: AppConstants.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : PieChart(
                                PieChartData(
                                  sections:
                                      data
                                          .asMap()
                                          .entries
                                          .where((e) => e.value['value'] > 0)
                                          .map(
                                            (e) => PieChartSectionData(
                                              color: e.value['color'],
                                              value: e.value['value'],
                                              title:
                                                  '${((e.value['value'] / total) * 100).toStringAsFixed(1)}%',
                                              titleStyle: AppConstants.bodySmall
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                              radius: 80,
                                            ),
                                          )
                                          .toList(),
                                  centerSpaceRadius: 50,
                                  sectionsSpace: 2,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingL),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          data
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppConstants.spacingM,
                                  ),
                                  child: GestureDetector(
                                    onTap:
                                        onItemTap != null
                                            ? () =>
                                                onItemTap(item['label'], item)
                                            : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color:
                                            onItemTap != null
                                                ? Colors.transparent
                                                : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: item['color'],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppConstants.spacingS,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['label'],
                                                  style: AppConstants.bodyMedium
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                Text(
                                                  '${item['value'].toInt()} orders',
                                                  style: AppConstants.bodySmall
                                                      .copyWith(
                                                        color:
                                                            AppConstants
                                                                .textSecondaryColor,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (onItemTap != null)
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 12,
                                              color:
                                                  AppConstants
                                                      .textSecondaryColor,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatistics() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    // Calculate stats dynamicallly from _allOrders to respect filters
    final totalOrders = _allOrders.length;
    final pendingOrders =
        _allOrders.where((o) => o.status == OrderStatus.pending).length;
    final waxOrders =
        _allOrders.where((o) => o.status == OrderStatus.Wax).length;
    final castedOrders =
        _allOrders.where((o) => o.status == OrderStatus.Casted).length;
    final dcOrders = _allOrders.where((o) => o.status == OrderStatus.DC).length;
    final pendingDispOrders =
        _allOrders.where((o) => o.status == OrderStatus.PendingDisp).length;
    final partialDeliveryOrders =
        _allOrders.where((o) => o.status == OrderStatus.partialDelivery).length;
    final completedOrders =
        _allOrders.where((o) => o.status == OrderStatus.Completed).length;
    final deliveredOrders =
        _allOrders.where((o) => o.status == OrderStatus.Delivered).length;
    final cancelledOrders =
        _allOrders.where((o) => o.status == OrderStatus.cancelled).length;

    // Calculate Single and Bulk counts
    final singleOrders =
        _allOrders
            .where((o) => (o.orderType ?? '').toLowerCase() == 'single')
            .length;
    final bulkOrders =
        _allOrders
            .where((o) => (o.orderType ?? '').toLowerCase() == 'bulk')
            .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detailed Statistics', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),
        isMobile
            ? Column(
              children: [
                _buildStatisticCard(
                  'Order Performance',
                  [
                    {'label': 'Total Orders', 'value': totalOrders.toString()},
                    {
                      'label': 'Single Orders',
                      'value': singleOrders.toString(),
                    },
                    {'label': 'Bulk Orders', 'value': bulkOrders.toString()},
                    {
                      'label': 'Pending Orders',
                      'value': pendingOrders.toString(),
                    },
                    {'label': 'Wax', 'value': waxOrders.toString()},
                    {'label': 'Casted', 'value': castedOrders.toString()},
                    {'label': 'DC', 'value': dcOrders.toString()},
                    {
                      'label': 'Pending Disp',
                      'value': pendingDispOrders.toString(),
                    },
                    {
                      'label': 'Partial Delivery',
                      'value': partialDeliveryOrders.toString(),
                    },
                    {'label': 'Completed', 'value': completedOrders.toString()},
                    {'label': 'Delivered', 'value': deliveredOrders.toString()},
                    {'label': 'Cancelled', 'value': cancelledOrders.toString()},
                  ],
                  Icons.analytics,
                  AppConstants.primaryColor,
                ),
                const SizedBox(height: AppConstants.spacingL),
                _buildStatisticCard(
                  'User Statistics',
                  [
                    {
                      'label': 'Total Users',
                      'value': _userStats['totalUsers']?.toString() ?? '0',
                    },
                    {
                      'label': 'Active Users',
                      'value': _userStats['activeUsers']?.toString() ?? '0',
                    },
                    {
                      'label': 'Admin Users',
                      'value': _userStats['adminUsers']?.toString() ?? '0',
                    },
                    {
                      'label': 'Employee Users',
                      'value': _userStats['employeeUsers']?.toString() ?? '0',
                    },
                    {
                      'label': 'Client Users',
                      'value': _userStats['clientUsers']?.toString() ?? '0',
                    },
                  ],
                  Icons.people,
                  AppConstants.accentColor,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserManagementScreen(),
                        ),
                      ),
                ),
              ],
            )
            : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildStatisticCard(
                    'Order Performance',
                    [
                      {
                        'label': 'Total Orders',
                        'value': totalOrders.toString(),
                      },
                      {
                        'label': 'Single Orders',
                        'value': singleOrders.toString(),
                      },
                      {'label': 'Bulk Orders', 'value': bulkOrders.toString()},
                      {
                        'label': 'Pending Orders',
                        'value': pendingOrders.toString(),
                      },
                      {'label': 'Wax', 'value': waxOrders.toString()},
                      {'label': 'Casted', 'value': castedOrders.toString()},
                      {'label': 'DC', 'value': dcOrders.toString()},
                      {
                        'label': 'Pending Disp',
                        'value': pendingDispOrders.toString(),
                      },
                      {
                        'label': 'Partial Delivery',
                        'value': partialDeliveryOrders.toString(),
                      },
                      {
                        'label': 'Completed',
                        'value': completedOrders.toString(),
                      },
                      {
                        'label': 'Delivered',
                        'value': deliveredOrders.toString(),
                      },
                      {
                        'label': 'Cancelled',
                        'value': cancelledOrders.toString(),
                      },
                    ],
                    Icons.analytics,
                    AppConstants.primaryColor,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingL),
                Expanded(
                  child: _buildStatisticCard(
                    'User Statistics',
                    [
                      {
                        'label': 'Total Users',
                        'value': _userStats['totalUsers']?.toString() ?? '0',
                      },
                      {
                        'label': 'Active Users',
                        'value': _userStats['activeUsers']?.toString() ?? '0',
                      },
                      {
                        'label': 'Admin Users',
                        'value': _userStats['adminUsers']?.toString() ?? '0',
                      },
                      {
                        'label': 'Employee Users',
                        'value': _userStats['employeeUsers']?.toString() ?? '0',
                      },
                      {
                        'label': 'Client Users',
                        'value': _userStats['clientUsers']?.toString() ?? '0',
                      },
                    ],
                    Icons.people,
                    AppConstants.accentColor,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserManagementScreen(),
                          ),
                        ),
                  ),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildStatisticCard(
    String title,
    List<Map<String, String>> stats,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: AppConstants.cardShadow,
          border: Border.all(
            color: color.withOpacity(onTap != null ? 0.3 : 0.2),
            width: onTap != null ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingS),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: Text(
                    title,
                    style: AppConstants.headingSmall.copyWith(color: color),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: color.withOpacity(0.6),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            ...stats.map(
              (stat) => Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        stat['label']!,
                        style: AppConstants.bodyMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: AppConstants.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                      ),
                      child: Text(
                        stat['value']!,
                        style: AppConstants.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods remain the same
  // Removed unused helpers (_formatDate, _getStatusText, _getStatusColor) to satisfy lints

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.employee:
        return 'Employee';
      case UserRole.customer:
        return 'Client';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppConstants.errorColor;
      case UserRole.employee:
        return AppConstants.accentColor;
      case UserRole.customer:
        return AppConstants.primaryColor;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.employee:
        return Icons.work;
      case UserRole.customer:
        return Icons.person;
    }
  }

  // Navigation callback methods for pie chart items
  void _onStatusItemTap(String label, Map<String, dynamic> item) {
    OrderStatus? status;

    // Map the label to OrderStatus enum
    switch (label.toLowerCase()) {
      case 'pending':
        status = OrderStatus.pending;
        break;
      case 'casted':
        status = OrderStatus.Casted;
        break;
      case 'completed':
        status = OrderStatus.Completed;
        break;
      case 'wax':
        status = OrderStatus.Wax;
        break;

      case 'dc':
        status = OrderStatus.DC;
        break;
      case 'cancelled':
        status = OrderStatus.cancelled;
        break;
      case 'delay':
        status = OrderStatus.delay;
        break;
      case 'due':
        status = OrderStatus.due;
        break;
      case 'partial delivery':
        status = OrderStatus.partialDelivery;
        break;
      case 'delivered':
        status = OrderStatus.Delivered;
        break;
      case 'pendingdisp':
      case 'pending disp':
        status = OrderStatus.PendingDisp;
        break;
      default:
        status = null;
    }

    // Navigate to ManageOrdersScreen with the selected status filter
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageOrdersScreen(initialStatus: status),
      ),
    );
  }

  void _onOrderTypeItemTap(String label, Map<String, dynamic> item) {
    String? orderType;

    // Map the label to order type
    switch (label.toLowerCase()) {
      case 'single orders':
        orderType = 'Single';
        break;
      case 'bulk orders':
        orderType = 'Bulk';
        break;
      default:
        orderType = null;
    }

    // Navigate to ManageOrdersScreen with the selected order type filter
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageOrdersScreen(initialOrderType: orderType),
      ),
    );
  }

  // Navigation callback methods for single order status items
  void _onSingleOrderStatusItemTap(String label, Map<String, dynamic> item) {
    OrderStatus? status;

    // Map the label to OrderStatus enum
    switch (label.toLowerCase()) {
      case 'pending':
        status = OrderStatus.pending;
        break;
      case 'casted':
        status = OrderStatus.Casted;
        break;
      case 'completed':
        status = OrderStatus.Completed;
        break;
      case 'wax':
        status = OrderStatus.Wax;
        break;
      case 'dc':
        status = OrderStatus.DC;
        break;
      case 'cancelled':
        status = OrderStatus.cancelled;
        break;
      case 'delay':
        status = OrderStatus.delay;
        break;
      case 'due':
        status = OrderStatus.due;
        break;
      case 'delivered':
        status = OrderStatus.Delivered;
        break;
      case 'partial delivery':
        status = OrderStatus.partialDelivery;
        break;
      case 'pendingdisp':
      case 'pending disp':
        status = OrderStatus.PendingDisp;
        break;
      default:
        status = null;
    }

    // Navigate to ManageOrdersScreen with status, Single order type, and party filters
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ManageOrdersScreen(
              initialStatus: status,
              initialOrderType: 'Single',
              initialUserId: _selectedUserId,
              initialUserName: _selectedUserName,
              initialStartDate: _startDate,
              initialEndDate: _endDate,
            ),
      ),
    );
  }

  // Navigation callback methods for bulk order status items
  void _onBulkOrderStatusItemTap(String label, Map<String, dynamic> item) {
    OrderStatus? status;

    // Map the label to OrderStatus enum
    switch (label.toLowerCase()) {
      case 'pending':
        status = OrderStatus.pending;
        break;
      case 'casted':
        status = OrderStatus.Casted;
        break;
      case 'wax':
        status = OrderStatus.Wax;
        break;
      case 'dc':
        status = OrderStatus.DC;
        break;
      case 'cancelled':
        status = OrderStatus.cancelled;
        break;
      case 'completed':
        status = OrderStatus.Completed;
        break;
      case 'delay':
        status = OrderStatus.delay;
        break;
      case 'due':
        status = OrderStatus.due;
        break;
      case 'partial delivery':
        status = OrderStatus.partialDelivery;
        break;
      case 'pendingdisp':
      case 'pending disp':
        status = OrderStatus.PendingDisp;
        break;
      case 'delivered':
        status = OrderStatus.Delivered;
        break;
      default:
        status = null;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ManageOrdersScreen(
              initialStatus: status,
              initialOrderType: 'Bulk',
              initialUserId: _selectedUserId,
              initialUserName: _selectedUserName,
              initialStartDate: _startDate,
              initialEndDate: _endDate,
            ),
      ),
    );
  }
}
