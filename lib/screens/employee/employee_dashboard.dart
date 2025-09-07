import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../dashboard_screen.dart';
import 'manage_orders_screen.dart';
import '../client/create_order_screen.dart';

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
    setState(() => _isLoading = true);

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
        print("Saaigned ORDER=========>${assignedOrders.length}");
        setState(() {
          _assignedOrders = assignedOrders;
          _pendingOrders = pendingOrders;
          _isLoading = false;
        });
      } else {
        throw Exception('No user or token available');
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
      title: 'Employee Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadOrders,
          tooltip: 'Refresh',
        ),
      ],
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadOrders,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(currentUser!),
                      const SizedBox(height: AppConstants.spacingL),
                      _buildQuickActions(),
                      const SizedBox(height: AppConstants.spacingL),
                      // _buildAssignedOrders(),
                      const SizedBox(height: AppConstants.spacingL),
                      _buildPendingOrders(),
                      const SizedBox(height: AppConstants.spacingL),
                      _buildStatistics(),
                    ],
                  ),
                ),
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
              _loadOrders(); // Refresh orders after creation
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
    final displayName =
        user.name.isNotEmpty ? user.name : user.email.split('@')[0];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
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
            'Manage your orders and assist clients efficiently',
            style: AppConstants.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
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
        GridView.count(
          crossAxisCount: isMobile ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppConstants.spacingM,
          mainAxisSpacing: AppConstants.spacingM,
          childAspectRatio: isMobile ? 4 : 3,
          children: [
            CustomButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageOrdersScreen(),
                    ),
                  ),
              text: 'Manage Orders',
              icon: Icons.manage_accounts,
              backgroundColor: AppConstants.primaryColor,
              isFullWidth: true,
            ),
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
                  _loadOrders(); // Refresh orders after creation
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
          ],
        ),
      ],
    );
  }

  // Widget _buildAssignedOrders() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Text('My Assigned Orders', style: AppConstants.headingSmall),
  //           TextButton(
  //             onPressed: () => Navigator.push(
  //               context,
  //               MaterialPageRoute(builder: (context) => const ManageOrdersScreen()),
  //             ),
  //             child: const Text('View All'),
  //           ),
  //         ],
  //       ),
  //       const SizedBox(height: AppConstants.spacingM),
  //       if (_assignedOrders.isEmpty)
  //         _buildEmptyState('No Assigned Orders', 'Orders assigned to you will appear here.'),
  //       ..._assignedOrders.take(3).map((order) => _buildOrderCard(order, true)),
  //     ],
  //   );
  // }

  Widget _buildPendingOrders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pending Orders', style: AppConstants.headingSmall),
            TextButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageOrdersScreen(),
                    ),
                  ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (_pendingOrders.isEmpty)
          _buildEmptyState(
            'No Pending Orders',
            'All orders have been processed.',
          ),
        ..._pendingOrders.take(3).map((order) => _buildOrderCard(order, false)),
      ],
    );
  }

  Widget _buildOrderCard(Order order, bool isAssigned) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(order.status).withValues(alpha: 0.1),
          child: Icon(
            Icons.shopping_cart,
            color: _getStatusColor(order.status),
            size: 20,
          ),
        ),
        title: Text(
          order.description,
          style: AppConstants.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client: ${order.clientName}',
              style: AppConstants.bodyMedium.copyWith(
                color: AppConstants.textSecondaryColor,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingS,
            vertical: AppConstants.spacingXS,
          ),
          decoration: BoxDecoration(
            color: _getStatusColor(order.status).withValues(alpha: 0.1),
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
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderDetail('Order ID', order.id),
                if (order.orderType != null)
                  _buildOrderDetail('Type', order.orderType!),
                if (order.orderDate != null)
                  _buildOrderDetail(
                    'Order Date',
                    _formatDate(order.orderDate!),
                  ),
                if (order.notes != null && order.notes!.isNotEmpty)
                  _buildOrderDetail('Notes', order.notes!),
                if (order.ornamentDetails.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Ornament Details:',
                    style: AppConstants.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...order.ornamentDetails.map(
                    (detail) => Padding(
                      padding: const EdgeInsets.only(
                        left: AppConstants.spacingM,
                        top: AppConstants.spacingXS,
                      ),
                      child: Text(
                        '• ${detail.name} - ${detail.material} (${detail.weight}g, ${detail.purity}) x${detail.quantity}',
                        style: AppConstants.bodySmall,
                      ),
                    ),
                  ),
                ],
                if (order.images.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Images:',
                    style: AppConstants.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: order.images.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(
                            right: AppConstants.spacingS,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              order.images[index],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: AppConstants.textSecondaryColor
                                      .withValues(alpha: 0.1),
                                  child: const Icon(Icons.image_not_supported),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (isAssigned)
                  Padding(
                    padding: const EdgeInsets.only(top: AppConstants.spacingM),
                    child: CustomButton(
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageOrdersScreen(),
                            ),
                          ),
                      text: 'Manage Order',
                      backgroundColor: AppConstants.primaryColor,
                      isFullWidth: true,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppConstants.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppConstants.textSecondaryColor,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppConstants.bodyMedium)),
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
        GridView.count(
          crossAxisCount: isMobile ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppConstants.spacingM,
          mainAxisSpacing: AppConstants.spacingM,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Assigned',
              totalAssigned.toString(),
              Icons.assignment_ind,
              AppConstants.primaryColor,
            ),
            _buildStatCard(
              'Pending',
              pendingAssigned.toString(),
              Icons.pending,
              AppConstants.warningColor,
            ),
            _buildStatCard(
              'In Progress',
              inProgressAssigned.toString(),
              Icons.work,
              AppConstants.secondaryColor,
            ),
            _buildStatCard(
              'Completed',
              completedAssigned.toString(),
              Icons.check_circle,
              AppConstants.successColor,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppConstants.spacingS),
          Text(value, style: AppConstants.headingSmall.copyWith(color: color)),
          Text(
            title,
            style: AppConstants.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppConstants.textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(title, style: AppConstants.bodyLarge),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            subtitle,
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
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
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
