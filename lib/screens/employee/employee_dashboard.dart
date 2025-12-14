import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:soloshine/screens/common/pdf_viewer_screen.dart';
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
import 'order_detailed_screen.dart' show OrderDetailsScreen;
import 'package:intl/intl.dart';

// Add enum for sort options
enum OrderSortOption { dateDesc, dateAsc, priority }

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  List<Order> _assignedOrders = [];
  List<Order> _pendingOrders = [];
  bool _isLoading = true;
  OrderSortOption _pendingSortOption = OrderSortOption.dateDesc;

  @override
  void initState() {
    super.initState();
    // Defer to after first frame so Provider context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  bool _isUrgent(Order order) {
    final p = (order.orderPriority ?? '').toLowerCase().trim();
    return p == 'urgent' || p.contains('urgent');
  }

  Widget _buildUrgentRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.errorColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: const Text(
        'URGENT',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildPendingRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.warningColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
      ),
      child: const Text(
        'PENDING',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.Casted:
        return 'Casted';
      case OrderStatus.Wax:
        return 'Wax';
      case OrderStatus.DC:
        return 'DC';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.delay:
        return 'Delay';
      case OrderStatus.due:
        return 'Due';
      case OrderStatus.partialDelivery:
        return 'Partial Delivery';
      case OrderStatus.PendingDisp:
        return 'PendingDisp';
        case OrderStatus.Completed:
        return 'Completed';
       case OrderStatus.Delivered:
        return 'Delivered';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFF9800); // Orange
      case OrderStatus.Casted:
        return const Color(0xFF2196F3); // Blue
      case OrderStatus.Wax:
        return const Color(0xFF9C27B0); // Purple
      case OrderStatus.DC:
        return const Color(0xFF4CAF50); // Green
      case OrderStatus.cancelled:
        return const Color(0xFFF44336); // Red
      case OrderStatus.delay:
        return const Color.fromARGB(255, 0, 0, 0); // Red
      case OrderStatus.due:
        return const Color(0xFFF44336); // Red
      case OrderStatus.partialDelivery:
        return AppConstants.partialDeliveryColor;
      case OrderStatus.PendingDisp:
        return AppConstants.PendingDisp;
             case OrderStatus.Completed:
        return AppConstants.Completed;
         case OrderStatus.Delivered:
        return AppConstants.deliveredColor;
      
    }
  }

  String _formatDate(DateTime date) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('h:mm:ss a'); // 12-hour format with AM/PM
    return '${dateFormat.format(date)} ${timeFormat.format(date)}';
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

  // Helper to get sorted pending orders
  List<Order> get _sortedPendingOrders {
    List<Order> sorted = List.from(_pendingOrders);
    switch (_pendingSortOption) {
      case OrderSortOption.dateDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case OrderSortOption.dateAsc:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case OrderSortOption.priority:
        sorted.sort((a, b) {
          final aUrgent = _isUrgent(a) ? 0 : 1;
          final bUrgent = _isUrgent(b) ? 0 : 1;
          if (aUrgent != bUrgent) return aUrgent - bUrgent;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
    return sorted;
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
                      if (currentUser != null)
                        _buildWelcomeSection(currentUser),
                      const SizedBox(height: AppConstants.spacingL),
                      _buildQuickActions(),
                      const SizedBox(height: AppConstants.spacingL),
                      // _buildAssignedOrders(),
                      const SizedBox(height: AppConstants.spacingL),
                      _buildPendingOrders(),
                      const SizedBox(height: AppConstants.spacingL),
                      // _buildStatistics(),
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
            Row(
              children: [
                DropdownButton<OrderSortOption>(
                  value: _pendingSortOption,
                  underline: SizedBox.shrink(),
                  style: TextStyle(color: Colors.black, fontSize: 13),
                  items: const [
                    DropdownMenuItem(
                      value: OrderSortOption.dateDesc,
                      child: Text('Newest'),
                    ),
                    DropdownMenuItem(
                      value: OrderSortOption.dateAsc,
                      child: Text('Oldest'),
                    ),
                    DropdownMenuItem(
                      value: OrderSortOption.priority,
                      child: Text('Urgent First'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pendingSortOption = val;
                      });
                    }
                  },
                ),
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
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (_pendingOrders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No Pending Orders',
                  style: AppConstants.headingSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'All orders have been processed.',
                  style: AppConstants.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ..._sortedPendingOrders.map((order) => _buildOrderCard(order)),
      ],
    );
  }

  Widget _buildOrderCard(Order order) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailsScreen(order: order),
                  ),
                );
              },
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                childrenPadding: const EdgeInsets.all(20),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(order.status).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        order.images.isNotEmpty
                            ? Image.network(
                              order.images.first,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => Container(
                                    color: _getStatusColor(
                                      order.status,
                                    ).withOpacity(0.1),
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      color: _getStatusColor(order.status),
                                      size: 24,
                                    ),
                                  ),
                            )
                            : Container(
                              color: _getStatusColor(
                                order.status,
                              ).withOpacity(0.1),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                color: _getStatusColor(order.status),
                                size: 24,
                              ),
                            ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNo ?? order.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              order.status,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getStatusColor(
                                order.status,
                              ).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _getStatusText(order.status),
                            style: TextStyle(
                              color: _getStatusColor(order.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.clientName,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      order.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                         _formatDate(order.orderDate!),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (order.images.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 12,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${order.images.length}',
                                  style: TextStyle(
                                    color: Colors.green.shade600,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (order.updatedBy != null && order.updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Updated by ${order.updatedBy} on ${_formatDate(order.updatedAt!)}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (order.orderType != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (order.orderType != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                order.orderType!,
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    // Ornament Details Summary (outside expansion)
                    if (order.ornamentDetails.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        // decoration: BoxDecoration(
                        //   color: Colors.amber.withOpacity(0.08),
                        //   borderRadius: BorderRadius.circular(8),
                        //   border: Border.all(
                        //     color: Colors.amber.withOpacity(0.2),
                        //   ),
                        // ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: order.ornamentDetails.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final detail = entry.value;
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: idx < order.ornamentDetails.length - 1 ? 8 : 0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                // children: [
                                //   Container(
                                //     width: 6,
                                //     height: 6,
                                //     margin: const EdgeInsets.only(top: 4, right: 8),
                                //     decoration: const BoxDecoration(
                                //       color: Colors.amber,
                                //       shape: BoxShape.circle,
                                //     ),
                                //   ),
                                //   Expanded(
                                //     child: Column(
                                //       crossAxisAlignment: CrossAxisAlignment.start,
                                //       children: [
                                //         Text(
                                //           detail.name,
                                //           style: const TextStyle(
                                //             fontWeight: FontWeight.w600,
                                //             fontSize: 12,
                                //           ),
                                //         ),
                                //         Text(
                                //           '${detail.weight}g • ${detail.purity} • Qty: ${detail.quantity}',
                                //           style: TextStyle(
                                //             color: Colors.grey.shade600,
                                //             fontSize: 11,
                                //           ),
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                                // ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  CreateOrderScreen(orderToEdit: order),
                        ),
                      ).then((_) => _loadOrders());
                    } else if (value == 'status') {
                      _showStatusUpdateDialog(order);
                    
                    } else if (value == 'full_details') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => OrderDetailsScreen(order: order),
                        ),
                      );
                    }
                    //  else if (value == 'pdf') {
                    //   Navigator.push(
                    //     context,
                    //     MaterialPageRoute(
                    //       builder: (context) => PDFViewerScreen(order: order),
                    //     ),
                    //   );
                    // }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              const Text('Edit Order'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'status',
                          child: Row(
                            children: [
                              Icon(
                                Icons.sync_alt_rounded,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              const Text('Update Status'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'full_details',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              const Text('Full Details'),
                            ],
                          ),
                        ),
                        // if (order.orderType == 'Single')
                        //   PopupMenuItem(
                        //     value: 'delete',
                        //     child: Row(
                        //       children: [
                        //         Icon(
                        //           Icons.delete_outline_rounded,
                        //           size: 18,
                        //           color: Colors.red.shade600,
                        //         ),
                        //         const SizedBox(width: 12),
                        //         Text(
                        //           'Delete Order',
                        //           style: TextStyle(color: Colors.red.shade600),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // PopupMenuItem(
                        //   value: 'pdf',
                        //   child: Row(
                        //     children: [
                        //       Icon(
                        //         Icons.picture_as_pdf_outlined,
                        //         size: 18,
                        //         color: Colors.grey.shade600,
                        //       ),
                        //       const SizedBox(width: 12),
                        //       const Text('Generate PDF'),
                        //     ],
                        //   ),
                        // ),
                      ],
                ),
                children: [_buildExpandedContent(order)],
              ),
            ),
          ),
        ),
        // if (order.status == OrderStatus.pending)
        //   Positioned(top: 0, right: 0, child: _buildPendingRibbon()),
        if (_isUrgent(order))
          Positioned(top: 0, left: 0, child: _buildUrgentRibbon()),
      ],
    );
  }

  Widget _buildExpandedContent(Order order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // // Order Details Grid
          // _buildDetailSection('Order Information', [
          //   // _buildDetailItem('Order ID', order.id, Icons.tag_rounded),
          //   if (order.orderType != null)
          //     _buildDetailItem(
          //       'Type',
          //       order.orderType!,
          //       Icons.category_outlined,
          //     ),
          //   if (order.orderDate != null)
          //     _buildDetailItem(
          //       'Order Date',
          //       _formatDate(order.orderDate!),
          //       Icons.calendar_today_outlined,
          //     ),
          //   if (order.notes != null && order.notes!.isNotEmpty)
          //     _buildDetailItem('Notes', order.notes!, Icons.note_outlined),
          // ]),
          // Ornament details + images (alternating per ornament)
          if (order.ornamentDetails.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildDetailSection('Ornament Details', []),
            const SizedBox(height: 8),
            ...order.ornamentDetails.asMap().entries.map((entry) {
              final idx = entry.key;
              final detail = entry.value;
              final images =
                  detail.images.isNotEmpty ? detail.images : order.images;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Detail ${idx + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.amber.shade700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      detail.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOrnamentDetailRow('Weight', '${detail.weight} ${detail.unit ?? 'g'}'),
                    const SizedBox(height: 10),
                    _buildOrnamentDetailRow('Purity', detail.purity),
                    const SizedBox(height: 10),
                    _buildOrnamentDetailRow('Quantity', '${detail.quantity}'),
                    if (detail.size != null) ...[
                      const SizedBox(height: 10),
                      _buildOrnamentDetailRow('Size', detail.size!),
                    ],
                    if (detail.colorstone != null) ...[
                      const SizedBox(height: 10),
                      _buildOrnamentDetailRow('Colorstone', detail.colorstone!),
                    ],
                    if (detail.rhodium != null) ...[
                      const SizedBox(height: 10),
                      _buildOrnamentDetailRow('Rhodium', detail.rhodium!),
                    ],
                    if (detail.dull != null) ...[
                      const SizedBox(height: 10),
                      _buildOrnamentDetailRow('Dull', detail.dull!),
                    ],
                    if ((detail.remarks ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildOrnamentDetailRow('Remarks', detail.remarks!),
                    ],
                    // Partial Delivery entries
                    if (detail.partialDelivery != null &&
                        detail.partialDelivery!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Partial Delivery (${detail.partialDelivery!.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.teal.withOpacity(0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Header row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: const [
                                  Expanded(
                                    child: Text(
                                      'Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      'Qty',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Note',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...detail.partialDelivery!.map((pd) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(pd.deliverydate),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        pd.qty.toString(),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        pd.deliverynote?.isNotEmpty == true ? pd.deliverynote! : '-',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: pd.deliverynote?.isNotEmpty == true ? Colors.black87 : Colors.grey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                    // Images for this ornament
                    if (images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Images (${images.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            final imageUrl = images[index];
                            final isPdf = imageUrl.toLowerCase().endsWith('.pdf');
                            
                            return GestureDetector(
                              onTap: () => _showFullScreenImage(images, index),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: isPdf
                                      ? Container(
                                          color: Colors.red.shade50,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.picture_as_pdf,
                                                color: Colors.red.shade400,
                                                size: 40,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'PDF',
                                                style: TextStyle(
                                                  color: Colors.red.shade400,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade100,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.grey.shade400,
                                                    size: 32,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Error',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade400,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ] else if (order.images.isNotEmpty) ...[
            // Fallback: no ornament details, show order-level images
            const SizedBox(height: 20),
            _buildDetailSection('Images (${order.images.length})', []),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: order.images.length,
                itemBuilder: (context, index) {
                  final imageUrl = order.images[index];
                  final isPdf = imageUrl.toLowerCase().endsWith('.pdf');
                  
                  return GestureDetector(
                    onTap: () => _showFullScreenImage(order.images, index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: isPdf
                            ? Container(
                                color: Colors.red.shade50,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red.shade400,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'PDF',
                                      style: TextStyle(
                                        color: Colors.red.shade400,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade100,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey.shade400,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Error',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        if (children.isNotEmpty) ...[const SizedBox(height: 12), ...children],
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(List<String> images, int initialIndex) {
    final imageUrl = images[initialIndex];
    
    // Check if the URL is a PDF
    if (imageUrl.toLowerCase().endsWith('.pdf')) {
      // Open PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            pdfUrl: imageUrl,
            title: 'Order Document',
          ),
        ),
      );
    } else {
      // Open image viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => FullScreenImageViewer(
                images: images,
                initialIndex: initialIndex,
              ),
        ),
      );
    }
  }

  void _showStatusUpdateDialog(Order order) {
    OrderStatus? selectedStatus = order.status;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.sync_alt_rounded,
                    color: AppConstants.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Update Status'),
              ],
            ),
            content: StatefulBuilder(
              builder:
                  (context, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Current: ',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  order.status,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _getStatusColor(
                                    order.status,
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                order.status.toString().split('.').last,
                                style: TextStyle(
                                  color: _getStatusColor(order.status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'New Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonFormField<OrderStatus>(
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          value: selectedStatus,
                          items:
                              OrderStatus.values
                                  .map(
                                    (status) => DropdownMenuItem(
                                      value: status,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            margin: const EdgeInsets.only(
                                              right: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(status),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Text(
                                            status.toString().split('.').last,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedStatus = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedStatus != null &&
                      selectedStatus != order.status) {
                    Navigator.of(context).pop();
                    _updateOrderStatus(order, selectedStatus!);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      final token = AuthService.currentToken;
      if (token != null) {
        await OrderService.updateOrderStatus(
          orderId: order.id,
          newStatus: newStatus,
          token: token,
        );
        _loadOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Order status updated successfully'),
                ],
              ),
              backgroundColor: AppConstants.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        throw Exception('No authentication token');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Error updating order: $e'),
              ],
            ),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final Casted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text('Delete Order'),
              ],
            ),
            content: const Text(
              'Are you sure you want to delete this order? This action cannot be undone.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.errorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (Casted == true) {
      try {
        final token = AuthService.currentToken;
        if (token != null) {
          await OrderService.deleteOrder(orderId: orderId, token: token);
          _loadOrders();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Order deleted successfully'),
                ],
              ),
              backgroundColor: AppConstants.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Error deleting order: $e'),
              ],
            ),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildOrnamentDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
