import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:soloshine/screens/client/order_image_generator.dart';
import 'package:soloshine/screens/client/pdfview.dart';
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
          // Sort by newest first for a proper "Recent Orders" view
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
                        // Welcome Section
                        _buildWelcomeSection(currentUser!),

                        const SizedBox(height: AppConstants.spacingXL),

                        // Quick Actions (hidden on mobile)
                        if (!isMobile) _buildQuickActions(),

                        if (!isMobile)
                          const SizedBox(height: AppConstants.spacingXL),

                        // Recent Orders
                        _buildRecentOrders(),

                        const SizedBox(height: AppConstants.spacingXL),

                        // Order Statistics (hidden on mobile)
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
          // Text(
          //   'Manage your orders with ease and track their progress in real-time.',
          //   style: AppConstants.bodyMedium.copyWith(
          //     color: Colors.white.withOpacity(0.9),
          //     fontSize: 16,
          //   ),
          // ),
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
    final recentOrders = _orders.take(3).toList();

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
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderHistoryScreen(),
                  ),
                );
              },
              child: Text(
                'View All',
                style: AppConstants.bodyMedium.copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        if (recentOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingXL),
            decoration: BoxDecoration(
              color: AppConstants.surfaceColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusL),
              border: Border.all(
                color: AppConstants.textSecondaryColor.withOpacity(0.2),
              ),
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
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 56,
                  color: AppConstants.textSecondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: AppConstants.spacingM),
                Text(
                  'No orders yet',
                  style: AppConstants.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Create your first order to get started',
                  style: AppConstants.bodyMedium.copyWith(
                    color: AppConstants.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = ResponsiveBreakpoints.of(context).isMobile;
              if (isMobile) {
                return Column(
                  children: [
                    for (final order in recentOrders)
                      _buildOrderCard(order),
                  ],
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppConstants.spacingM,
                  crossAxisSpacing: AppConstants.spacingM,
                  childAspectRatio: 1.9,
                ),
                itemCount: recentOrders.length,
                itemBuilder: (context, index) => _buildOrderCard(recentOrders[index]),
              );
            },
          ),
        const SizedBox(height: AppConstants.spacingXL),
        _buildOrderHistoryList(),
      ],
    );
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
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
          padding: const EdgeInsets.all(AppConstants.spacingL),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order ID + Status
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
                  // Space for top separation
                  const SizedBox(height: AppConstants.spacingS),

                  // Quick actions (Edit, Clone, Cancel) like Order History
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppConstants.spacingS,
                    runSpacing: AppConstants.spacingS,
                    children: [
                      OutlinedButton.icon(
                        onPressed: order.status == OrderStatus.pending
                            ? () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateOrderScreen(orderToEdit: order),
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
                              builder: (context) => CreateOrderScreen(
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
                          final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
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
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.errorColor,
                          side: BorderSide(color: AppConstants.errorColor.withOpacity(0.5)),
                        ),
                      ),
                    ],
                  ),

                  // Created/Updated detailed
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

                  // Order date
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

                  // Ornament details
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

                  // Notes
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

                  // Attachments info
                  // if (order.images.isNotEmpty || order.pdfs.isNotEmpty) ...[
                  //   const SizedBox(height: AppConstants.spacingM),
                  //   if (order.images.isNotEmpty) ...[
                  //     Text('Imagess',
                  //         style: AppConstants.bodyMedium
                  //             .copyWith(fontWeight: FontWeight.w700)),
                  //     const SizedBox(height: AppConstants.spacingS),
                  //     _buildImageThumbnails(order.images),
                  //     const SizedBox(height: AppConstants.spacingM),
                  //   ],
                  //   if (order.pdfs.isNotEmpty)
                  //     Chip(
                  //       avatar: const Icon(Icons.picture_as_pdf, size: 18),
                  //       label: Text('${order.pdfs.length} PDF(s)'),
                  //     ),
                  // ],

                  // Generate Actions (PDF / Image) row to match Order History
                  Padding(
                    padding: const EdgeInsets.only(top: AppConstants.spacingM),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PDFViewerScreen(order: order),
                              ),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Generate PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryColor,
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
                        const SizedBox(width: AppConstants.spacingM),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderImageGenerator(order: order),
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

                // const SizedBox(height: AppConstants.spacingS),

                // // Description (full)
                // Text(
                //   order.description,
                //   style: AppConstants.bodyLarge.copyWith(
                //     color: AppConstants.textPrimaryColor,
                //     fontWeight: FontWeight.w600,
                //   ),
                // ),

                // const SizedBox(height: AppConstants.spacingM),

                // // Amount and Dates
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [

                //     Column(
                //       crossAxisAlignment: CrossAxisAlignment.end,
                //       children: [
                //         Text(
                //           'Created: ${_formatDate(order.createdAt)}',
                //           style: AppConstants.bodySmall.copyWith(
                //             color: AppConstants.textSecondaryColor,
                //           ),
                //         ),
                //         if (order.updatedAt != null)
                //           Text(
                //             'Updated: ${_formatDate(order.updatedAt!)}',
                //             style: AppConstants.bodySmall.copyWith(
                //               color: AppConstants.textSecondaryColor,
                //             ),
                //           ),
                //       ],
                //     ),
                //   ],
                // ),

                // const SizedBox(height: AppConstants.spacingM),

                // // Order type/date
                // if (order.orderType != null || order.orderDate != null)
                //   Row(
                //     children: [
                //       if (order.orderType != null)
                //         Text('Type: ${order.orderType!}', style: AppConstants.bodySmall),
                //       if (order.orderType != null && order.orderDate != null)
                //         const SizedBox(width: AppConstants.spacingL),
                //       if (order.orderDate != null)
                //         Text('Order Date: ${_formatDate(order.orderDate!)}',
                //             style: AppConstants.bodySmall),
                //     ],
                //   ),

                // // Ornament details
                // if (order.ornamentDetails.isNotEmpty) ...[
                //   const SizedBox(height: AppConstants.spacingM),
                //   Text('Ornament Details',
                //       style: AppConstants.bodyMedium.copyWith(
                //         fontWeight: FontWeight.w700,
                //       )),
                //   const SizedBox(height: AppConstants.spacingS),
                //   ...order.ornamentDetails.map((d) => Padding(
                //         padding: const edgeInsets.only(bottom: AppConstants.spacingS),
                //         child: Row(
                //           children: [
                //             Expanded(
                //               child: Text(
                //                 d.name,
                //                 style: AppConstants.bodyMedium,
                //               ),
                //             ),
                //             Text('${d.material} • ${d.purity}',
                //                 style: AppConstants.bodySmall
                //                     .copyWith(color: AppConstants.textSecondaryColor)),
                //             const SizedBox(width: AppConstants.spacingM),
                //             Text('${d.weight}g x ${d.quantity}',
                //                 style: AppConstants.bodySmall
                //                     .copyWith(color: AppConstants.textSecondaryColor)),
                //           ],
                //         ),
                //       )),
                // ],

                // // Notes
                // if (order.notes != null && order.notes!.isNotEmpty) ...[
                //   const SizedBox(height: AppConstants.spacingM),
                //   Text('Notes',
                //       style: AppConstants.bodyMedium.copyWith(
                //         fontWeight: FontWeight.w700,
                //       )),
                //   const SizedBox(height: AppConstants.spacingXS),
                //   Text(order.notes!, style: AppConstants.bodySmall),
                // ],

                // // Attachments with thumbnails (similar to Order History)
                // if (order.images.isNotEmpty || order.pdfs.isNotEmpty) ...[
                //   const SizedBox(height: AppConstants.spacingM),
                //   if (order.images.isNotEmpty) ...[
                //     Text('Images',
                //         style:
                //             AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                //     const SizedBox(height: AppConstants.spacingS),
                //     _buildImageThumbnails(order.images),
                //   ],
                //   if (order.pdfs.isNotEmpty) ...[
                //     const SizedBox(height: AppConstants.spacingM),
                //     Chip(
                //       avatar: const Icon(Icons.picture_as_pdf, size: 18),
                //       label: Text('${order.pdfs.length} PDF(s)'),
                //     ),
                //   ],
                // ],
              ),
            ],
          ),
        ),
        if (_isUrgent(order))
          Positioned(top: 0, left: 0, child: _buildUrgentRibbon()),
      ],
    );
  }

  // Thumbnails like in Order History
  Widget _buildImageThumbnails(List<String> images) {
    // Show a horizontal list of thumbnails
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final url = images[index];
          return GestureDetector(
            onTap: () => _showImagePreview(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
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

  void _showImagePreview(String url) {
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
