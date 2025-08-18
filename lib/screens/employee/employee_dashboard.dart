import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../dashboard_screen.dart';
import 'manage_orders_screen.dart';
import 'create_client_screen.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  List<Order> _assignedOrders = [];
  List<Order> _pendingOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = context.read<AuthProvider>().currentUser;
      final token = AuthService.currentToken;

      if (currentUser != null && token != null) {
        final assignedOrders = await OrderService.getOrdersByEmployee(
          currentUser.id,
          token,
        );
        final pendingOrders = await OrderService.getOrdersByStatus(
          OrderStatus.pending,
          token,
        );

        setState(() {
          _assignedOrders = assignedOrders;
          _pendingOrders = pendingOrders;
          _isLoading = false;
        });
      } else {
        setState(() {
          _assignedOrders = [];
          _pendingOrders = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _assignedOrders = [];
        _pendingOrders = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;

    return DashboardScaffold(
      title: 'Muthaji - Employee Dashboard',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
      ],
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () async => _loadOrders(),
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

                      // Assigned Orders
                      _buildAssignedOrders(),

                      const SizedBox(height: AppConstants.spacingL),

                      // Pending Orders
                      _buildPendingOrders(),

                      const SizedBox(height: AppConstants.spacingL),

                      // Statistics
                      _buildStatistics(),
                    ],
                  ),
                ),
              ),
      floatingActionButtons: [
        FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateClientScreen(),
              ),
            );
            if (result == true) {
              // Refresh if needed
            }
          },
          label: const Text('New Client'),
          icon: const Icon(Icons.person_add),
          backgroundColor: AppConstants.successColor,
        ),
      ],
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
          colors: [AppConstants.accentColor, AppConstants.secondaryColor],
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
            'Manage orders and help clients with their requests',
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageOrdersScreen(),
                    ),
                  );
                },
                text: 'Manage Orders',
                icon: Icons.manage_accounts,
                backgroundColor: AppConstants.primaryColor,
                isFullWidth: true,
              ),
              const SizedBox(height: AppConstants.spacingM),
              CustomButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateClientScreen(),
                    ),
                  );
                  if (result == true) {
                    // Handle client creation
                  }
                },
                text: 'Create Client',
                icon: Icons.person_add,
                backgroundColor: AppConstants.successColor,
                isFullWidth: true,
              ),
            ],
          )
        else
          // Show buttons in a row on tablet/desktop
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageOrdersScreen(),
                      ),
                    );
                  },
                  text: 'Manage Orders',
                  icon: Icons.manage_accounts,
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
                        builder: (context) => const CreateClientScreen(),
                      ),
                    );
                    if (result == true) {
                      // Handle client creation
                    }
                  },
                  text: 'Create Client',
                  icon: Icons.person_add,
                  backgroundColor: AppConstants.successColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAssignedOrders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My Assigned Orders', style: AppConstants.headingSmall),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageOrdersScreen(),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (_assignedOrders.isEmpty)
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
                  Icons.assignment_ind,
                  size: 48,
                  color: AppConstants.textSecondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: AppConstants.spacingM),
                Text('No assigned orders', style: AppConstants.bodyLarge),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Orders will appear here when assigned to you',
                  style: AppConstants.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._assignedOrders
              .take(3)
              .map((order) => _buildOrderCard(order, true)),
      ],
    );
  }

  Widget _buildPendingOrders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pending Orders', style: AppConstants.headingSmall),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageOrdersScreen(),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (_pendingOrders.isEmpty)
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
                  Icons.pending,
                  size: 48,
                  color: AppConstants.textSecondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: AppConstants.spacingM),
                Text('No pending orders', style: AppConstants.bodyLarge),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'All orders have been processed',
                  style: AppConstants.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._pendingOrders
              .take(3)
              .map((order) => _buildOrderCard(order, false)),
      ],
    );
  }

  Widget _buildOrderCard(Order order, bool isAssigned) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
        border: Border.all(
          color:
              isAssigned
                  ? AppConstants.accentColor.withOpacity(0.3)
                  : AppConstants.warningColor.withOpacity(0.3),
          width: isAssigned ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.description,
                  style: AppConstants.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: AppConstants.spacingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client: ${order.clientName}',
                    style: AppConstants.bodyMedium.copyWith(
                      color: AppConstants.textSecondaryColor,
                    ),
                  ),
                  Text(
                    '\$${order.amount.toStringAsFixed(2)}',
                    style: AppConstants.bodyLarge.copyWith(
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Created: ${_formatDate(order.createdAt)}',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondaryColor,
                    ),
                  ),
                  if (isAssigned)
                    Container(
                      margin: const EdgeInsets.only(
                        top: AppConstants.spacingXS,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: AppConstants.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                      ),
                      child: Text(
                        'Assigned to you',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final totalAssigned = _assignedOrders.length;
    final pendingAssigned =
        _assignedOrders.where((o) => o.status == OrderStatus.pending).length;
    final inProgressAssigned =
        _assignedOrders.where((o) => o.status == OrderStatus.inProgress).length;
    final completedAssigned =
        _assignedOrders.where((o) => o.status == OrderStatus.completed).length;

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Statistics', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),
        if (isMobile)
          // Stack cards vertically on mobile
          Column(
            children: [
              _buildStatCard(
                'Total Assigned',
                totalAssigned.toString(),
                Icons.assignment_ind,
                AppConstants.primaryColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Pending',
                pendingAssigned.toString(),
                Icons.pending,
                AppConstants.warningColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'In Progress',
                inProgressAssigned.toString(),
                Icons.work,
                AppConstants.secondaryColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Completed',
                completedAssigned.toString(),
                Icons.check_circle,
                AppConstants.successColor,
              ),
            ],
          )
        else
          // Show cards in a grid on tablet/desktop
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Assigned',
                      totalAssigned.toString(),
                      Icons.assignment_ind,
                      AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Pending',
                      pendingAssigned.toString(),
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
                      'In Progress',
                      inProgressAssigned.toString(),
                      Icons.work,
                      AppConstants.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Completed',
                      completedAssigned.toString(),
                      Icons.check_circle,
                      AppConstants.successColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
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
}
