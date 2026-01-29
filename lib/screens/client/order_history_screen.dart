import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:soloshine/screens/common/pdf_viewer_screen.dart';
import 'package:soloshine/screens/employee/manage_orders_screen.dart';
import 'package:intl/intl.dart';
import 'package:soloshine/screens/client/order_image_generator.dart';
import 'package:soloshine/screens/client/create_order_screen.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
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
  final TextEditingController _searchController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  OrderStatus? _selectedStatus;
  String? _selectedOrderType;

  String _selectedRange = 'All time';
  final List<String> _ranges = const [
    'All time',
    'Today',
    'Last 7 days',
    'Last 30 days',
    'Custom',
  ];

  bool _showFilters = false;
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
    _loadOrders();
    _searchController.addListener(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  bool _isUrgent(Order order) {
    final p = (order.orderPriority ?? '').toLowerCase().trim();
    return p == 'urgent' || p.contains('urgent');
  }

  bool _isFinished(Order order) {
    return order.status == OrderStatus.Completed ||
        order.status == OrderStatus.Delivered ||
        order.status == OrderStatus.cancelled;
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

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = context.read<AuthProvider>().currentUser;
      final token = AuthService.currentToken;

      if (currentUser != null && token != null) {
        DateTime? apiStartDate;
        DateTime? apiEndDate;

        final now = DateTime.now();
        switch (_selectedRange) {
          case 'Today':
            apiStartDate = DateTime(now.year, now.month, now.day);
            apiEndDate = apiStartDate.add(const Duration(days: 1));
            break;
          case 'Last 7 days':
            apiStartDate = now.subtract(const Duration(days: 7));
            apiEndDate = now;
            break;
          case 'Last 30 days':
            apiStartDate = now.subtract(const Duration(days: 30));
            apiEndDate = now;
            break;
          case 'Custom':
            apiStartDate = _startDate;
            apiEndDate = _endDate;
            break;
          case 'All time':
          default:
            break;
        }

        final orders = await OrderService.getOrdersByClient(
          currentUser.id,
          token,
          startDate: apiStartDate,
          endDate: apiEndDate,
          orderType: _selectedOrderType,
        );

        setState(() {
          _allOrders = orders;
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _applyFilters() {
    // Define "In Progress" statuses
    final inProgressStatuses = [
      OrderStatus.Wax,
      OrderStatus.DC,
      OrderStatus.Casted,
      OrderStatus.PendingDisp,
    ];

    setState(() {
      _filteredOrders =
          _allOrders.where((order) {
            bool matchesStatus = true;
            if (_selectedStatus != null) {
              // If selected status is one of the "In Progress" statuses,
              // show all orders with any "In Progress" status
              if (inProgressStatuses.contains(_selectedStatus)) {
                matchesStatus = inProgressStatuses.contains(order.status);
              } else {
                matchesStatus = order.status == _selectedStatus;
              }
            }

            final matchesSearch =
                _searchQuery.isEmpty ||
                (order.clientName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                )) ||
                (order.orderNo?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (order.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ));

            final matchesType =
                _selectedOrderType == null ||
                (_selectedOrderType == (order.orderType ?? 'Single'));

            return matchesStatus && matchesSearch && matchesType;
          }).toList();

      _filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
      if (_showFilters) {
        _filterAnimationController.forward();
      } else {
        _filterAnimationController.reverse();
      }
    });
  }

  bool _hasActiveFilters() {
    return _selectedStatus != null ||
        _selectedOrderType != null ||
        _selectedRange != 'All time' ||
        _searchQuery.isNotEmpty;
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedStatus = null;
      _selectedOrderType = null;
      _selectedRange = 'All time';
      _startDate = null;
      _endDate = null;
    });
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.primaryColor,
        title: const Text(
          'Order History',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade300,
                  Colors.transparent,
                  Colors.grey.shade300,
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _toggleFilters,
            tooltip: 'Filters',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    _showFilters
                        ? AppConstants.primaryColor.withOpacity(0.2)
                        : AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _showFilters ? Icons.filter_list_off : Icons.filter_list,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search orders',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),

          // Advanced Filters
          AnimatedBuilder(
            animation: _filterAnimation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _filterAnimation,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _buildAdvancedFilters(),
                ),
              );
            },
          ),

          // Summary Bar
          _buildSummaryBar(),

          // Orders List
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading orders...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                      onRefresh: _loadOrders,
                      color: AppConstants.primaryColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = _filteredOrders[index];
                          return _buildOrderCard(order);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: AppConstants.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Advanced Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppConstants.primaryColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isMobile) ...[
            _buildDropdownField<OrderStatus>(
              'Status',
              _selectedStatus,
              [
                    OrderStatus.pending,
                    OrderStatus.Wax, // Represents "In Progress"
                    OrderStatus.partialDelivery,
                    OrderStatus.Completed,
                    OrderStatus.Delivered,
                    OrderStatus.cancelled,
                  ]
                  .map(
                    (s) => DropdownMenuItem<OrderStatus>(
                      value: s,
                      child: Text(_getStatusText(s)),
                    ),
                  )
                  .toList(),
              (value) {
                setState(() => _selectedStatus = value);
                _applyFilters();
              },
              allowNull: true,
              nullText: 'All Statuses',
            ),
            const SizedBox(height: 12),
            _buildDropdownField(
              'Type',
              _selectedOrderType,
              const [
                DropdownMenuItem(value: 'Single', child: Text('Single')),
                DropdownMenuItem(value: 'Bulk', child: Text('Bulk')),
              ],
              (value) {
                setState(() => _selectedOrderType = value);
                _applyFilters();
              },
              allowNull: true,
              nullText: 'All Types',
            ),
            const SizedBox(height: 12),
            _buildDateRangeField(),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField<OrderStatus>(
                    'Status',
                    _selectedStatus,
                    [
                          OrderStatus.pending,
                          OrderStatus.Wax, // Represents "In Progress"
                          OrderStatus.partialDelivery,
                          OrderStatus.Completed,
                          OrderStatus.Delivered,
                          OrderStatus.cancelled,
                        ]
                        .map(
                          (s) => DropdownMenuItem<OrderStatus>(
                            value: s,
                            child: Text(_getStatusText(s)),
                          ),
                        )
                        .toList(),
                    (value) {
                      setState(() => _selectedStatus = value);
                      _applyFilters();
                    },
                    allowNull: true,
                    nullText: 'All Statuses',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField(
                    'Type',
                    _selectedOrderType,
                    const [
                      DropdownMenuItem(value: 'Single', child: Text('Single')),
                      DropdownMenuItem(value: 'Bulk', child: Text('Bulk')),
                    ],
                    (value) {
                      setState(() => _selectedOrderType = value);
                      _applyFilters();
                    },
                    allowNull: true,
                    nullText: 'All Types',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildDateRangeField()),
              ],
            ),
          ],

          if (_hasActiveFilters()) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_filteredOrders.length} of ${_allOrders.length} orders',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged, {
    bool allowNull = false,
    String? nullText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<T>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: [
              if (allowNull && nullText != null)
                DropdownMenuItem<T>(
                  value: null,
                  child: Text(
                    nullText,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date Range',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRange,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items:
                _ranges
                    .map(
                      (r) => DropdownMenuItem<String>(value: r, child: Text(r)),
                    )
                    .toList(),
            onChanged: (val) async {
              if (val == null) return;
              setState(() {
                _selectedRange = val;
                if (val != 'Custom') {
                  _startDate = null;
                  _endDate = null;
                }
              });
              if (val == 'Custom') {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDateRange:
                      _startDate != null && _endDate != null
                          ? DateTimeRange(start: _startDate!, end: _endDate!)
                          : null,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppConstants.primaryColor,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _startDate = picked.start;
                    _endDate = picked.end;
                  });
                }
              }
              _loadOrders();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar() {
    if (_allOrders.isEmpty && !_hasActiveFilters()) {
      return const SizedBox.shrink();
    }

    final baseOrders =
        _allOrders.where((order) {
          final matchesSearch =
              _searchQuery.isEmpty ||
              (order.clientName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              )) ||
              (order.orderNo?.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false);

          final matchesType =
              _selectedOrderType == null ||
              (_selectedOrderType == (order.orderType ?? 'Single'));

          return matchesSearch && matchesType;
        }).toList();

    // Define "In Progress" statuses
    final inProgressStatuses = [
      OrderStatus.Wax,
      OrderStatus.DC,
      OrderStatus.Casted,
      OrderStatus.PendingDisp,
    ];

    // Calculate counts
    final pendingCount =
        baseOrders.where((o) => o.status == OrderStatus.pending).length;
    final inProgressCount =
        baseOrders.where((o) => inProgressStatuses.contains(o.status)).length;
    final partialDeliveryCount =
        baseOrders.where((o) => o.status == OrderStatus.partialDelivery).length;
    final completedCount =
        baseOrders.where((o) => o.status == OrderStatus.Completed).length;
    final deliveredCount =
        baseOrders.where((o) => o.status == OrderStatus.Delivered).length;
    final cancelledCount =
        baseOrders.where((o) => o.status == OrderStatus.cancelled).length;

    // Check if "In Progress" is selected
    final isInProgressSelected =
        _selectedStatus != null && inProgressStatuses.contains(_selectedStatus);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // All chip
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedStatus = null);
                      _applyFilters();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _selectedStatus == null
                                ? AppConstants.primaryColor.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _selectedStatus == null
                                  ? AppConstants.primaryColor
                                  : Colors.grey.withOpacity(0.3),
                          width: _selectedStatus == null ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  _selectedStatus == null
                                      ? AppConstants.primaryColor
                                      : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'All (${baseOrders.length})',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _selectedStatus == null
                                      ? AppConstants.primaryColor
                                      : Colors.grey,
                              fontWeight:
                                  _selectedStatus == null
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pending chip
                  if (pendingCount > 0)
                    _buildStatusChip(
                      'Pending',
                      pendingCount,
                      OrderStatus.pending,
                      _selectedStatus == OrderStatus.pending,
                    ),

                  // In Progress chip (consolidated)
                  if (inProgressCount > 0)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          // Toggle between first in-progress status and null
                          _selectedStatus =
                              isInProgressSelected ? null : OrderStatus.Wax;
                        });
                        _applyFilters();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isInProgressSelected
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isInProgressSelected
                                    ? Colors.blue
                                    : Colors.blue.withOpacity(0.3),
                            width: isInProgressSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'In Progress ($inProgressCount)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight:
                                    isInProgressSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Partially Delivered chip
                  if (partialDeliveryCount > 0)
                    _buildStatusChip(
                      'Partially Delivered',
                      partialDeliveryCount,
                      OrderStatus.partialDelivery,
                      _selectedStatus == OrderStatus.partialDelivery,
                    ),

                  // Completed chip
                  if (completedCount > 0)
                    _buildStatusChip(
                      'Completed',
                      completedCount,
                      OrderStatus.Completed,
                      _selectedStatus == OrderStatus.Completed,
                    ),

                  // Delivered chip
                  if (deliveredCount > 0)
                    _buildStatusChip(
                      'Delivered',
                      deliveredCount,
                      OrderStatus.Delivered,
                      _selectedStatus == OrderStatus.Delivered,
                    ),

                  // Cancelled chip
                  if (cancelledCount > 0)
                    _buildStatusChip(
                      'Cancelled',
                      cancelledCount,
                      OrderStatus.cancelled,
                      _selectedStatus == OrderStatus.cancelled,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String label,
    int count,
    OrderStatus status,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = isSelected ? null : status;
        });
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? _getStatusColor(status).withOpacity(0.2)
                  : _getStatusColor(status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? _getStatusColor(status)
                    : _getStatusColor(status).withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 12,
                color: _getStatusColor(status),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasActiveFilters()
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _hasActiveFilters()
                ? 'No Orders Match Your Filters'
                : 'No Orders Found',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _hasActiveFilters()
                ? 'Try adjusting your filters or search terms'
                : 'Orders will appear here once they are created',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Clear All Filters'),
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
            ),
          ],
        ],
      ),
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
                // Navigate to order details if needed
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
                            ? (order.images.first.toLowerCase().endsWith('.pdf')
                                ? Container(
                                  color: Colors.red.shade50,
                                  child: Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red.shade400,
                                    size: 32,
                                  ),
                                )
                                : Image.network(
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
                                ))
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
                    Text(
                      order.orderNo ?? order.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
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
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final orderDetails = _formatOrderDetailsForCopy(
                              order,
                            );
                            final data = ClipboardData(text: orderDetails);
                            Clipboard.setData(data);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text('All details copied'),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppConstants.successColor,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.content_copy_rounded,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                          _formatDate(order.orderDate ?? order.createdAt),
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
                    if (order.orderType != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
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
                      ),
                    ],
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
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Container(
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
                children: [_buildExpandedContent(order)],
              ),
            ),
          ),
        ),
        if (_isUrgent(order))
          Positioned(top: 0, left: 0, child: _buildUrgentRibbon()),
      ],
    );
  }

  String _formatOrderDetailsForCopy(Order order) {
    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('║           📋 ORDER DETAILS                         ');
    buffer.writeln('');
    buffer.writeln('🔹 Order Number: ${order.orderNo ?? order.id}');
    buffer.writeln('🔹 Client Name: ${order.clientName}');
    buffer.writeln('🔹 Status: ${_getStatusText(order.status)}');
    buffer.writeln('🔹 Description: ${order.description}');
    buffer.writeln(
      '🔹 Order Date: ${_formatDate(order.orderDate ?? order.createdAt)}',
    );

    if (order.ornamentDetails.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('╔═════════');
      buffer.writeln('║           💎 ORNAMENT DETAILS                      ');
      buffer.writeln('');
      for (int i = 0; i < order.ornamentDetails.length; i++) {
        final detail = order.ornamentDetails[i];
        buffer.writeln('  ▶ Detail ${i + 1}: ${detail.name}');
        buffer.writeln('    • Weight: ${detail.weight} ${detail.unit ?? 'g'}');
        buffer.writeln('    • Purity: ${detail.purity}');
        buffer.writeln('    • Quantity: ${detail.quantity}');
      }
    }
    return buffer.toString();
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
          if (order.ornamentDetails.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Text(
                    'ORNAMENT DETAILS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...order.ornamentDetails.asMap().entries.map((entry) {
              final idx = entry.key;
              final detail = entry.value;
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
                    _buildOrnamentDetailRow(
                      'Weight',
                      '${detail.weight} ${detail.unit ?? 'g'}',
                    ),
                    const SizedBox(height: 10),
                    _buildOrnamentDetailRow('Purity', detail.purity),
                    const SizedBox(height: 10),
                    _buildOrnamentDetailRow('Quantity', '${detail.quantity}'),
                    if (detail.images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: detail.images.length,
                          itemBuilder: (context, index) {
                            final imageUrl = detail.images[index];
                            final isPdf = imageUrl.toLowerCase().endsWith(
                              '.pdf',
                            );

                            return GestureDetector(
                              onTap:
                                  () => _showImagePreview(
                                    imageUrl,
                                    galleryImages: detail.images,
                                  ),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child:
                                      isPdf
                                          ? Container(
                                            color: Colors.red.shade50,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
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
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return Container(
                                                color: Colors.grey.shade100,
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color:
                                                          Colors.grey.shade400,
                                                      size: 32,
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
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => OrderImageGenerator(order: order),
                        ),
                      ),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Generate Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
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
                  icon: const Icon(Icons.content_copy_outlined),
                  label: const Text('Clone Order'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
          ),
        ),
      ],
    );
  }

  void _showImagePreview(String url, {List<String>? galleryImages}) async {
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
                              (context, error, stack) => const SizedBox(
                                height: 300,
                                child: Center(
                                  child: Icon(Icons.broken_image, size: 40),
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

    final initialIndex = galleryImages.indexOf(url);
    if (initialIndex == -1) return;

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

  String _formatDate(DateTime date) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('h:mm:ss a');
    return '${dateFormat.format(date)} ${timeFormat.format(date)}';
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFF9800);
      case OrderStatus.Casted:
        return const Color(0xFF2196F3);
      case OrderStatus.Wax:
        return const Color(0xFF9C27B0);
      case OrderStatus.DC:
        return const Color(0xFF4CAF50);
      case OrderStatus.cancelled:
        return const Color(0xFFF44336);
      case OrderStatus.delay:
        return const Color.fromARGB(255, 0, 0, 0);
      case OrderStatus.due:
        return const Color(0xFFF44336);
      case OrderStatus.partialDelivery:
        return const Color.fromARGB(255, 75, 121, 118);
      case OrderStatus.PendingDisp:
        return AppConstants.PendingDisp;
      case OrderStatus.Completed:
        return AppConstants.Completed;
      case OrderStatus.Delivered:
        return AppConstants.deliveredColor;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
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
}
