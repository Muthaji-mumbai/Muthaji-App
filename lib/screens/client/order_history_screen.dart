import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';

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
  DateTime? _fromDate;
  DateTime? _toDate;
  final Set<int> _expanded = <int>{};

  @override
  void initState() {
    super.initState();
    _loadOrders();
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
          ),
        );
      }
    }
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

      // Apply date range filter (by createdAt)
      if (_fromDate != null) {
        final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        if (order.createdAt.isBefore(from)) return false;
      }
      if (_toDate != null) {
        final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59, 999);
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
        title: const Text('Muthaji - Order History'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
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
                          itemCount: _filteredOrders.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) return _buildTableHeader();
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

          // Filters header
          Row(
            children: [
              Text('Filters',
                  style: AppConstants.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),

          const SizedBox(height: AppConstants.spacingS),

          // Status Filter (restyled chips)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppConstants.spacingS,
              runSpacing: AppConstants.spacingS,
              children: [
                _buildStatusChip(null, 'All'),
                ...OrderStatus.values.map(
                  (status) => _buildStatusChip(status, _getStatusText(status)),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Date range filter (bordered fields)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(isFrom: true),
                  child: _buildDateField(
                    label: 'From Date',
                    date: _fromDate,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(isFrom: false),
                  child: _buildDateField(
                    label: 'To Date',
                    date: _toDate,
                  ),
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
              )
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
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
          // Ensure from <= to
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

  Widget _buildStatusChip(OrderStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    final color =
        status != null ? _getStatusColor(status) : AppConstants.primaryColor;

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
          color:
              isSelected
                  ? color
                  : AppConstants.textSecondaryColor.withOpacity(0.3),
        ),
      ),
    );
  }

  // Header row for the table-like layout
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 48,
            child: Text('Sl No', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 3,
            child: Text('Order number',
                style: AppConstants.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Text('Type',
                style: AppConstants.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Text('Order date',
                style: AppConstants.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Collapsible row with summary and expandable details
  Widget _buildOrderTile(int index, Order order) {
    final isOpen = _expanded.contains(index);
    return Container(
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
          title: _buildOrderSummary(index, order),
          childrenPadding: const EdgeInsets.all(AppConstants.spacingM),
          children: [
            _buildOrderDetails(order),
          ],
        ),
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
              child: Text('${index + 1}',
                  style: AppConstants.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Order #${order.id.substring(0, 8)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppConstants.primaryColor,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                order.orderType ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppConstants.bodySmall,
              ),
            ),
            Expanded(
              flex: 2,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badge in details
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingS,
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
            ),
          ],
        ),

        const SizedBox(height: AppConstants.spacingM),

        // Created/Updated detailed
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Created: ${_formatDate(order.createdAt)}',
                style: AppConstants.bodySmall.copyWith(
                    color: AppConstants.textSecondaryColor)),
            if (order.updatedAt != null)
              Text('Updated: ${_formatDate(order.updatedAt!)}',
                  style: AppConstants.bodySmall
                      .copyWith(color: AppConstants.textSecondaryColor)),
          ],
        ),

        // Order type/date
        if (order.orderType != null || order.orderDate != null)
          Row(
            children: [
              if (order.orderType != null)
                Text('Type: ${order.orderType!}',
                    style: AppConstants.bodySmall),
              if (order.orderType != null && order.orderDate != null)
                const SizedBox(width: AppConstants.spacingL),
              if (order.orderDate != null)
                Text('Order Date: ${_formatDate(order.orderDate!)}',
                    style: AppConstants.bodySmall),
            ],
          ),

        // Ornament details
        if (order.ornamentDetails.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingM),
          Text('Ornament Details',
              style: AppConstants.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: AppConstants.spacingS),
          ...order.ornamentDetails.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(d.name, style: AppConstants.bodyMedium),
                    ),
                    Text('${d.material} • ${d.purity}',
                        style: AppConstants.bodySmall.copyWith(
                            color: AppConstants.textSecondaryColor)),
                    const SizedBox(width: AppConstants.spacingM),
                    Text('${d.weight}g x ${d.quantity}',
                        style: AppConstants.bodySmall.copyWith(
                            color: AppConstants.textSecondaryColor)),
                  ],
                ),
              )),
        ],

        // Notes
        if (order.notes != null && order.notes!.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingM),
          Text('Notes',
              style: AppConstants.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: AppConstants.spacingXS),
          Text(order.notes!, style: AppConstants.bodySmall),
        ],

        // Attachments info
        if (order.images.isNotEmpty || order.pdfs.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingM),
          if (order.images.isNotEmpty) ...[
            Text('Images',
                style: AppConstants.bodyMedium
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppConstants.spacingS),
            _buildImageThumbnails(order.images),
            const SizedBox(height: AppConstants.spacingM),
          ],
          if (order.pdfs.isNotEmpty)
            Chip(
              avatar: const Icon(Icons.picture_as_pdf, size: 18),
              label: Text('${order.pdfs.length} PDF(s)'),
            ),
        ],
      ],
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

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  errorBuilder: (context, error, stack) => SizedBox(
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
    final text = date == null
        ? label
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        border: Border.all(color: AppConstants.textSecondaryColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: Text(
              text,
              style: AppConstants.bodySmall.copyWith(
                color: date == null
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
