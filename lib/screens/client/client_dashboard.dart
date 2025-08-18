import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../dashboard_screen.dart';
import 'create_order_screen.dart';
import 'order_history_screen.dart';
import '../../services/auth_service.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  List<Order> _orders = [];
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
        final orders = await OrderService.getOrdersByClient(
          currentUser.id,
          token,
        );
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      } else {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _orders = [];
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
      title: 'Muthaji - Client Dashboard',
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

                      // Recent Orders
                      _buildRecentOrders(),

                      const SizedBox(height: AppConstants.spacingL),

                      // Order Statistics
                      _buildOrderStatistics(),
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
                builder: (context) => const CreateOrderScreen(),
              ),
            );
            if (result == true) {
              _loadOrders();
            }
          },
          label: const Text('New Order'),
          icon: const Icon(Icons.add),
          backgroundColor: AppConstants.primaryColor,
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
            'Welcome back, $displayName!',
            style: AppConstants.headingMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Manage your orders and track their progress',
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
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateOrderScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadOrders();
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
                      builder: (context) => const OrderHistoryScreen(),
                    ),
                  );
                },
                text: 'View History',
                icon: Icons.history,
                backgroundColor: AppConstants.accentColor,
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
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateOrderScreen(),
                      ),
                    );
                    if (result == true) {
                      _loadOrders();
                    }
                  },
                  text: 'Create Order',
                  icon: Icons.add_shopping_cart,
                  backgroundColor: AppConstants.successColor,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: CustomButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderHistoryScreen(),
                      ),
                    );
                  },
                  text: 'View History',
                  icon: Icons.history,
                  backgroundColor: AppConstants.accentColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    final recentOrders = _orders.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Orders', style: AppConstants.headingSmall),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderHistoryScreen(),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (recentOrders.isEmpty)
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
                  'Create your first order to get started',
                  style: AppConstants.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...recentOrders.map((order) => _buildOrderCard(order)),
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
                  color: order.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Text(
                  order.statusText,
                  style: AppConstants.bodySmall.copyWith(
                    color: order.statusColor,
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
              Text(
                '\$${order.amount.toStringAsFixed(2)}',
                style: AppConstants.bodyLarge.copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Created: ${_formatDate(order.createdAt)}',
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

  Widget _buildOrderStatistics() {
    final totalOrders = _orders.length;
    final pendingOrders =
        _orders.where((o) => o.status == OrderStatus.pending).length;
    final completedOrders =
        _orders.where((o) => o.status == OrderStatus.completed).length;
    final totalSpent = _orders
        .where((o) => o.status == OrderStatus.completed)
        .fold(0.0, (sum, order) => sum + order.amount);

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Statistics', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),
        if (isMobile)
          // Stack cards vertically on mobile
          Column(
            children: [
              _buildStatCard(
                'Total Orders',
                totalOrders.toString(),
                Icons.shopping_cart,
                AppConstants.primaryColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Pending',
                pendingOrders.toString(),
                Icons.pending,
                AppConstants.warningColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Completed',
                completedOrders.toString(),
                Icons.check_circle,
                AppConstants.successColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildStatCard(
                'Total Spent',
                '\$${totalSpent.toStringAsFixed(2)}',
                Icons.attach_money,
                AppConstants.accentColor,
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
                      'Total Orders',
                      totalOrders.toString(),
                      Icons.shopping_cart,
                      AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Pending',
                      pendingOrders.toString(),
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
                      'Completed',
                      completedOrders.toString(),
                      Icons.check_circle,
                      AppConstants.successColor,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Total Spent',
                      '\$${totalSpent.toStringAsFixed(2)}',
                      Icons.attach_money,
                      AppConstants.accentColor,
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
}
