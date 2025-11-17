import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For loading asset images
import 'package:soloshine/screens/common/pdf_viewer_screen.dart';
import 'package:soloshine/screens/employee/manage_orders_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:soloshine/screens/client/order_image_generator.dart';
import 'package:soloshine/screens/client/create_order_screen.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';
import '../../services/auth_service.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

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

  // New filters
  OrderStatus? _selectedStatus; // enum-based status filter
  String? _orderType; // 'Single' | 'Bulk'

  // Tab definitions
  late List<String> _tabs;
  int _selectedTabIndex = 0;
  String _mapOrderToUiStatus(Order order) {
    switch (order.status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.partialDelivery:
        return 'Partially Delivered'; // Show for both bulk and single orders
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.Delivered:
        return 'Delivered';
      case OrderStatus.Completed:
        return 'Completed'; // Separate status for Completed
      // In Progress: all other statuses (Casted, Wax, PendingDisp, etc.)
      default:
        return 'In Progress';
    }
  }

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

  @override
  void initState() {
    super.initState();
    // Tabs: All, Pending, In Progress, Delivered, Cancelled (+ Partially Delivered for bulk)
    _tabs = [
      'All',
      'Pending',
      'In Progress',
      'Partially Delivered',
      'Completed',
      'Delivered',
      'Cancelled',
    ];
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
        _applyFilters();
      });
    });
    _loadOrders();
  }

  _updateTabs() {
    if (_orderType?.toLowerCase() == 'Bulk') {
      _tabs = [
        'All',
        'Pending',
        'In Progress',
        'Partially Delivered',
        'Completed',
        'Delivered',
        'Cancelled',
      ];
    } else {
      _tabs = [
        'All',
        'Pending',
        'In Progress',
        'Partially Delivered', // Added for single orders too
        'Completed',
        'Delivered',
        'Cancelled',
      ];
    }
    if (_tabController.length != _tabs.length) {
      _tabController.dispose();
      // _initializeTabController(); // Reinitialize with new length
    }
    setState(() {}); // Refresh UI
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
        // Use API-level filtering with date parameters
        final clientOrders = await OrderService.getOrdersByClient(
          currentUser.id,
          token,
          startDate: _fromDate,
          endDate: _toDate,
          orderType: _orderType,
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
    // Filter by tab
    String? tabStatus;
    if (_selectedTabIndex > 0) {
      tabStatus = _tabs[_selectedTabIndex];
    }
    _filteredOrders =
        _allOrders.where((order) {
          final uiStatus = _mapOrderToUiStatus(order);
          // Tab filter
          if (tabStatus != null &&
              tabStatus != 'All' &&
              uiStatus != tabStatus) {
            return false;
          }
          // Status dropdown filter (legacy, can be removed if not needed)
          if (_selectedStatus != null && order.status != _selectedStatus) {
            return false;
          }
          // Order type filter
          if (_orderType != null &&
              (order.orderType ?? 'Single') != _orderType) {
            return false;
          }
          // Search filter
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final matches =
                order.description.toLowerCase().contains(query) ||
                order.id.toLowerCase().contains(query) ||
                (order.orderNo?.toLowerCase().contains(query) ?? false) ||
                order.statusText.toLowerCase().contains(query);
            if (!matches) return false;
          }
          return true;
        }).toList();
    // Sort by creation date (newest first)
    _filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Map<String, int> _getStatusCounts() {
    final counts = <String, int>{};
    for (final order in _allOrders) {
      final status = _mapOrderToUiStatus(order);
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  Widget _buildTabWithCount(String tabName) {
    final counts = _getStatusCounts();
    int count = 0;

    if (tabName == 'All') {
      count = _allOrders.length;
    } else {
      count = counts[tabName] ?? 0;
    }

    return Tab(
      text: '$tabName($count)',
      height: 48,
    );
  }

  @override
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppConstants.primaryColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: _tabs.map((t) => _buildTabWithCount(t)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, (tabIdx) {
          if (_selectedTabIndex == tabIdx) {
            _applyFilters(); // Ensure filters are applied for the current tab
          }
          return Column(
            children: [
              // _buildStatusCountSection(),
              _buildSearchAndFilterSection(),
              _buildDateFilterSection(),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredOrders.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                          onRefresh: () async => _loadOrders(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(
                              AppConstants.spacingM,
                            ),
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
          );
        }),
      ),
    );
  }

  Widget _buildDateFilterSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        boxShadow: AppConstants.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(isFrom: true),
              child: _buildDateField(label: 'From', date: _fromDate),
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(isFrom: false),
              child: _buildDateField(label: 'To', date: _toDate),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildStatusCountSection() {
  //   final counts = _getStatusCounts();
  //   final statusColors = {
  //     'Pending': Colors.orange,
  //     'In Progress': Colors.blue,
  //     'Partially Delivered': Colors.purple,
  //     'Completed': Colors.green,
  //     'Delivered': Colors.teal,
  //     'Cancelled': Colors.red,
  //     'All': AppConstants.primaryColor,
  //   };

  //   return Container(
  //     padding: const EdgeInsets.all(AppConstants.spacingM),
     
      
  //   );
  // }

  Widget _buildStatusCountCard(String status, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: AppConstants.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: AppConstants.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

          // Filters row (Status, Order Type, Date Range)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _orderType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Order Type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Types'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Single',
                      child: Text('Single'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Bulk',
                      child: Text('Bulk'),
                    ),
                  ],
                  onChanged: (val) async {
                    setState(() => _orderType = val);
                    await _loadOrders();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // String _statusLabel(OrderStatus s) {
  //   switch (s) {
  //     case OrderStatus.pending:
  //       return 'Pending';
  //     case OrderStatus.Casted:
  //       return 'Casted';
  //     case OrderStatus.Wax:
  //       return 'Wax';
  //     case OrderStatus.DC:
  //       return 'DC';
  //     case OrderStatus.cancelled:
  //       return 'Cancelled';
  //     case OrderStatus.delay:
  //       return 'Delay';
  //     case OrderStatus.due:
  //       return 'Due';
  //     case OrderStatus.partialDelivery:
  //       return 'Partial Delivery';
  //     case OrderStatus.PendingDisp:
  //       return 'PendingDisp';
  //   }
  // }

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
        _loadOrders(); // Reload data from API with new date filters
      });
    }
  }

  // Collapsible row with summary and expandable details
  Widget _buildOrderTile(int index, Order order) {
    final isOpen = _expanded.contains(index);
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            boxShadow: AppConstants.cardShadow,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  order.status == OrderStatus.Completed
                      ? Colors
                          .green
                          .shade600 // Distinct color for Completed
                      : order.statusColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(AppConstants.radiusM),
                bottomLeft: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: (order.status == OrderStatus.Completed
                          ? Colors.green.shade600
                          : order.statusColor)
                      .withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child:
                ([
                      OrderStatus.Casted,
                      OrderStatus.DC,
                      OrderStatus.PendingDisp,
                      OrderStatus.Wax,
                    ].contains(order.status))
                    ? Text(
                      "In Progress",
                      style: AppConstants.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    )
                    : Text(
                      order.status == OrderStatus.Completed
                          ? "COMPLETED"
                          : order.statusText.toUpperCase(),
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
                  final isPdf = url.toLowerCase().endsWith('.pdf');
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        isPdf
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
                              errorBuilder:
                                  (c, e, s) => Container(
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
              child: Row(
                children: [
                  Expanded(
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
                  if (order.orderType != null) ...[
                    const SizedBox(width: 8),
                    _buildOrderTypeChip(order.orderType!),
                  ],
                ],
              ),
            ),
            SizedBox(width: 5),
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

                // Partial Delivery Status
                if (order.status == OrderStatus.partialDelivery) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.partialDeliveryColor.withOpacity(
                        0.1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppConstants.partialDeliveryColor
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 14,
                          color: AppConstants.partialDeliveryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Delivered: ${order.totalDeliveryCount}/${order.totalQuantity}',
                          style: TextStyle(
                            color: AppConstants.partialDeliveryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (order.shouldBeDelivered) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'READY FOR COMPLETION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

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

  Widget _buildOrderTypeChip(String type) {
    final isBulk = type.toLowerCase() == 'bulk';
    final bg = isBulk ? Colors.purple.shade50 : Colors.blue.shade50;
    final fg = isBulk ? Colors.purple.shade700 : Colors.blue.shade700;
    final border = isBulk ? Colors.purple.shade200 : Colors.blue.shade200;
    final icon = isBulk ? Icons.groups_2_outlined : Icons.person_outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            type,
            style: AppConstants.bodySmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
            border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
          ),
          child: Column(
            children: [
              // _buildInfoRow(
              //   icon: Icons.calendar_today_outlined,
              //   label: 'Created',
              //   value: _formatDate(order.createdAt),
              // ),

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
        Icon(icon, size: 18, color: AppConstants.textSecondaryColor),
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
                              child: _buildSpecItem('Size', '${detail.size}'),
                            ),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Additional properties
                if (detail.colorstone != null ||
                    detail.rhodium != null ||
                    detail.dull != null) ...[
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
                        Text(detail.remarks!, style: AppConstants.bodySmall),
                      ],
                    ),
                  ),
                ],

                // Partial Delivery
                if (detail.partialDelivery != null &&
                    detail.partialDelivery!.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingM),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.spacingS),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.teal.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 16,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: AppConstants.spacingXS),
                            Text(
                              'Partial Delivery (${detail.partialDelivery!.length})',
                              style: AppConstants.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.spacingS),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            children: [
                              // Header row
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppConstants.spacingS,
                                  vertical: AppConstants.spacingXS,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Delivery Date',
                                        style: AppConstants.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        'Qty',
                                        textAlign: TextAlign.right,
                                        style: AppConstants.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        'Notes',
                                        textAlign: TextAlign.right,
                                        style: AppConstants.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Data rows
                              ...detail.partialDelivery!.asMap().entries.map((
                                entry,
                              ) {
                                final pd = entry.value;
                                final isLast =
                                    entry.key ==
                                    detail.partialDelivery!.length - 1;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppConstants.spacingS,
                                    vertical: AppConstants.spacingS,
                                  ),
                                  decoration: BoxDecoration(
                                    border:
                                        isLast
                                            ? null
                                            : Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.withOpacity(
                                                  0.2,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(pd.deliverydate),
                                          style: AppConstants.bodySmall,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          pd.qty.toString(),
                                          textAlign: TextAlign.right,
                                          style: AppConstants.bodySmall
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal,
                                              ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          pd.deliverynote ?? '',
                                          textAlign: TextAlign.right,
                                          style: AppConstants.bodySmall
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal,
                                              ),
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
          style: AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.w600),
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
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
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
            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
          ),
          child: Text(order.notes!, style: AppConstants.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildActionButtonsSection(Order order) {
    final isBulk = (order.orderType?.toLowerCase() == 'bulk');
    final isSingle = !isBulk;
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
            if (isSingle)
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
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                    vertical: AppConstants.spacingS,
                  ),
                ),
              ),
            // No edit/cancel for single, nothing for bulk
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    () => Navigator.push(
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
      ],
    );
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

  // Color _getStatusColor(OrderStatus status) {
  //   switch (status) {
  //     case OrderStatus.pending:
  //       return AppConstants.warningColor;
  //     case OrderStatus.Casted:
  //       return AppConstants.accentColor;
  //     case OrderStatus.Wax:
  //       return AppConstants.secondaryColor;
  //     case OrderStatus.DC:
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
        final isPdf = url.toLowerCase().endsWith('.pdf');
        
        return GestureDetector(
          onTap: () => _showImagePreview(url, galleryImages: images), // ✅ UPDATED
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
                      errorBuilder: (context, error, stack) => Container(
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

  void _showImagePreview(String url, {List<String>? galleryImages}) async {
    // If single image or no gallery context, show single image
   
   
   
    if (galleryImages == null || galleryImages.length == 1) {
      if (url.toLowerCase().endsWith('.pdf')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    PdfViewerScreen(pdfUrl: url, title: 'Order Document'),
          ),
        );
      } else {
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
      return;
    }

    // Gallery mode - Find index and show full screen gallery
    final initialIndex = galleryImages.indexOf(url);
    if (initialIndex == -1) return; // Safety check

    if (url.toLowerCase().endsWith('.pdf')) {
      // If first image is PDF, open PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  PdfViewerScreen(pdfUrl: url, title: 'Order Document'),
        ),
      );
    } else {
      // Show swipeable image gallery
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => FullScreenImageViewer(
                images: galleryImages,
                initialIndex: initialIndex,
              ),
        ),
      );
    }
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
