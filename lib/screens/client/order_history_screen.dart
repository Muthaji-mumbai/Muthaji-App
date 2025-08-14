import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  OrderStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _isLoading = true;
    });

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      _allOrders = OrderService.getOrdersByClient(currentUser.id);
      _applyFilters();
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _applyFilters() {
    _filteredOrders = _allOrders.where((order) {
      // Apply status filter
      if (_selectedStatus != null && order.status != _selectedStatus) {
        return false;
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return order.description.toLowerCase().contains(query) ||
               order.id.toLowerCase().contains(query) ||
               order.statusText.toLowerCase().contains(query);
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
        title: const Text('Soloshine by muthaji - Order History'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilterSection(),
          
          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => _loadOrders(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppConstants.spacingM),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(_filteredOrders[index]);
                          },
                        ),
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
          
          // Status Filter
          Row(
            children: [
              Text(
                'Filter by Status:',
                style: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip(null, 'All'),
                                             ...OrderStatus.values.map((status) => _buildStatusChip(status, _getStatusText(status))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    final color = status != null ? _getStatusColor(status) : AppConstants.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.only(right: AppConstants.spacingS),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = selected ? status : null;
            _applyFilters();
          });
        },
        backgroundColor: AppConstants.surfaceColor,
        selectedColor: color.withOpacity(0.2),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: isSelected ? color : AppConstants.textPrimaryColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: isSelected ? color : AppConstants.textSecondaryColor.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Order ID and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Order #${order.id.substring(0, 8)}',
                  style: AppConstants.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: AppConstants.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: order.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
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
          
          const SizedBox(height: AppConstants.spacingS),
          
          // Description
          Text(
            order.description,
            style: AppConstants.bodyLarge.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: AppConstants.spacingS),
          
          // Amount and Dates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${order.amount.toStringAsFixed(2)}',
                style: AppConstants.headingSmall.copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
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
            ],
          ),
          
          // Notes (if any)
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingS),
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingS),
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor,
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
                border: Border.all(
                  color: AppConstants.textSecondaryColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes:',
                    style: AppConstants.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXS),
                  Text(
                    order.notes!,
                    style: AppConstants.bodySmall,
                  ),
                ],
              ),
            ),
          ],
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
            Icons.history,
            size: 64,
            color: AppConstants.textSecondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            _searchQuery.isNotEmpty || _selectedStatus != null
                ? 'No orders match your filters'
                : 'No orders yet',
            style: AppConstants.headingSmall,
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            _searchQuery.isNotEmpty || _selectedStatus != null
                ? 'Try adjusting your search or filters'
                : 'Create your first order to get started',
            style: AppConstants.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty || _selectedStatus != null) ...[
            const SizedBox(height: AppConstants.spacingM),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedStatus = null;
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
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppConstants.warningColor;
      case OrderStatus.confirmed:
        return AppConstants.accentColor;
      case OrderStatus.inProgress:
        return AppConstants.secondaryColor;
      case OrderStatus.completed:
        return AppConstants.successColor;
      case OrderStatus.cancelled:
        return AppConstants.errorColor;
    }
  }
}
