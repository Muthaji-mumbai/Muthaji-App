import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:soloshine/screens/common/pdf_viewer_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:soloshine/screens/client/order_image_generator.dart';
import 'package:soloshine/screens/client/pdfview.dart';
import 'package:soloshine/screens/employee/order_detailed_screen.dart';
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

class _ClientDashboardState extends State<ClientDashboard>
    with SingleTickerProviderStateMixin {
  List<Order> _orders = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _expandedOrderId; // Track expanded order

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _loadOrders();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return DashboardScaffold(
      logo: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        child: Image.asset(
          'assets/icons/logo.png',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
      ),
      title: 'Muthaji',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadOrders,
          tooltip: 'Refresh Orders',
          color: AppConstants.primaryColor,
        ),
      ],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: () async => _loadOrders(),
                  color: AppConstants.primaryColor,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppConstants.spacingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeSection(currentUser!),
                        const SizedBox(height: AppConstants.spacingXL),
                        if (!isMobile) _buildQuickActions(),
                        if (!isMobile)
                          const SizedBox(height: AppConstants.spacingXL),
                        _buildRecentOrders(),
                        const SizedBox(height: AppConstants.spacingXL),
                        if (!isMobile) _buildOrderStatistics(),
                      ],
                    ),
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
          elevation: 2,
          hoverElevation: 8,
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(User user) {
    final displayName =
        user.name.isNotEmpty ? user.name : user.email.split('@')[0];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingXL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryColor.withOpacity(0.9),
            AppConstants.secondaryColor.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $displayName!',
            style: AppConstants.headingMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppConstants.headingSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimaryColor,
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (isMobile)
          Column(
            children: [
              _buildActionButton(
                text: 'Create Order',
                icon: Icons.add_shopping_cart,
                color: AppConstants.successColor,
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
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildActionButton(
                text: 'View History',
                icon: Icons.history,
                color: AppConstants.accentColor,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  text: 'Create Order',
                  icon: Icons.add_shopping_cart,
                  color: AppConstants.successColor,
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
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: _buildActionButton(
                  text: 'View History',
                  icon: Icons.history,
                  color: AppConstants.accentColor,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderHistoryScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: CustomButton(
        onPressed: onPressed,
        text: text,
        icon: icon,
        backgroundColor: color,
        isFullWidth: true,
        textStyle: AppConstants.bodyLarge.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingM,
          horizontal: AppConstants.spacingL,
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    final recentOrders = _orders.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Orders',
              style: AppConstants.headingSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppConstants.textPrimaryColor,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              label: const Text('View All'),
              style: TextButton.styleFrom(
                foregroundColor: AppConstants.primaryColor,
                textStyle: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (recentOrders.isEmpty)
          _buildEmptyState()
        else
          _buildRecentOrdersList(recentOrders),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingXL * 2),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
          color: AppConstants.textSecondaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: AppConstants.primaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),
          Text(
            'No orders yet',
            style: AppConstants.headingSmall.copyWith(
              color: AppConstants.textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Create your first order to get started with our services',
            style: AppConstants.bodyMedium.copyWith(
              color: AppConstants.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingL),
          ElevatedButton.icon(
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
            icon: const Icon(Icons.add),
            label: const Text('Create Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingL,
                vertical: AppConstants.spacingM,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersList(List<Order> orders) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            decoration: BoxDecoration(
              color: AppConstants.backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.radiusL),
                topRight: Radius.circular(AppConstants.radiusL),
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder:
                (context, index) => Divider(
                  height: 1,
                  color: AppConstants.textSecondaryColor.withOpacity(0.1),
                ),
            itemBuilder: (context, index) {
              final order = orders[index];
              final isExpanded = _expandedOrderId == order.id;
              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedOrderId = isExpanded ? null : order.id;
                      });
                    },
                    child: _buildRecentOrderRow(order, isExpanded),
                  ),
                  if (isExpanded) _buildExpandedOrderDetails(order),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String? _getFirstImageUrl(Order order) {
    // Prefer per-ornament images
    for (final d in order.ornamentDetails) {
      if (d.images.isNotEmpty) return d.images.first;
    }
    // Fallback to order-level images
    if (order.images.isNotEmpty) return order.images.first;
    return null;
  }

  String _formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return _formatDate(date);
  }

 bool _isSingleOrder(Order order) {
  final orderType = order.orderType?.toLowerCase();
  return orderType == null || orderType == 'single';
}

Widget _buildRecentOrderRow(Order order, bool isExpanded) {
  return Stack(
    children: [
      Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        color: isExpanded ? AppConstants.backgroundColor.withOpacity(0.5) : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Builder(
                      builder: (context) {
                        final url = _getFirstImageUrl(order);
                        if (url == null || url.isEmpty) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          );
                        }
                        final isPdf = url.toLowerCase().endsWith('.pdf');
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isPdf
                              ? Container(
                                  color: Colors.red.shade50,
                                  child: Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red.shade400,
                                    size: 24,
                                  ),
                                )
                              : Image.network(
                                  url,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    flex: 4,
                    child: Text(
                      order.orderNo?.isNotEmpty == true
                          ? order.orderNo!
                          : order.id.substring(0, 8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppConstants.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      _formatFriendlyDate(order.orderDate ?? order.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  onSelected: (value) => _handleOrderAction(value, order),
                  itemBuilder: (context) {
                    final items = <PopupMenuItem<String>>[
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      // if (order.status == OrderStatus.pending)
                      //   const PopupMenuItem(
                      //     value: 'edit',
                      //     child: Row(
                      //       children: [
                      //         Icon(Icons.edit_outlined, size: 18),
                      //         SizedBox(width: 8),
                      //         Text('Edit'),
                      //       ],
                      //     ),
                      //   ),
                      if (_isSingleOrder(order)) // Add condition for clone
                        const PopupMenuItem(
                          value: 'clone',
                          child: Row(
                            children: [
                              Icon(Icons.content_copy_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Clone'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'image',
                        child: Row(
                          children: [
                            Icon(Icons.image_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Generate Image'),
                          ],
                        ),
                      ),
                      if (order.status == OrderStatus.pending) ...[
                      
                        // const PopupMenuItem(
                        //   value: 'cancel',
                        //   child: Row(
                        //     children: [
                        //       Icon(
                        //         Icons.cancel_outlined,
                        //         size: 18,
                        //         color: Colors.red,
                        //       ),
                        //       SizedBox(width: 8),
                        //       Text(
                        //         'Cancel',
                        //         style: TextStyle(color: Colors.red),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                      ],
                    ];
                    return items;
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppConstants.textSecondaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: AppConstants.textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (order.orderPriority?.toLowerCase() == 'urgent')
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'URGENT',
              style: AppConstants.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ),
      _buildStatusRibbon(order),
    ],
  );
}

  Widget _buildExpandedOrderDetails(Order order) {
  return Container(
    padding: const EdgeInsets.all(AppConstants.spacingL),
    decoration: BoxDecoration(
      color: AppConstants.backgroundColor,
      borderRadius: BorderRadius.circular(AppConstants.radiusM),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Container(
            //   padding: const EdgeInsets.symmetric(
            //     horizontal: AppConstants.spacingM,
            //     vertical: AppConstants.spacingS,
            //   ),
            //   decoration: BoxDecoration(
            //     color: order.statusColor.withOpacity(0.15),
            //     borderRadius: BorderRadius.circular(AppConstants.radiusS),
            //     border: Border.all(color: order.statusColor.withOpacity(0.3)),
            //   ),
            //   child: Text(
            //     order.statusText,
            //     style: AppConstants.bodySmall.copyWith(
            //       color: order.statusColor,
            //       fontWeight: FontWeight.w600,
            //     ),
            //   ),
            // ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (order.updatedAt != null)
                  Text(
                    'Updated: ${_formatDate(order.updatedAt!)}',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondaryColor,
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (order.orderDate != null)
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.spacingXS),
            child: Text(
              'Order Date: ${_formatDate(order.orderDate!)}',
              style: AppConstants.bodySmall,
            ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: AppConstants.bodyMedium),
                  const SizedBox(height: AppConstants.spacingXS),
                  Text(
                    'Weight: ${d.weight} • Unit: ${d.unit ?? 'g'} • Purity: ${d.purity} • Qty: ${d.quantity}${d.size != null ? ' • Size: ${d.size}' : ''} • Colorstone: ${d.colorstone} • Rhodium: ${d.rhodium} • Dull: ${d.dull}',
                    style: AppConstants.bodySmall.copyWith(
                      color: AppConstants.textSecondaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (d.remarks != null && d.remarks!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppConstants.spacingXS,
                      ),
                      child: Text(
                        'Remarks: ${d.remarks!}',
                        style: AppConstants.bodySmall,
                      ),
                    ),
                  if (d.partialDelivery != null && d.partialDelivery!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppConstants.spacingS,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppConstants.spacingS),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.teal.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  size: 14,
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Partial Delivery (${d.partialDelivery!.length})',
                                  style: AppConstants.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingXS),
                            ...d.partialDelivery!.map((pd) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy').format(pd.deliverydate),
                                    style: AppConstants.bodySmall,
                                  ),
                                  Text(
                                    'Qty: ${pd.qty}',
                                    style: AppConstants.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  if (d.images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppConstants.spacingXS,
                      ),
                      child: _buildImageThumbnails(d.images),
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
        const SizedBox(height: AppConstants.spacingM),
        Wrap(
          alignment: WrapAlignment.start,
          spacing: AppConstants.spacingS,
          runSpacing: AppConstants.spacingS,
          children: [
            // if (order.status == OrderStatus.pending)
            //   OutlinedButton.icon(
            //     onPressed: () async {
            //       final updated = await Navigator.push<bool>(
            //         context,
            //         MaterialPageRoute(
            //           builder: (context) => CreateOrderScreen(orderToEdit: order),
            //         ),
            //       );
            //       if (updated == true) _loadOrders();
            //     },
            //     icon: const Icon(Icons.edit_outlined, size: 18),
            //     label: const Text('Edit'),
            //   ),
            if (_isSingleOrder(order)) // Add condition for clone
              OutlinedButton.icon(
                onPressed: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateOrderScreen(
                        orderToEdit: order,
                        cloneFromOrder: true,
                      ),
                    ),
                  );
                  if (created == true) _loadOrders();
                },
                icon: const Icon(Icons.content_copy_outlined, size: 18),
                label: const Text('Clone'),
              ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderImageGenerator(order: order),
                ),
              ),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Generate Image'),
            ),
            // if (order.status == OrderStatus.pending)
            //   OutlinedButton.icon(
            //     onPressed: () => _cancelOrder(order),
            //     icon: const Icon(Icons.cancel_outlined, size: 18),
            //     label: const Text('Cancel'),
            //     style: OutlinedButton.styleFrom(
            //       foregroundColor: AppConstants.errorColor,
            //       side: BorderSide(
            //         color: AppConstants.errorColor.withOpacity(0.5),
            //       ),
            //     ),
            //   ),
          ],
        ),
      ],
    ),
  );
}

  void _handleOrderAction(String action, Order order) async {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailsScreen(order: order),
          ),
        );
        break;
      case 'edit':
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => CreateOrderScreen(orderToEdit: order),
          ),
        );
        if (updated == true) _loadOrders();
        break;
      case 'clone':
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    CreateOrderScreen(orderToEdit: order, cloneFromOrder: true),
          ),
        );
        if (created == true) _loadOrders();
        break;
      case 'image':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderImageGenerator(order: order),
          ),
        );
        break;
      case 'cancel':
        _cancelOrder(order);
        break;
    }
  }

  void _showOrderDetailsDialog(Order order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Order #${order.orderNo}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Status', order.statusText),
                  //
                  if (order.orderDate != null)
                    _buildDetailRow(
                      'Order Date',
                      _formatDate(order.orderDate!),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Ornament Details (${order.ornamentDetails.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...order.ornamentDetails.map(
                    (detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${detail.weight}${detail.unit ?? 'g'} • ${detail.purity} • Qty: ${detail.quantity}',
                          ),
                          if (detail.remarks?.isNotEmpty == true)
                            Text(
                              'Remarks: ${detail.remarks}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (detail.partialDelivery != null && detail.partialDelivery!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_shipping_outlined,
                                        size: 12,
                                        color: Colors.teal,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Partial Delivery (${detail.partialDelivery!.length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ...detail.partialDelivery!.map((pd) => Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat('dd MMM yyyy').format(pd.deliverydate),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        Text(
                                          'Qty: ${pd.qty}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (order.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Notes',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(order.notes!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _cancelOrder(Order order) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Cancel Order?'),
                content: const Text(
                  'Are you sure you want to cancel this order? This action cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm) return;

    final token = AuthService.currentToken;
    if (token == null) return;

    try {
      await OrderService.updateOrderStatus(
        orderId: order.id,
        newStatus: OrderStatus.cancelled,
        token: token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order cancelled successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      }
      _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildOrderHistoryList() {
    final historyOrders =
        _orders.length > 3 ? _orders.skip(3).toList() : <Order>[];
    if (historyOrders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order History',
          style: AppConstants.headingSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimaryColor,
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        ...historyOrders.map((order) => _buildOrderCard(order)),
      ],
    );
  }

  bool _isUrgent(Order order) {
    final p = (order.orderPriority ?? '').toLowerCase().trim();
    return p == 'urgent' || p.contains('urgent');
  }

  Widget _buildStatusRibbon(Order order) {
    // Show "In Progress" for Casted, Wax, DC, PendingDisp statuses
    final showInProgress = [
      OrderStatus.Casted,
      OrderStatus.Wax,
      OrderStatus.DC,
      OrderStatus.PendingDisp,
    ].contains(order.status);
    
    return Positioned(  
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: order.statusColor,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: order.statusColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          showInProgress ? 'IN PROGRESS' : order.statusText.toUpperCase(),
          style: AppConstants.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingS,
        vertical: 4,
      ),
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

  Widget _buildOrderCard(Order order) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
          padding: const EdgeInsets.all(AppConstants.spacingL),
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.orderNo}',
                      style: AppConstants.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingM,
                      vertical: AppConstants.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: order.statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                      border: Border.all(
                        color: order.statusColor.withOpacity(0.3),
                      ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppConstants.spacingS),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppConstants.spacingS,
                    runSpacing: AppConstants.spacingS,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            order.status == OrderStatus.pending
                                ? () async {
                                  final updated = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => CreateOrderScreen(
                                            orderToEdit: order,
                                          ),
                                    ),
                                  );
                                  if (updated == true) _loadOrders();
                                }
                                : null,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final created = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CreateOrderScreen(
                                    orderToEdit: order,
                                    cloneFromOrder: true,
                                  ),
                            ),
                          );
                          if (created == true) {
                            _loadOrders();
                          }
                        },
                        icon: const Icon(Icons.content_copy_outlined, size: 18),
                        label: const Text('Clone'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirm =
                              await showDialog<bool>(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: const Text('Cancel Order?'),
                                      content: const Text(
                                        'Are you sure you want to cancel this order? This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, false),
                                          child: const Text('No'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
                                          child: const Text('Yes'),
                                        ),
                                      ],
                                    ),
                              ) ??
                              false;
                          if (!confirm) return;
                          final token = AuthService.currentToken;
                          if (token == null) return;
                          try {
                            await OrderService.updateOrderStatus(
                              orderId: order.id,
                              newStatus: OrderStatus.cancelled,
                              token: token,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Order cancelled successfully',
                                  ),
                                  backgroundColor: AppConstants.successColor,
                                ),
                              );
                            }
                            _loadOrders();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to cancel order: $e'),
                                  backgroundColor: AppConstants.errorColor,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.errorColor,
                          side: BorderSide(
                            color: AppConstants.errorColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  if (order.orderDate != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppConstants.spacingXS,
                      ),
                      child: Text(
                        'Order Date: ${_formatDate(order.orderDate!)}',
                        style: AppConstants.bodySmall,
                      ),
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
                        padding: const EdgeInsets.only(
                          bottom: AppConstants.spacingS,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d.name,
                                    style: AppConstants.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingXS),
                            Text(
                              'Weight: ${d.weight} • Unit: ${d.unit ?? 'g'} • Purity: ${d.purity} • Qty: ${d.quantity}${d.size != null ? ' • Size: ${d.size}' : ''} • Colorstone: ${d.colorstone} • Rhodium: ${d.rhodium} • Dull: ${d.dull}',
                              style: AppConstants.bodySmall.copyWith(
                                color: AppConstants.textSecondaryColor,
                              ),
                            ),
                            if (d.remarks != null && d.remarks!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppConstants.spacingXS,
                                ),
                                child: Text(
                                  'Remarks: ${d.remarks!}',
                                  style: AppConstants.bodySmall,
                                ),
                              ),
                            if (d.partialDelivery != null && d.partialDelivery!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppConstants.spacingS,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(AppConstants.spacingS),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.teal.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.local_shipping_outlined,
                                            size: 14,
                                            color: Colors.teal,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Partial Delivery (${d.partialDelivery!.length})',
                                            style: AppConstants.bodySmall.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppConstants.spacingXS),
                                      ...d.partialDelivery!.map((pd) => Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat('dd MMM yyyy').format(pd.deliverydate),
                                              style: AppConstants.bodySmall,
                                            ),
                                            Text(
                                              'Qty: ${pd.qty}',
                                              style: AppConstants.bodySmall.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            if (d.images.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppConstants.spacingXS,
                                ),
                                child: _buildImageThumbnails(d.images),
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
                  Padding(
                    padding: const EdgeInsets.only(top: AppConstants.spacingM),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            OrderImageGenerator(order: order),
                                  ),
                                ),
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Generate Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppConstants.spacingM,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_isUrgent(order))
          Positioned(top: 0, left: 0, child: _buildUrgentRibbon()),
      ],
    );
  }

  Widget _buildImageThumbnails(List<String> images) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final url = images[index];
          final isPdf = url.toLowerCase().endsWith('.pdf');
          
          return GestureDetector(
            onTap: () => _showImagePreview(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
              child: AspectRatio(
                aspectRatio: 1,
                child: isPdf
                    ? Container(
                        color: Colors.red.shade50,
                        alignment: Alignment.center,
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
                        url,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stack) => Container(
                              color: AppConstants.backgroundColor,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image),
                            ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImagePreview(String url) async {
    // Check if the URL is a PDF
    if (url.toLowerCase().endsWith('.pdf')) {
      // Open PDF in external viewer
     Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            pdfUrl: url,
            title: 'Order Document',
          ),
        ),
      );

    } else {
      // Show image preview dialog
      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (context, error, stack) => SizedBox(
                              height: 300,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.broken_image, size: 40),
                                    SizedBox(height: 8),
                                    Text('Failed to load image'),
                                  ],
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
      );
    }
  }

  Widget _buildOrderStatistics() {
    final totalOrders = _orders.length;
    final pendingOrders =
        _orders.where((o) => o.status == OrderStatus.pending).length;
    final DCOrders = _orders.where((o) => o.status == OrderStatus.DC).length;
    final totalSpent = _orders
        .where((o) => o.status == OrderStatus.DC)
        .fold(0.0, (sum, order) => sum + order.amount);

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Statistics',
          style: AppConstants.headingSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimaryColor,
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (isMobile)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                _buildStatCard(
                  'Total Orders',
                  totalOrders.toString(),
                  Icons.shopping_cart,
                  AppConstants.primaryColor,
                ),
                const Spacer(),
                _buildStatCard(
                  'Pending',
                  pendingOrders.toString(),
                  Icons.pending,
                  AppConstants.warningColor,
                ),
                const SizedBox(height: AppConstants.spacingM),
              ],
            ),
          )
        else
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: 100,
        width: 100,
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              value,
              style: AppConstants.headingMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              title,
              style: AppConstants.bodyMedium.copyWith(
                color: AppConstants.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
