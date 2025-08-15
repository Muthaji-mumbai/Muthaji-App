import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  // Services are static, so we don't need instances

  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  List<User> _employees = [];

  OrderStatus? _selectedStatus;
  String _searchQuery = '';
  String? _selectedEmployeeId;
  final TextEditingController _searchController = TextEditingController();

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
        final employees = await UserService.getUsersByRole(
          UserRole.employee,
          token,
        );

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredOrders =
          _allOrders.where((order) {
            bool matchesStatus =
                _selectedStatus == null || order.status == _selectedStatus;
            bool matchesSearch =
                _searchQuery.isEmpty ||
                order.clientName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                order.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
            bool matchesEmployee =
                _selectedEmployeeId == null ||
                order.assignedEmployeeId == _selectedEmployeeId;

            return matchesStatus && matchesSearch && matchesEmployee;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating order: $e')));
      }
    }
  }

  Future<void> _assignOrder(Order order, String employeeId) async {
    try {
      final token = AuthService.currentToken;
      if (token != null) {
        // Use updateOrderStatus with assignedEmployeeId parameter
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error assigning order: $e')));
      }
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Order'),
            content: const Text(
              'Are you sure you want to delete this order? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppConstants.errorColor,
                ),
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

          // Reload orders
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
    ).then((_) {
      // Reload orders when returning from update screen
      _loadData();
    });
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
            // Search and Filter Section
            _buildSearchAndFilterSection(),
            const SizedBox(height: AppConstants.spacingM),

            // Orders List
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : _buildOrdersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Column(
      children: [
        // Search Bar
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search orders...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),

        // Filters Row
        Row(
          children: [
            // Status Filter
            Expanded(
              child: DropdownButtonFormField<OrderStatus>(
                decoration: const InputDecoration(
                  labelText: 'Filter by Status',
                  border: OutlineInputBorder(),
                ),
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
            const SizedBox(width: AppConstants.spacingS),

            // Clear Filters Button
            CustomButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedStatus = null;
                  _selectedEmployeeId = null;
                });
                _applyFilters();
              },
              text: 'Clear Filters',
              backgroundColor: AppConstants.secondaryColor,
            ),
          ],
        ),
      ],
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
            color: AppConstants.textSecondaryColor,
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            'No orders found',
            style: AppConstants.headingMedium.copyWith(
              color: AppConstants.textSecondaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Try adjusting your search or filter criteria',
            style: AppConstants.bodyMedium.copyWith(
              color: AppConstants.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return ListView.builder(
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.description,
                    style: AppConstants.headingSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(order.status),
              ],
            ),
            const SizedBox(height: AppConstants.spacingS),

            // Order Details
            _buildOrderDetail('Order ID', order.id),
            _buildOrderDetail('Client', order.clientName),
            _buildOrderDetail('Amount', '\$${order.amount.toStringAsFixed(2)}'),
            _buildOrderDetail('Created', _formatDate(order.createdAt)),
            if (order.orderType != null)
              _buildOrderDetail('Type', order.orderType!),
            if (order.orderDate != null)
              _buildOrderDetail('Order Date', _formatDate(order.orderDate!)),
            if (order.notes != null && order.notes!.isNotEmpty)
              _buildOrderDetail('Notes', order.notes!),

            // Ornament Details
            if (order.ornamentDetails.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'Ornament Details:',
                style: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXS),
              ...order.ornamentDetails.map(
                (detail) => Padding(
                  padding: const EdgeInsets.only(left: AppConstants.spacingM),
                  child: Text(
                    '• ${detail.name} - ${detail.material} (${detail.weight}g, ${detail.purity}) x${detail.quantity}',
                    style: AppConstants.bodySmall,
                  ),
                ),
              ),
            ],

            // Images
            if (order.images.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'Images:',
                style: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXS),
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
                                  .withOpacity(0.1),
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

            const SizedBox(height: AppConstants.spacingM),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    onPressed: () => _navigateToUpdateOrder(order),
                    text: 'Edit Order',
                    backgroundColor: AppConstants.secondaryColor,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: CustomButton(
                    onPressed: () => _showStatusUpdateDialog(order),
                    text: 'Update Status',
                    backgroundColor: AppConstants.primaryColor,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: CustomButton(
                    onPressed: () => _deleteOrder(order.id),
                    text: 'Delete',
                    backgroundColor: AppConstants.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildStatusChip(OrderStatus status) {
    Color chipColor;
    String statusText;

    switch (status) {
      case OrderStatus.pending:
        chipColor = AppConstants.warningColor;
        statusText = 'Pending';
        break;
      case OrderStatus.confirmed:
        chipColor = AppConstants.primaryColor;
        statusText = 'Confirmed';
        break;
      case OrderStatus.inProgress:
        chipColor = AppConstants.secondaryColor;
        statusText = 'In Progress';
        break;
      case OrderStatus.completed:
        chipColor = AppConstants.successColor;
        statusText = 'Completed';
        break;
      case OrderStatus.cancelled:
        chipColor = AppConstants.errorColor;
        statusText = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingS,
        vertical: AppConstants.spacingXS,
      ),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        statusText,
        style: AppConstants.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showStatusUpdateDialog(Order order) {
    OrderStatus? selectedStatus = order.status;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Update Order Status'),
            content: StatefulBuilder(
              builder:
                  (context, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Current Status: ${order.status.toString().split('.').last}',
                      ),
                      const SizedBox(height: AppConstants.spacingM),
                      DropdownButtonFormField<OrderStatus>(
                        decoration: const InputDecoration(
                          labelText: 'New Status',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedStatus,
                        items:
                            OrderStatus.values
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(
                                      status.toString().split('.').last,
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
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (selectedStatus != null &&
                      selectedStatus != order.status) {
                    Navigator.of(context).pop();
                    _updateOrderStatus(order, selectedStatus!);
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
