import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

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
      final orders = OrderService.getAllOrders();
      final employees = UserService.getUsersByRole(UserRole.employee);
      
      setState(() {
        _allOrders = orders;
        _filteredOrders = orders;
        _employees = employees;
        _isLoading = false;
      });
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
        bool matchesStatus = _selectedStatus == null || order.status == _selectedStatus;
        bool matchesSearch = _searchQuery.isEmpty || 
            order.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            order.description.toLowerCase().contains(_searchQuery.toLowerCase());
        bool matchesEmployee = _selectedEmployeeId == null || 
            order.assignedEmployeeId == _selectedEmployeeId;
        
        return matchesStatus && matchesSearch && matchesEmployee;
      }).toList();
    });
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      OrderService.updateOrderStatus(order.id, newStatus);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated successfully')),
        );
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
      // Use updateOrderStatus with assignedEmployeeId parameter
      OrderService.updateOrderStatus(order.id, order.status, assignedEmployeeId: employeeId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order assigned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning order: $e')),
        );
      }
    }
  }

  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Client', order.clientName),
              _buildDetailRow('Description', order.description),
              _buildDetailRow('Amount', '\$${order.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Status', order.statusText),
              _buildDetailRow('Created', _formatDate(order.createdAt)),
              if (order.updatedAt != null) _buildDetailRow('Updated', _formatDate(order.updatedAt!)),
              if (order.notes != null && order.notes!.isNotEmpty) _buildDetailRow('Notes', order.notes!),
              if (order.assignedEmployeeId != null) 
                _buildDetailRow('Assigned To', _getEmployeeName(order.assignedEmployeeId!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppConstants.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppConstants.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppConstants.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _getEmployeeName(String employeeId) {
    final employee = _employees.firstWhere(
      (e) => e.id == employeeId,
      orElse: () => User(
        id: '',
        name: 'Unknown',
        email: '',
        phone: '',
        role: UserRole.employee,
        createdAt: DateTime.now(),
        isActive: true,
      ),
    );
    return employee.name;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Soloshine by muthaji - Manage Orders'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filters Section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: AppConstants.cardShadow,
                  ),
                  child: Column(
                    children: [
                      // Search and Status Filter
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _searchController,
                              labelText: 'Search Orders',
                              hintText: 'Search by client name or description...',
                              prefixIcon: Icons.search,
                            ),
                          ),
                          SizedBox(width: 16),
                          DropdownButton<OrderStatus>(
                            value: _selectedStatus,
                            hint: Text('All Statuses'),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text('All Statuses'),
                              ),
                              ...OrderStatus.values.map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.name.toUpperCase()),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedStatus = value);
                              _applyFilters();
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Employee Filter
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedEmployeeId,
                              hint: Text('All Employees'),
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('All Employees'),
                                ),
                                ..._employees.map((employee) => DropdownMenuItem(
                                  value: employee.id,
                                  child: Text(employee.name),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedEmployeeId = value);
                                _applyFilters();
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          CustomButton(
                            text: 'Clear Filters',
                            onPressed: () {
                              setState(() {
                                _selectedStatus = null;
                                _searchQuery = '';
                                _selectedEmployeeId = null;
                              });
                              _applyFilters();
                            },
                            isOutlined: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Orders List
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: AppConstants.textSecondary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No orders found',
                                style: AppConstants.headlineSmall.copyWith(
                                  color: AppConstants.textSecondaryColor,
                                ),
                              ),
                              Text(
                                'Try adjusting your filters',
                                style: AppConstants.bodyMedium.copyWith(
                                  color: AppConstants.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _buildOrderCard(order);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.clientName,
                        style: AppConstants.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Order #${order.id.substring(0, 8)}',
                        style: AppConstants.bodySmall.copyWith(
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: order.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: order.statusColor),
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
            
            SizedBox(height: 12),
            
            // Description
            Text(
              order.description,
              style: AppConstants.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            SizedBox(height: 12),
            
            // Details
            Row(
              children: [
                Icon(Icons.attach_money, size: 16, color: AppConstants.textSecondary),
                SizedBox(width: 4),
                Text(
                  '\$${order.amount.toStringAsFixed(2)}',
                  style: AppConstants.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppConstants.primaryColor,
                  ),
                ),
                Spacer(),
                Icon(Icons.calendar_today, size: 16, color: AppConstants.textSecondaryColor),
                SizedBox(width: 4),
                Text(
                  _formatDate(order.createdAt),
                  style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondaryColor,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'View Details',
                    onPressed: () => _showOrderDetails(order),
                    isOutlined: true,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: CustomButton(
                    text: 'Update Status',
                    onPressed: () => _showStatusUpdateDialog(order),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: CustomButton(
                    text: 'Assign',
                    onPressed: () => _showAssignmentDialog(order),
                    isOutlined: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusUpdateDialog(Order order) {
    OrderStatus? selectedStatus = order.status;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: OrderStatus.values.map((status) => RadioListTile<OrderStatus>(
            title: Text(status.name.toUpperCase()),
            value: status,
            groupValue: selectedStatus,
            onChanged: (value) => selectedStatus = value,
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          CustomButton(
            text: 'Update',
            onPressed: () {
              if (selectedStatus != null && selectedStatus != order.status) {
                _updateOrderStatus(order, selectedStatus!);
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showAssignmentDialog(Order order) {
    String? selectedEmployeeId = order.assignedEmployeeId;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Order to Employee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: selectedEmployeeId,
              hint: Text('Select Employee'),
              isExpanded: true,
              items: _employees.map((employee) => DropdownMenuItem(
                value: employee.id,
                child: Text(employee.name),
              )).toList(),
              onChanged: (value) => selectedEmployeeId = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          CustomButton(
            text: 'Assign',
            onPressed: () {
              if (selectedEmployeeId != null) {
                _assignOrder(order, selectedEmployeeId!);
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
