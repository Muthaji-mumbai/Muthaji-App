import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For loading asset images
import 'package:soloshine/screens/client/pdfview.dart';
import 'package:soloshine/screens/client/order_image_generator.dart';
import 'package:soloshine/screens/client/create_order_screen.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';
import '../../services/auth_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  final Set<int> _expanded = <int>{};
  late TabController _tabController;

  bool _isUrgent(Order order) {
    final p = (order.orderPriority ?? '').toLowerCase().trim();
    return p == 'urgent' || p.contains('urgent');
  }

  bool _isPending(Order order) {
    return order.status == OrderStatus.pending;
  }

  bool _isDue(Order order) {
    if (!_isPending(order) || order.orderDate == null) return false;
    final now = DateTime.now();
    final days = now.difference(order.orderDate!).inDays;
    return days >= 7 && days < 10;
  }

  bool _isDelay(Order order) {
    if (!_isPending(order) || order.orderDate == null) return false;
    final now = DateTime.now();
    final days = now.difference(order.orderDate!).inDays;
    return days >= 10;
  }

  Widget _buildDueRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFFA000),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
      ),
      child: const Text(
        'DUE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDelayRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.errorColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
      ),
      child: const Text(
        'DELAY',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
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

  Widget _buildUrgentRibbon() {
    return Container(
      
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadOrders();
  }

  // Helper to build a Tab with an icon and a small text label underneath
  Widget _buildIconTextTab(IconData icon, String label) {
    return Tab(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 2),
          Text(label, style: AppConstants.bodySmall.copyWith(fontSize: 7)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        // First try client-filtered orders
        final clientOrders = await OrderService.getOrdersByClient(
          currentUser.id,
          token,
        );

        List<Order> effectiveOrders = clientOrders;

        // Temporary debug fallback: if none matched but server has data, show all
        if (clientOrders.isEmpty) {
          "No orders found for client";
        
        }

        setState(() {
          _allOrders = effectiveOrders;
          _applyFilters();
          _isLoading = false;
        });
      } else {
        setState(() {
          _allOrders = [];
          _filteredOrders = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _allOrders = [];
        _filteredOrders = [];
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

  void _applyFilters() {
    _filteredOrders =
        _allOrders.where((order) {
          // Apply tab filter
          switch (_tabController.index) {
            case 1: // Pending
              if (order.status != OrderStatus.pending) return false;
              break;
            case 2: // In Progress
              if (order.status != OrderStatus.inProgress) return false;
              break;
            case 3: // Completed
              if (order.status != OrderStatus.completed) return false;
              break;
            case 4: // Cancelled
              if (order.status != OrderStatus.cancelled) return false;
              break;
          }

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            return order.description.toLowerCase().contains(query) ||
                order.id.toLowerCase().contains(query) ||
                (order.orderNo?.toLowerCase().contains(query) ?? false) ||
                order.statusText.toLowerCase().contains(query);
          }

          // Apply date range filter (by createdAt)
          if (_fromDate != null) {
            final from = DateTime(
              _fromDate!.year,
              _fromDate!.month,
              _fromDate!.day,
            );
            if (order.createdAt.isBefore(from)) return false;
          }
          if (_toDate != null) {
            final to = DateTime(
              _toDate!.year,
              _toDate!.month,
              _toDate!.day,
              23,
              59,
              59,
              999,
            );
            if (order.createdAt.isAfter(to)) return false;
          }

          return true;
        }).toList();

    // Sort by creation date (newest first)
    _filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section with Tabs
          _buildSearchAndFilterSection(),

          // Orders List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                      onRefresh: () async => _loadOrders(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppConstants.spacingM),
                        itemCount: _filteredOrders.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) return const SizedBox.shrink();
                          final rowIndex = index - 1;
                          final order = _filteredOrders[rowIndex];
                          return _buildOrderTile(rowIndex, order);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // Status chip used in the ExpansionTile trailing when expanded
  Widget _buildStatusChip(Order order) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingL,
        vertical: AppConstants.spacingXS,
      ),
      decoration: BoxDecoration(
        color: order.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        border: Border.all(color: order.statusColor.withOpacity(0.3)),
      ),
      child: Text(
        order.statusText,
        style: AppConstants.bodySmall.copyWith(
          color: order.statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search orders...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                borderSide: BorderSide(
                  color: AppConstants.textSecondaryColor.withOpacity(0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                borderSide: BorderSide(
                  color: AppConstants.textSecondaryColor.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                borderSide: const BorderSide(
                  color: AppConstants.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
                vertical: AppConstants.spacingM,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Filters header and Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppConstants.primaryColor,
            unselectedLabelColor: AppConstants.textSecondaryColor,
            indicatorColor: AppConstants.primaryColor,
            tabs: [
              const Tab(text: 'All'),
              _buildIconTextTab(Icons.hourglass_empty, 'Pending'),
              _buildIconTextTab(Icons.autorenew, 'In Progress'),
              _buildIconTextTab(Icons.check_circle, 'Completed'),
              _buildIconTextTab(Icons.cancel, 'Cancelled'),
            ],
            onTap: (index) {
              setState(() {
                _applyFilters();
              });
            },
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Date range filter (bordered fields)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(isFrom: true),
                  child: _buildDateField(label: 'From Date', date: _fromDate),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(isFrom: false),
                  child: _buildDateField(label: 'To Date', date: _toDate),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _fromDate = null;
                    _toDate = null;
                    _applyFilters();
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial =
        isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final first = DateTime(2000);
    final last = DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
          if (_fromDate != null && _fromDate!.isAfter(_toDate!)) {
            _fromDate = _toDate;
          }
        }
        _applyFilters();
      });
    }
  }

  // Header row for the table-like layout
  // Widget _buildTableHeader() {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(
  //       horizontal: AppConstants.spacingM,
  //       vertical: AppConstants.spacingS,
  //     ),
  //     decoration: BoxDecoration(
  //       color: AppConstants.surfaceColor,
  //       borderRadius: BorderRadius.circular(AppConstants.radiusM),
  //       boxShadow: AppConstants.cardShadow,
  //     ),
  //     child: Row(
  //       children: [
  //         const SizedBox(
  //           width: 48,
  //           child: Text('Image', style: TextStyle(fontWeight: FontWeight.w700)),
  //         ),
  //         Expanded(
  //           flex: 4,
  //           child: Text(
  //             'Order No',
  //             style: AppConstants.bodySmall.copyWith(
  //               fontWeight: FontWeight.w700,
  //             ),
  //           ),
  //         ),
  //         Expanded(
  //           flex: 3,
  //           child: Text(
  //             'Order date',
  //             style: AppConstants.bodySmall.copyWith(
  //               fontWeight: FontWeight.w700,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Collapsible row with summary and expandable details
  Widget _buildOrderTile(int index, Order order) {
    final isOpen = _expanded.contains(index);
    return Dismissible(
      key: Key(order.id),
      direction: DismissDirection.horizontal,
      // Right swipe (startToEnd) => Edit
      background: Container(
        color: AppConstants.primaryColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppConstants.spacingM),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      // Left swipe (endToStart) => Cancel
      secondaryBackground: Container(
        color: AppConstants.errorColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppConstants.spacingM),
        child: const Icon(Icons.cancel, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        // Right swipe to Edit
        if (direction == DismissDirection.startToEnd) {
          if (order.status != OrderStatus.pending) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Only pending orders can be edited'),
                  backgroundColor: AppConstants.errorColor,
                ),
              );
            }
            return false; // Do not dismiss
          }
          // Navigate to CreateOrderScreen in edit mode; reload on success
          final updated = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => CreateOrderScreen(orderToEdit: order),
            ),
          );
          if (updated == true) {
            _loadOrders();
          }
          return false; // Never dismiss; we handle refresh ourselves
        }
        // Left swipe to Cancel
        else if (direction == DismissDirection.endToStart) {
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
          if (!confirm) return false;

          final token = AuthService.currentToken;
          if (token == null) return false;
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
          return false; // Do not dismiss; keep list stable
        }
        return false; // Default: never dismiss via swipe
      },
      // onDismissed no longer used since we don't actually dismiss items
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
            decoration: BoxDecoration(
              color: AppConstants.surfaceColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              boxShadow: AppConstants.cardShadow,
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isOpen,
                onExpansionChanged: (open) {
                  setState(() {
                    if (open) {
                      _expanded.add(index);
                    } else {
                      _expanded.remove(index);
                    }
                  });
                },
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
                ),
                // trailing:
                //     isOpen ? _buildStatusChip(order) : _buildStatusChip(order),
                title: _buildOrderSummary(index, order),
                childrenPadding: const EdgeInsets.all(AppConstants.spacingM),
                children: [_buildOrderDetails(order)],
              ),
            ),
          ),
          if (_isUrgent(order))
            Positioned(top: 0, left: 0, child: _buildUrgentRibbon()),
          // Status ribbon positioned on the right end
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: order.statusColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(AppConstants.radiusM),
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
                order.statusText.toUpperCase(),
                style: AppConstants.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          // Show Delay over Due when both conditions could be true (positioned below status ribbon)
          if (_isDelay(order))
            Positioned(top: 30, right: 0, child: _buildDelayRibbon())
          else if (_isDue(order))
            Positioned(top: 30, right: 0, child: _buildDueRibbon()),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(int index, Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
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
              flex: 3,
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
      ],
    );
  }

 Widget _buildOrderDetails(Order order) {
  return Stack(
    children: [
      Card(
        elevation: 2,
        margin: const EdgeInsets.all(AppConstants.spacingM),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status and actions
             
              
             
              
              // Order Information Section
              _buildOrderInfoSection(order),
              
              // Ornament Details Section
              if (order.ornamentDetails.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingL),
                _buildOrnamentDetailsSection(order),
              ],
              
              // Notes Section
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingL),
                _buildNotesSection(order),
              ],
              
              const SizedBox(height: AppConstants.spacingL),
              
              // Action Buttons Section
              _buildActionButtonsSection(order),
            ],
          ),
        ),
      ),
      // Status ribbon positioned on the right
      
    ],
  );
}

Widget _buildOrderHeader(Order order) {
  return Row(
    children: [
      // Order status chip
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingM,
          vertical: AppConstants.spacingXS,
        ),
        decoration: BoxDecoration(
          color: _getStatusColor(order.status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor(order.status),
            width: 1,
          ),
        ),
        child: Text(
          order.status.toString().split('.').last.toUpperCase(),
          style: AppConstants.bodySmall.copyWith(
            color: _getStatusColor(order.status),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

    ],
  );
}

Widget _buildOrderInfoSection(Order order) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Order Information',
        style: AppConstants.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: AppConstants.primaryColor,
        ),
      ),
      
      const SizedBox(height: AppConstants.spacingM),
      
      Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Created',
              value: _formatDate(order.createdAt),
            ),
            
            if (order.updatedAt != null) ...[
              const SizedBox(height: AppConstants.spacingS),
              _buildInfoRow(
                icon: Icons.update_outlined,
                label: 'Updated',
                value: _formatDate(order.updatedAt!),
              ),
            ],
            
            if (order.orderDate != null) ...[
              const SizedBox(height: AppConstants.spacingS),
              _buildInfoRow(
                icon: Icons.event_outlined,
                label: 'Order Date',
                value: _formatDate(order.orderDate!),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

Widget _buildInfoRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: AppConstants.textSecondaryColor,
      ),
      const SizedBox(width: AppConstants.spacingS),
      Text(
        '$label:',
        style: AppConstants.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
          color: AppConstants.textSecondaryColor,
        ),
      ),
      const SizedBox(width: AppConstants.spacingS),
      Expanded(
        child: Text(
          value,
          style: AppConstants.bodyMedium,
          textAlign: TextAlign.end,
        ),
      ),
    ],
  );
}

Widget _buildOrnamentDetailsSection(Order order) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Ornament Details',
        style: AppConstants.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: AppConstants.primaryColor,
        ),
      ),
      
      const SizedBox(height: AppConstants.spacingM),
      
      ...order.ornamentDetails.asMap().entries.map((entry) {
        final index = entry.key;
        final detail = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
          padding: const EdgeInsets.all(AppConstants.spacingM),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppConstants.primaryColor.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and index
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Expanded(
                    child: Text(
                      detail.name,
                      style: AppConstants.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${detail.purity}',
                      style: AppConstants.bodySmall.copyWith(
                        color: AppConstants.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.spacingM),
              
              // Specifications grid
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecItem(
                            'Weight',
                            '${detail.weight} ${detail.unit ?? ''}',
                          ),
                        ),
                        Expanded(
                          child: _buildSpecItem(
                            'Quantity',
                            '${detail.quantity}',
                          ),
                        ),
                      ],
                    ),
                    if (detail.size != null) ...[
                      const SizedBox(height: AppConstants.spacingS),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSpecItem(
                              'Size',
                              '${detail.size}',
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Additional properties
              if (detail.colorstone != null || detail.rhodium != null || detail.dull != null) ...[
                const SizedBox(height: AppConstants.spacingM),
                Wrap(
                  spacing: AppConstants.spacingS,
                  runSpacing: AppConstants.spacingXS,
                  children: [
                    if (detail.colorstone != null)
                      _buildPropertyChip('Colorstone', detail.colorstone!),
                    if (detail.rhodium != null)
                      _buildPropertyChip('Rhodium', detail.rhodium!),
                    if (detail.dull != null)
                      _buildPropertyChip('Dull', detail.dull!),
                  ],
                ),
              ],
              
              // Remarks
              if (detail.remarks != null && detail.remarks!.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingM),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remarks',
                        style: AppConstants.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingXS),
                      Text(
                        detail.remarks!,
                        style: AppConstants.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
              
              // Images
              if (detail.images.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingM),
                _buildImageThumbnails(detail.images),
              ],
            ],
          ),
        );
      }),
    ],
  );
}

Widget _buildSpecItem(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppConstants.bodySmall.copyWith(
          color: AppConstants.textSecondaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: AppConstants.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

Widget _buildPropertyChip(String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppConstants.spacingS,
      vertical: AppConstants.spacingXS,
    ),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.orange.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Text(
      '$label: $value',
      style: AppConstants.bodySmall.copyWith(
        color: Colors.orange.shade700,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

Widget _buildNotesSection(Order order) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Notes',
        style: AppConstants.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: AppConstants.primaryColor,
        ),
      ),
      
      const SizedBox(height: AppConstants.spacingM),
      
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.amber.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          order.notes!,
          style: AppConstants.bodyMedium,
        ),
      ),
    ],
  );
}

Widget _buildActionButtonsSection(Order order) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Actions',
        style: AppConstants.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: AppConstants.primaryColor,
        ),
      ),
      
      const SizedBox(height: AppConstants.spacingS),
      
      Wrap(
        spacing: AppConstants.spacingS,
        runSpacing: AppConstants.spacingS,
        children: [
          // Edit
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
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
                vertical: AppConstants.spacingS,
              ),
            ),
          ),

          // Clone
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
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
                vertical: AppConstants.spacingS,
              ),
            ),
          ),

          // Cancel
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Cancel Order?'),
                      content: const Text(
                        'Are you sure you want to cancel this order? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('No'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.errorColor,
                          ),
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
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingM,
                vertical: AppConstants.spacingS,
              ),
            ),
          ),
        ],
      ),
      
      const SizedBox(height: AppConstants.spacingM),
      
      Row(
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
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
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
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

Color _getStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Colors.orange;
    case OrderStatus.confirmed:
      return Colors.blue;
    case OrderStatus.completed:
      return Colors.green;
    case OrderStatus.cancelled:
      return Colors.red;
    default:
      return Colors.grey;
  }
}
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppConstants.textSecondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            _searchQuery.isNotEmpty || _tabController.index > 0
                ? 'No orders match your filters'
                : 'No orders yet',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            _searchQuery.isNotEmpty || _tabController.index > 0
                ? 'Try adjusting your search or filters'
                : 'Create your first order to get started',
            style: AppConstants.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty || _tabController.index > 0) ...[
            const SizedBox(height: AppConstants.spacingM),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _tabController.index = 0;
                  _applyFilters();
                });
              },
              child: const Text('Clear Filters'),
            ),
          ],
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

  String _formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return _formatDate(date);
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
      case OrderStatus.delay:
        return 'Delay';
      case OrderStatus.due:
        return 'Due';
      case OrderStatus.partialDelivery:
        return 'Partial Delivery';
    }
  }

  // Color _getStatusColor(OrderStatus status) {
  //   switch (status) {
  //     case OrderStatus.pending:
  //       return AppConstants.warningColor;
  //     case OrderStatus.confirmed:
  //       return AppConstants.accentColor;
  //     case OrderStatus.inProgress:
  //       return AppConstants.secondaryColor;
  //     case OrderStatus.completed:
  //       return AppConstants.successColor;
  //     case OrderStatus.cancelled:
  //       return AppConstants.errorColor;
  //     case OrderStatus.delay:
  //       return AppConstants.errorColor;
  //     case OrderStatus.due:
  //       return AppConstants.errorColor;
  //   }
  // }

  Widget _buildImageThumbnails(List<String> images) {
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

  Widget _buildDateField({required String label, DateTime? date}) {
    final text =
        date == null
            ? label
            : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        border: Border.all(
          color: AppConstants.textSecondaryColor.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: Text(
              text,
              style: AppConstants.bodySmall.copyWith(
                color:
                    date == null
                        ? AppConstants.textSecondaryColor
                        : AppConstants.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
