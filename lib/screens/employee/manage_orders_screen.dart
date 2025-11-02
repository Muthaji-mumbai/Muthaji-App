import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:soloshine/screens/client/order_image_generator.dart';
import 'package:soloshine/screens/employee/order_detailed_screen.dart';
import 'package:soloshine/screens/client/create_order_screen.dart';
import 'package:soloshine/screens/common/pdf_viewer_screen.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../models/user.dart';
import '../../constants/app_constants.dart';

class ManageOrdersScreen extends StatefulWidget {
  final OrderStatus? initialStatus;
  final String? initialOrderType;
  final String? initialUserId;
  final String? initialUserName;

  const ManageOrdersScreen({
    super.key,
    this.initialStatus,
    this.initialOrderType,
    this.initialUserId,
    this.initialUserName,
  });

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen>
    with TickerProviderStateMixin {
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  int _initialTotalCount = 0;
  int _allChipCount = 0; // <-- Stores the FIRST load count
  bool _isFirstLoadDone = false; // <-- Locks after first load
  // ← count that is shown in the **All** chip
  bool _allChipCountLocked = false; // ← true after the first successful load
  OrderStatus? _selectedStatus;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String? _selectedOrderType; // 'Single' | 'Bulk'
  bool _selectionMode = false;
  final Set<String> _selectedOrderIds = {};

  String _selectedRange = 'All time';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _ranges = const [
    'All time',
    'Today',
    'Last 7 days',
    'Last 30 days',
    'Custom',
  ];

  // Sorting variables
  String _sortBy = 'orderDate'; // Default sort by order date
  bool _sortAscending = false; // Default to descending (newest first)
  final List<Map<String, String>> _sortOptions = const [
    {'value': 'orderDate', 'label': 'Order Date'},
    {'value': 'clientName', 'label': 'Client Name'},
    {'value': 'status', 'label': 'Status'},
    {'value': 'orderNo', 'label': 'Order Number'},
    {'value': 'description', 'label': 'Description'},
  ];

  // Party/User filtering variables
  String? _selectedUserId;
  String? _selectedUserName;
  List<User> _allUsers = [];
  bool _loadingUsers = false;

  bool _isLoading = true;
  bool _showFilters = false;
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  @override
  void initState() {
    super.initState();

    // Set initial filter values from widget parameters
    _selectedStatus = widget.initialStatus;
    _selectedOrderType = widget.initialOrderType;
    _selectedUserId = widget.initialUserId;
    _selectedUserName = widget.initialUserName;

    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
    _loadData();
    _loadUsers(); // Load users for party filtering
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final token = AuthService.currentToken;
      if (token != null) {
        // Calculate date range for API call
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
            // No date filtering at API level
            break;
        }

        final orders = await OrderService.getAllOrders(
          token,
          status:
              _selectedStatus == OrderStatus.due ||
                      _selectedStatus == OrderStatus.delay
                  ? null
                  : _selectedStatus,
          startDate: apiStartDate,
          endDate: apiEndDate,
          partyname: _selectedUserId,
        );

        setState(() {
          _allOrders = orders;
          _filteredOrders = orders;
          if (!_allChipCountLocked) {
            _allChipCount =
                orders.length; // ← first load → remember this number
            _allChipCountLocked = true; // ← never change it again
          }

          _isLoading = false;
        });

        // await _checkAndUpdateDeliveredOrders(token);

        _applyFilters();
      } else {
        throw Exception('No authentication token');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed loading data:'),
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

  Future<void> _checkAndUpdateDeliveredOrders(String token) async {
    try {
      final currentUser = AuthService.currentUser;
      final ordersToUpdate =
          _allOrders.where((order) => order.shouldBeDelivered).toList();

      if (ordersToUpdate.isNotEmpty) {
        for (final order in ordersToUpdate) {
          try {
            await OrderService.updateOrderStatus(
              orderId: order.id,
              newStatus: OrderStatus.Delivered, // Mark as delivered
              userId: currentUser?.id,
              token: token,
            );
          } catch (e) {
            // Log error but continue with other orders
            print('Error updating order ${order.id} to delivered: $e');
          }
        }

        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '${ordersToUpdate.length} orders automatically marked as delivered',
                  ),
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
      }
    } catch (e) {
      // Silently handle errors for auto-update
      print('Error in auto-update delivered orders: $e');
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final token = AuthService.currentToken;
      if (token != null) {
        final users = await UserService.getAllUsers(token);

        setState(() {
          _allUsers = users;
          _loadingUsers = false;
        });
      }
    } catch (e) {
      setState(() => _loadingUsers = false);

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
    

    final isSingleOrder = order.orderType == 'Single' || order.orderType == null;
    final dueThreshold = isSingleOrder ? 7 : 10;
    final delayThreshold = isSingleOrder ? 10 : 15;
    
    return days >= dueThreshold && days < delayThreshold;
  }

  bool _isDelay(Order order) {
    if (!_isPending(order) || order.orderDate == null) return false;
    final now = DateTime.now();
    final days = now.difference(order.orderDate!).inDays;

    final isSingleOrder = order.orderType == 'Single' || order.orderType == null;
    final delayThreshold = isSingleOrder ? 10 : 15;
    
    return days >= delayThreshold;
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

  Widget _buildDueRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFFA000), // Amber 700
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

  void _applyFilters() {
    setState(() {
      _filteredOrders =
          _allOrders.where((order) {
            // Status filtering is now handled at API level, but we still need to handle special cases
            bool matchesStatus = true;
            if (_selectedStatus != null) {
              if (_selectedStatus == OrderStatus.due) {
                matchesStatus = _isDue(order);
              } else if (_selectedStatus == OrderStatus.delay) {
                matchesStatus = _isDelay(order);
              } else {
                matchesStatus = order.status == _selectedStatus;
              }
            }

            final matchesSearch =
                _searchQuery.isEmpty ||
                order.clientName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                order.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (order.orderNo?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false);

            final matchesType =
                _selectedOrderType == null ||
                (_selectedOrderType == (order.orderType ?? 'Single'));

            // Date filtering is now handled at API level
            return matchesStatus && matchesSearch && matchesType;
          }).toList();

      // Apply sorting
      _filteredOrders.sort((a, b) {
        int comparison = 0;

        switch (_sortBy) {
          case 'orderDate':
            if (a.orderDate != null && b.orderDate != null) {
              comparison = a.orderDate!.compareTo(b.orderDate!);
            } else if (a.orderDate != null) {
              comparison = -1;
            } else if (b.orderDate != null) {
              comparison = 1;
            }
            break;
          case 'clientName':
            comparison = a.clientName.toLowerCase().compareTo(
              b.clientName.toLowerCase(),
            );
            break;
          case 'status':
            comparison = a.status.toString().compareTo(b.status.toString());
            break;
          case 'orderNo':
            final aOrderNo = a.orderNo ?? a.id;
            final bOrderNo = b.orderNo ?? b.id;
            comparison = aOrderNo.toLowerCase().compareTo(
              bOrderNo.toLowerCase(),
            );
            break;
          case 'description':
            comparison = a.description.toLowerCase().compareTo(
              b.description.toLowerCase(),
            );
            break;
          default:
            // Default to order date
            if (a.orderDate != null && b.orderDate != null) {
              comparison = a.orderDate!.compareTo(b.orderDate!);
            }
        }

        // Reverse if descending
        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppConstants.primaryColor),
                const SizedBox(height: 16),
                const Text('Updating order status...'),
              ],
            ),
          ),
    );

    try {
      final token = AuthService.currentToken;
      final currentUser = AuthService.currentUser;
      if (token != null) {
        await OrderService.updateOrderStatus(
          orderId: order.id,
          newStatus: newStatus,
          userId: currentUser?.id,
          token: token,
        );
        await _loadData();

        // Close loading dialog
        if (mounted) Navigator.of(context).pop();

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
        // Close loading dialog
        if (mounted) Navigator.of(context).pop();
        throw Exception('No authentication token');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

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

  void _toggleSelection(String orderId, bool selected) {
    setState(() {
      if (selected) {
        _selectedOrderIds.add(orderId);
      } else {
        _selectedOrderIds.remove(orderId);
      }
      _selectionMode = _selectedOrderIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedOrderIds.clear();
      _selectionMode = false;
    });
  }

  void _selectAllOrders() {
    setState(() {
      _selectedOrderIds.clear();
      for (final order in _filteredOrders) {
        _selectedOrderIds.add(order.id);
      }
      _selectionMode = _selectedOrderIds.isNotEmpty;
    });
  }

  void _selectNoneOrders() {
    _clearSelection();
  }

  Future<void> _bulkChangeStatus(OrderStatus status) async {
    final token = AuthService.currentToken;
    if (token == null || _selectedOrderIds.isEmpty) return;

    // Show confirmation dialog
    final Casted = await showDialog<bool>(
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
                const Text('Bulk Status Update'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to update ${_selectedOrderIds.length} orders to "${_getStatusText(status)}"?',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New Status: ${_getStatusText(status)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
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
                child: const Text('Update All'),
              ),
            ],
          ),
    );

    if (Casted != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Updating ${_selectedOrderIds.length} orders...'),
              ],
            ),
          ),
    );

    try {
      final currentUser = AuthService.currentUser;
      for (final id in _selectedOrderIds) {
        final order = _allOrders.firstWhere((o) => o.id == id);
        await OrderService.updateOrderStatus(
          orderId: order.id,
          newStatus: status,
          userId: currentUser?.id,
          token: token,
        );
      }
      await _loadData();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.done_all, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Updated  orders successfully'),
            ],
          ),
          backgroundColor: AppConstants.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _clearSelection();
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Bulk update failed: $e'),
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
          await _loadData();
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

  Future<void> _bulkDeleteOrders() async {
    if (_selectedOrderIds.isEmpty) return;

    // Check if user is admin
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Only admins can delete orders'),
            ],
          ),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Delete Multiple Orders'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${_selectedOrderIds.length} orders? This action cannot be undone.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This will permanently delete all selected orders.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Deleting Orders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.red.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Deleting 0/${_selectedOrderIds.length}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final token = AuthService.currentToken;
      if (token == null) {
        if (mounted) Navigator.of(context).pop();
        throw Exception('No authentication token');
      }

      int deletedCount = 0;

      for (final id in _selectedOrderIds) {
        try {
          await OrderService.deleteOrder(orderId: id, token: token);
          deletedCount++;

          // Update progress
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          print('Error deleting order $id: $e');
          // Continue with next order even if one fails
        }
      }

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      await _loadData();

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.done_all, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Successfully deleted $deletedCount orders'),
            ],
          ),
          backgroundColor: AppConstants.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      _clearSelection();
    } catch (e) {
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Bulk delete failed: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.primaryColor,
        title: Text(
          _selectionMode
              ? '${_selectedOrderIds.length} selected'
              : _selectedUserName != null
              ? 'Orders - $_selectedUserName'
              : 'Manage Orders',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
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
          if (_selectionMode) ...[
            IconButton(
              tooltip: 'Select All',
              icon: const Icon(Icons.select_all_rounded),
              onPressed: _selectAllOrders,
            ),
            IconButton(
              tooltip: 'Select None',
              icon: const Icon(Icons.deselect_rounded),
              onPressed: _selectNoneOrders,
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<OrderStatus>(
                tooltip: 'Bulk Change Status',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sync_alt_rounded, size: 20),
                ),
                onSelected: (st) => _bulkChangeStatus(st),
                itemBuilder:
                    (context) => [
                      ...OrderStatus.values
                          .where((s) => s != OrderStatus.partialDelivery)
                          .map(
                            (s) => PopupMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(s),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Text(_getStatusText(s)),
                                ],
                              ),
                            ),
                          ),
                    ],
              ),
            ),
            if (_isAdmin())
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Delete Selected',
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.red.shade600,
                    ),
                  ),
                  onPressed: () => _bulkDeleteOrders(),
                ),
              ),
          ] else ...[
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
        ],
      ),
      body: Column(
        children: [
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

          // Advanced Filters - Collapsible
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
                      onRefresh: _loadData,
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
      floatingActionButton:
          !_selectionMode
              ? FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    _selectionMode = true;
                  });
                },
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Select Orders'),
              )
              : null,
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
              OrderStatus.values
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
            _buildPartyDropdownField(),
            const SizedBox(height: 12),
            _buildDateRangeField(),
            const SizedBox(height: 12),
            _buildDropdownField<String>(
              'Sort By',
              _sortBy,
              _sortOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option['value']!,
                      child: Text(option['label']!),
                    ),
                  )
                  .toList(),
              (value) {
                setState(() => _sortBy = value ?? 'orderDate');
                _applyFilters();
              },
            ),
            const SizedBox(height: 12),
            _buildDropdownField<bool>(
              'Sort Order',
              _sortAscending,
              const [
                DropdownMenuItem<bool>(
                  value: false,
                  child: Row(
                    children: [
                      Icon(Icons.arrow_downward, size: 16),
                      SizedBox(width: 8),
                      Text('Descending (Newest First)'),
                    ],
                  ),
                ),
                DropdownMenuItem<bool>(
                  value: true,
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 16),
                      SizedBox(width: 8),
                      Text('Ascending (Oldest First)'),
                    ],
                  ),
                ),
              ],
              (value) {
                setState(() => _sortAscending = value ?? false);
                _applyFilters();
              },
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField<OrderStatus>(
                    'Status',
                    _selectedStatus,
                    OrderStatus.values
                        .map(
                          (s) => DropdownMenuItem<OrderStatus>(
                            value: s,
                            child: Text(_getStatusText(s)),
                          ),
                        )
                        .toList(),
                    (value) {
                      setState(() => _selectedStatus = value);
                      _loadData(); // Reload data from API with new status filter
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
                      _applyFilters(); // Order type is still filtered client-side
                    },
                    allowNull: true,
                    nullText: 'All Types',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildPartyDropdownField()),
                const SizedBox(width: 16),
                Expanded(child: _buildDateRangeField()),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField<String>(
                    'Sort By',
                    _sortBy,
                    _sortOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option['value']!,
                            child: Text(option['label']!),
                          ),
                        )
                        .toList(),
                    (value) {
                      setState(() => _sortBy = value ?? 'orderDate');
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField<bool>(
                    'Sort Order',
                    _sortAscending,
                    const [
                      DropdownMenuItem<bool>(
                        value: false,
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward, size: 16),
                            SizedBox(width: 8),
                            Text('Desc'),
                          ],
                        ),
                      ),
                      DropdownMenuItem<bool>(
                        value: true,
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward, size: 16),
                            SizedBox(width: 8),
                            Text('Asc'),
                          ],
                        ),
                      ),
                    ],
                    (value) {
                      setState(() => _sortAscending = value ?? false);
                      _applyFilters();
                    },
                  ),
                ),
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

  Widget _buildPartyDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Party/Customer',
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
          child:
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
                  : DropdownButtonFormField<String>(
                    value: _selectedUserId,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                          child: Text(
                            '${user.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                        _selectedUserName =
                            value != null
                                ? _allUsers
                                    .firstWhere((u) => u.id == value)
                                    .name
                                : null;
                      });
                      _loadData(); // Reload data from API with new user filter
                    },
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
              _loadData(); // Reload data from API with new date filter
            },
          ),
        ),
      ],
    );
  }Widget _buildSummaryBar() {
  if (_allOrders.isEmpty && !_hasActiveFilters()) return const SizedBox.shrink();

  // ---- Live counts for every status (updated on every API call) ----
  final statusCounts = <OrderStatus, int>{};
  for (final status in OrderStatus.values) {
    if (status == OrderStatus.due) {
      statusCounts[status] = _allOrders.where(_isDue).length;
    } else if (status == OrderStatus.delay) {
      statusCounts[status] = _allOrders.where(_isDelay).length;
    } else {
      statusCounts[status] = _allOrders.where((o) => o.status == status).length;
    }
  }

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
                // ---------- ALL CHIP – LOCKED TO FIRST LOAD ----------
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedStatus = null);
                    _loadData(); // still reloads data, but count stays same
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _selectedStatus == null
                          ? AppConstants.primaryColor.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedStatus == null
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
                            color: _selectedStatus == null
                                ? AppConstants.primaryColor
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'All', // ← NEVER CHANGES
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedStatus == null
                                ? AppConstants.primaryColor
                                : Colors.grey,
                            fontWeight: _selectedStatus == null
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ---------- OTHER STATUS CHIPS – LIVE COUNTS ----------
                ...OrderStatus.values.map((status) {
                  final isVirtual = status == OrderStatus.due || status == OrderStatus.delay;
                  final count = statusCounts[status] ?? 0;
                  final isSelected = _selectedStatus == status;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStatus = isSelected ? null : status;
                      });
                      if (!isVirtual) {
                        _loadData();          // real status → API call
                      } else {
                        _applyFilters();      // Due/Delay → local filter
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getStatusColor(status).withOpacity(0.2)
                            : _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
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
                            '${_getStatusText(status)}',
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
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}  Widget _buildEmptyState() {
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

  bool _isAdmin() {   
    final currentUser = AuthService.currentUser;
    return currentUser?.role == UserRole.admin;
  }

  String _formatOrderDetailsForCopy(Order order) {
    final buffer = StringBuffer();
    
    buffer.writeln('');
    buffer.writeln('║           📋 ORDER DETAILS                         ');
    buffer.writeln('');
    buffer.writeln('');
    buffer.writeln('🔹 Order Number: ${order.orderNo ?? order.id}');
    buffer.writeln('🔹 Order ID: ${order.id}');
    buffer.writeln('🔹 Client Name: ${order.clientName}');
    buffer.writeln('🔹 Status: ${_getStatusText(order.status)}');
    buffer.writeln('🔹 Description: ${order.description}');
    buffer.writeln('🔹 Order Date: ${_formatDate(order.orderDate!)}');
    
    if (order.orderType != null) {
      buffer.writeln('🔹 Order Type: ${order.orderType}');
    }
    
    if (order.partynameDisplay != null) {
      buffer.writeln('🔹 Party Name: ${order.partynameDisplay}');
    }
    
    if (order.images.isNotEmpty) {
      buffer.writeln('🔹 Images: ${order.images.length}');
    }
    
    if (order.totalQuantity != null) {
      buffer.writeln('🔹 Total Quantity: ${order.totalQuantity}');
    }
    
    if (order.status == OrderStatus.partialDelivery && order.totalDeliveryCount != null) {
      buffer.writeln('🔹 Delivered: ${order.totalDeliveryCount}/${order.totalQuantity}');
    }
    
    if (order.updatedBy != null && order.updatedAt != null) {
      buffer.writeln('🔹 Last Updated: ${_formatDate(order.updatedAt!)} by ${order.updatedBy}');
    }
    
    if (order.ornamentDetails.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('╔═════════');
      buffer.writeln('║           💎 ORNAMENT DETAILS                      ');
      buffer.writeln('');
      for (int i = 0; i < order.ornamentDetails.length; i++) {
        final detail = order.ornamentDetails[i];
        buffer.writeln('');
        buffer.writeln('  ▶ Detail ${i + 1}: ${detail.name}');
        buffer.writeln('    • Weight: ${detail.weight} ${detail.unit ?? 'g'}');
        buffer.writeln('    • Purity: ${detail.purity}');
        buffer.writeln('    • Quantity: ${detail.quantity}');
        if (detail.size != null) {
          buffer.writeln('    • Size: ${detail.size}');
        }
        if (detail.colorstone != null) {
          buffer.writeln('    • Colorstone: ${detail.colorstone}');
        }
        if (detail.rhodium != null) {
          buffer.writeln('    • Rhodium: ${detail.rhodium}');
        }
        if (detail.dull != null) {
          buffer.writeln('    • Dull: ${detail.dull}');
        }
        if ((detail.remarks ?? '').isNotEmpty) {
          buffer.writeln('    • Remarks: ${detail.remarks}');
        }
      }
    }
    
    buffer.writeln('');
    buffer.writeln('');
    
    return buffer.toString();
  }

  Widget _buildOrderCard(Order order) {
    final isSelected = _selectedOrderIds.contains(order.id);

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppConstants.primaryColor.withOpacity(0.05)
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                isSelected
                    ? Border.all(
                      color: AppConstants.primaryColor.withOpacity(0.3),
                      width: 2,
                    )
                    : null,
            boxShadow: [
              BoxShadow(
                color:
                    isSelected
                        ? AppConstants.primaryColor.withOpacity(0.1)
                        : Colors.grey.shade200,
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
                    Row(
                      children: [
                        Expanded(
                          child: Row(
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
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  final orderDetails = _formatOrderDetailsForCopy(order);
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
                              'Status updated by ${order.updatedBy} on ${_formatDate(order.updatedAt!)}',
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
                            const SizedBox(width: 8),
                          ],
                          // Show party name for bulk orders
                          if (order.orderType == 'Bulk' ||
                              order.orderType == 'Single' &&
                                  order.partynameDisplay != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.purple.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.group_outlined,
                                    size: 12,
                                    color: Colors.purple.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.partynameDisplay!,
                                    style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ],
                    // Show delivery count for partial delivery orders
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
                    if (_selectionMode) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged:
                                (val) =>
                                    _toggleSelection(order.id, val ?? false),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Select for bulk action',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
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
                      ).then((_) => _loadData());
                    } else if (value == 'status') {
                      _showStatusUpdateDialog(order);
                    } else if (value == 'delete') {
                      if (_isAdmin()) {
                        _deleteOrder(order.id);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Only admins can delete orders',
                            ),
                            backgroundColor: AppConstants.errorColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    } else if (value == 'full_details') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => OrderDetailsScreen(order: order),
                        ),
                      );
                    } else if (value == 'generate_image') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => OrderImageGenerator(order: order),
                        ),
                      );
                    }
                    // else if (value == 'generate_pdf') {
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
                        PopupMenuItem(
                          value: 'generate_image',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              const Text('Generate Image'),
                            ],
                          ),
                        ),
                        // PopupMenuItem(
                        //   value: 'generate_pdf',
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
                        if (_isAdmin() &&
                            (order.orderType == 'Single' ||
                                order.status != OrderStatus.Delivered))
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Delete Order',
                                  style: TextStyle(color: Colors.red.shade600),
                                ),
                              ],
                            ),
                          ),
                      ],
                ),
                children: [_buildExpandedContent(order)],
              ),
            ),
          ),
        ),

        if (_isUrgent(order))
          Positioned(top: 0, left: 0, child: _buildUrgentRibbon()),
        if (_isDelay(order))
          Positioned(top: 0, right: 0, child: _buildDelayRibbon())
        else if (_isDue(order))
          Positioned(top: 0, right: 0, child: _buildDueRibbon()),
        // else if (_isPending(order))
        //   Positioned(top: 0, right: 0, child: _buildPendingRibbon()),
      ],
    );
  }

  Widget _buildOrderSummaryRow(
    String label,
    String value, {
    bool isStatus = false,
    OrderStatus? status,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: isStatus && status != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(status).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _getStatusColor(status),
                  ),
                ),
              )
            : Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        ),
      ],
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
          // Order Summary Section
          // Container(
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     color: Colors.white,
          //     borderRadius: BorderRadius.circular(12),
          //     border: Border.all(
          //       color: AppConstants.primaryColor.withOpacity(0.3),
          //       width: 2,
          //     ),
          //     boxShadow: [
          //       BoxShadow(
          //         color: AppConstants.primaryColor.withOpacity(0.1),
          //         blurRadius: 8,
          //         offset: const Offset(0, 2),
          //       ),
          //     ],
          //   ),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     // children: [
          //     //   Row(
          //     //     children: [
          //     //       Icon(
          //     //         Icons.info_outline_rounded,
          //     //         color: AppConstants.primaryColor,
          //     //         size: 24,
          //     //       ),
          //     //       const SizedBox(width: 12),
          //     //       Text(
          //     //         'ORDER SUMMARY',
          //     //         style: TextStyle(
          //     //           fontSize: 16,
          //     //           fontWeight: FontWeight.w800,
          //     //           color: AppConstants.primaryColor,
          //     //           letterSpacing: 0.5,
          //     //         ),
          //     //       ),
          //     //     ],
          //     //   ),
          //     //   const SizedBox(height: 16),
          //     //   _buildOrderSummaryRow('Order Number', order.orderNo ?? order.id),
          //     //   const SizedBox(height: 12),
          //     //   _buildOrderSummaryRow('Client Name', order.clientName),
          //     //   const SizedBox(height: 12),
          //     //   _buildOrderSummaryRow('Status', _getStatusText(order.status), isStatus: true, status: order.status),
          //     //   const SizedBox(height: 12),
          //     //   _buildOrderSummaryRow('Description', order.description),
          //     //   const SizedBox(height: 12),
          //     //   _buildOrderSummaryRow('Order Date', _formatDate(order.orderDate!)),
          //     //   if (order.orderType != null) ...[
          //     //     const SizedBox(height: 12),
          //     //     _buildOrderSummaryRow('Order Type', order.orderType!),
          //     //   ],
          //     //   if (order.partynameDisplay != null) ...[
          //     //     const SizedBox(height: 12),
          //     //     _buildOrderSummaryRow('Party Name', order.partynameDisplay!),
          //     //   ],
          //     //   if (order.images.isNotEmpty) ...[
          //     //     const SizedBox(height: 12),
          //     //     _buildOrderSummaryRow('Images', '${order.images.length} attached'),
          //     //   ],
          //     //   if (order.totalQuantity != null) ...[
          //     //     const SizedBox(height: 12),
          //     //     _buildOrderSummaryRow('Total Quantity', '${order.totalQuantity}'),
          //     //   ],
          //     //   if (order.status == OrderStatus.partialDelivery && order.totalDeliveryCount != null) ...[
          //     //     const SizedBox(height: 12),
          //     //     _buildOrderSummaryRow('Delivered', '${order.totalDeliveryCount}/${order.totalQuantity}'),
          //     //   ],
          //     //   if (order.updatedBy != null && order.updatedAt != null) ...[
          //     //     const SizedBox(height: 12),
          //     //     _buildOrderSummaryRow('Last Updated', '${_formatDate(order.updatedAt!)} by ${order.updatedBy}'),
          //     //   ],
          //     // ],
          //   ),
          // ),
          const SizedBox(height: 20),
          if (order.ornamentDetails.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  // Icon(
                  //   Icons.diamond_outlined,
                  //   color: Colors.amber.shade700,
                  //   size: 24,
                  // ),
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
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                    if (detail.images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Images (${detail.images.length})',
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
                          itemCount: detail.images.length,
                          itemBuilder: (context, index) {
                            final imageUrl = detail.images[index];
                            final isPdf = imageUrl.toLowerCase().endsWith(
                              '.pdf',
                            );

                            return GestureDetector(
                              onTap:
                                  () => _showFullScreenImage(
                                    detail.images,
                                    index,
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
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Error',
                                                      style: TextStyle(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade400,
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
          ],

          // Images
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

  void _showFullScreenImage(List<String> images, int initialIndex) async {
    final imageUrl = images[initialIndex];

    // Check if the URL is a PDF
    if (imageUrl.toLowerCase().endsWith('.pdf')) {
      // Open PDF in built-in viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  PdfViewerScreen(pdfUrl: imageUrl, title: 'Order Document'),
        ),
      );
    } else {
      // Open image in full screen viewer
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
                                  .where(
                                    (status) =>
                                        status != OrderStatus.partialDelivery,
                                  )
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
                                          Text(_getStatusText(status)),
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

  bool _hasActiveFilters() {
    return _selectedStatus != null ||
        _selectedOrderType != null ||
        _selectedRange != 'All time' ||
        _searchQuery.isNotEmpty ||
        _sortBy != 'orderDate' ||
        _sortAscending != false || // Default is descending
        _selectedUserId != null; // Include user filter
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
      _sortBy = 'orderDate';
      _sortAscending = false; // Reset to default descending
      _selectedUserId = null; // Clear user filter
      _selectedUserName = null;
    });
    _loadData(); // Reload data from API with cleared filters
  }

  String _formatDate(DateTime date) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('h:mm:ss a'); // 12-hour format with AM/PM
    return '${dateFormat.format(date)} ${timeFormat.format(date)}';
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
}

class FullScreenImageViewer extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Image ${initialIndex + 1} of ${images.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              // Implement share functionality if needed
            },
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(images[index]),
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(tag: index),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
        itemCount: images.length,
        loadingBuilder:
            (context, event) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value:
                          event == null
                              ? 0
                              : event.cumulativeBytesLoaded /
                                  (event.expectedTotalBytes ?? 1),
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
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
                  const SizedBox(height: 16),
                  const Text(
                    'Loading image...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        pageController: PageController(initialPage: initialIndex),
        onPageChanged: (index) {
          // Update app bar title if needed
        },
      ),
    );
  }
}
