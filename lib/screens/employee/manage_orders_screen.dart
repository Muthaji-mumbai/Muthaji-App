import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:soloshine/screens/employee/order_detailed_screen.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'update_order_screen.dart';

class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  List<User> _employees = [];

  OrderStatus? _selectedStatus;
  String _searchQuery = '';
  String? _selectedEmployeeId;
  final TextEditingController _searchController = TextEditingController();

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

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final token = AuthService.currentToken;
      if (token != null) {
        final orders = await OrderService.getAllOrders(token);
        final employees = await UserService.getUsersByRole(UserRole.employee, token);

        setState(() {
          _allOrders = orders;
          _filteredOrders = orders;
          _employees = employees;
          _isLoading = false;
        });
      } else {
        throw Exception('No authentication token');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        final matchesStatus = _selectedStatus == null || order.status == _selectedStatus;
        final matchesSearch = _searchQuery.isEmpty ||
            order.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            order.description.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesEmployee = _selectedEmployeeId == null || order.assignedEmployeeId == _selectedEmployeeId;

        final created = order.createdAt;
        bool matchesDate = true;
        final now = DateTime.now();
        switch (_selectedRange) {
          case 'All time':
            matchesDate = true;
            break;
          case 'Today':
            final startOfDay = DateTime(now.year, now.month, now.day);
            final endOfDay = startOfDay.add(const Duration(days: 1));
            matchesDate = created.isAfter(startOfDay) && created.isBefore(endOfDay);
            break;
          case 'Last 7 days':
            final from = now.subtract(const Duration(days: 7));
            matchesDate = created.isAfter(from);
            break;
          case 'Last 30 days':
            final from = now.subtract(const Duration(days: 30));
            matchesDate = created.isAfter(from);
            break;
          case 'Custom':
            if (_startDate != null) {
              final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
              if (created.isBefore(start)) matchesDate = false;
            }
            if (_endDate != null) {
              final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day).add(const Duration(days: 1));
              if (created.isAfter(end)) matchesDate = false;
            }
            break;
        }

        return matchesStatus && matchesSearch && matchesEmployee && matchesDate;
      }).toList();
    });
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
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order status updated successfully')),
          );
        }
      } else {
        throw Exception('No authentication token');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e')),
        );
      }
    }
  }

  Future<void> _assignOrder(Order order, String employeeId) async {
    try {
      final token = AuthService.currentToken;
      if (token != null) {
        await OrderService.updateOrderStatus(
          orderId: order.id,
          newStatus: order.status,
          assignedEmployeeId: employeeId,
          token: token,
        );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order assigned successfully')),
          );
        }
      } else {
        throw Exception('No authentication token');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning order: $e')),
        );
      }
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to delete this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppConstants.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final token = AuthService.currentToken;
        if (token != null) {
          await OrderService.deleteOrder(orderId: orderId, token: token);
          await _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order deleted successfully'),
              backgroundColor: AppConstants.successColor,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting order: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  void _navigateToUpdateOrder(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateOrderScreen(orderId: order.id),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterBar(),
            const SizedBox(height: AppConstants.spacingM),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _buildOrderCard(order);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingS),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            controller: _searchController,
            hintText: 'Search by client or description...',
            prefixIcon: Icons.search,
            labelText: 'Search',
          ),
          const SizedBox(height: AppConstants.spacingS),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<OrderStatus>(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingXS,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                  ),
                  hint: const Text('Filter by Status'),
                  value: _selectedStatus,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Statuses'),
                    ),
                    ...OrderStatus.values.map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toString().split('.').last),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _selectedStatus = value;
                    _applyFilters();
                  },
                ),
              ),
              if (!isMobile) const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingXS,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                  ),
                  hint: const Text('Date Range'),
                  value: _selectedRange,
                  items: _ranges
                      .map((r) => DropdownMenuItem<String>(value: r, child: Text(r)))
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
                        initialDateRange: _startDate != null && _endDate != null
                            ? DateTimeRange(start: _startDate!, end: _endDate!)
                            : null,
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked.start;
                          _endDate = picked.end;
                        });
                      }
                    }
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          if (_selectedStatus != null || _selectedRange != 'All time' || _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.spacingS),
              child: CustomButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.text = '';
                    _selectedStatus = null;
                    _selectedRange = 'All time';
                    _startDate = null;
                    _endDate = null;
                  });
                  _applyFilters();
                },
                text: 'Clear Filters',
                backgroundColor: AppConstants.secondaryColor,
                isFullWidth: isMobile,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppConstants.textSecondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            'No Orders Found',
            style: AppConstants.headingMedium.copyWith(
              color: AppConstants.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Try adjusting your filters or search terms',
            style: AppConstants.bodyMedium.copyWith(
              color: AppConstants.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(order.status).withOpacity(0.1),
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
              style: AppConstants.bodyMedium.copyWith(color: AppConstants.textSecondaryColor),
            ),
            
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'edit') {
              _navigateToUpdateOrder(order);
            } else if (value == 'status') {
              _showStatusUpdateDialog(order);
            } else if (value == 'assign') {
              _showAssignEmployeeDialog(order);
            } else if (value == 'delete') {
              _deleteOrder(order.id);
            } else if (value == 'full_details') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailsScreen(order: order),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit Order'),
            ),
            const PopupMenuItem(
              value: 'status',
              child: Text('Update Status'),
            ),
            const PopupMenuItem(
              value: 'assign',
              child: Text('Assign Employee'),
            ),
            const PopupMenuItem(
              value: 'full_details',
              child: Text('Full Details'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete Order'),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderDetail('Order ID', order.id),
                if (order.orderType != null) _buildOrderDetail('Type', order.orderType!),
                if (order.orderDate != null) _buildOrderDetail('Order Date', _formatDate(order.orderDate!)),
                if (order.notes != null && order.notes!.isNotEmpty) _buildOrderDetail('Notes', order.notes!),
                if (order.ornamentDetails.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Ornament Details:',
                    style: AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  ...order.ornamentDetails.map(
                    (detail) => Padding(
                      padding: const EdgeInsets.only(left: AppConstants.spacingM, top: AppConstants.spacingXS),
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
                    style: AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: order.images.length,
                      itemBuilder: (context, index) {
                        final imageUrl = order.images[index];
                        return GestureDetector(
                          onTap: () => _showFullScreenImage(order.images, index),
                          child: Container(
                            margin: const EdgeInsets.only(right: AppConstants.spacingS),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 80,
                                    height: 80,
                                    color: AppConstants.textSecondaryColor.withOpacity(0.1),
                                    child: const Icon(Icons.image_not_supported),
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

  void _showFullScreenImage(List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _showStatusUpdateDialog(Order order) {
    OrderStatus? selectedStatus = order.status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Status: ${order.status.toString().split('.').last}',
                style: AppConstants.bodyMedium,
              ),
              const SizedBox(height: AppConstants.spacingM),
              DropdownButtonFormField<OrderStatus>(
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingXS,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  ),
                ),
                value: selectedStatus,
                items: OrderStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toString().split('.').last),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CustomButton(
            onPressed: () {
              if (selectedStatus != null && selectedStatus != order.status) {
                Navigator.of(context).pop();
                _updateOrderStatus(order, selectedStatus!);
              }
            },
            text: 'Update',
            backgroundColor: AppConstants.primaryColor,
          ),
        ],
      ),
    );
  }

  void _showAssignEmployeeDialog(Order order) {
    String? selectedEmployeeId = order.assignedEmployeeId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Employee'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingXS,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  ),
                ),
                hint: const Text('Select Employee'),
                value: selectedEmployeeId,
                items: _employees
                    .map(
                      (employee) => DropdownMenuItem(
                        value: employee.id,
                        child: Text(employee.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedEmployeeId = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CustomButton(
            onPressed: () {
              if (selectedEmployeeId != null && selectedEmployeeId != order.assignedEmployeeId) {
                Navigator.of(context).pop();
                _assignOrder(order, selectedEmployeeId!);
              }
            },
            text: 'Assign',
            backgroundColor: AppConstants.primaryColor,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppConstants.warningColor;
      case OrderStatus.confirmed:
        return AppConstants.primaryColor;
      case OrderStatus.inProgress:
        return AppConstants.secondaryColor;
      case OrderStatus.completed:
        return AppConstants.successColor;
      case OrderStatus.cancelled:
        return AppConstants.errorColor;
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
      body: GestureDetector(
        child: PhotoViewGallery.builder(
          scrollPhysics: const BouncingScrollPhysics(),
          builder: (BuildContext context, int index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: NetworkImage(images[index]),
              initialScale: PhotoViewComputedScale.contained,
              heroAttributes: PhotoViewHeroAttributes(tag: index),
            );
          },
          itemCount: images.length,
          loadingBuilder: (context, event) => Center(
            child: SizedBox(
              width: 20.0,
              height: 20.0,
              child: CircularProgressIndicator(
                value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
              ),
            ),
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          pageController: PageController(initialPage: initialIndex),
        ),
        onTap: () => Navigator.pop(context),
      ),
    );
  }
}
