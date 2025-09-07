import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';

class UpdateOrderScreen extends StatefulWidget {
  final String orderId;

  const UpdateOrderScreen({super.key, required this.orderId});

  @override
  State<UpdateOrderScreen> createState() => _UpdateOrderScreenState();
}

class _UpdateOrderScreenState extends State<UpdateOrderScreen> {
  Order? _order;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _error;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _orderTypeController = TextEditingController();
  final _orderDateController = TextEditingController();

  // Selected values
  OrderStatus _selectedStatus = OrderStatus.pending;
  DateTime _selectedDate = DateTime.now();
  List<String> _images = [];
  List<Map<String, dynamic>> _ornamentDetails = [];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _orderTypeController.dispose();
    _orderDateController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('No authentication token available');
      }

      final order = await OrderService.getOrderById(widget.orderId, token);

      if (order == null) {
        throw Exception('Order not found');
      }

      setState(() {
        _order = order;
        _selectedStatus = order.status;
        _selectedDate = order.orderDate ?? DateTime.now();
        _images = List.from(order.images);
        _ornamentDetails =
            order.ornamentDetails.map((detail) => detail.toJson()).toList();

        // Initialize form controllers
        _descriptionController.text = order.description;
        _amountController.text = order.amount.toString();
        _notesController.text = order.notes ?? '';
        _orderTypeController.text = order.orderType ?? 'Single';
        _orderDateController.text =
            _selectedDate.toIso8601String().split('T')[0];

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.currentUser?.token;

      if (token == null) {
        throw Exception('No authentication token available');
      }

      final updateData = <String, dynamic>{
        'userid': _order!.clientId,
        'description': _descriptionController.text.trim(),
        'amount': double.parse(_amountController.text),
        'status': _selectedStatus.toString().split('.').last,
        'ordertype': _orderTypeController.text.trim(),
        'orderdate': _selectedDate.toIso8601String(),
        'image': _images,
        'ornamentdetails': _ornamentDetails,
      };

      if (_notesController.text.trim().isNotEmpty) {
        updateData['notes'] = _notesController.text.trim();
      }

      await OrderService.updateOrder(
        orderId: widget.orderId,
        updateData: updateData,
        token: token,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order updated successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _addImage() {
    // In a real app, this would open image picker
    // For now, we'll add a placeholder image URL
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Image'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter image URL:'),
                const SizedBox(height: AppConstants.spacingM),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/image.jpg',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (url) {
                    if (url.isNotEmpty) {
                      setState(() {
                        _images.add(url);
                      });
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  // Add placeholder image
                  setState(() {
                    _images.add(
                      'https://via.placeholder.com/300x200?text=Image+${_images.length + 1}',
                    );
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Add Placeholder'),
              ),
            ],
          ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _addOrnamentDetail() {
    setState(() {
      _ornamentDetails.add({
        'name': 'New Ornament',
        'material': 'Gold',
        'weight': 5.0,
        'purity': '18K',
        'quantity': 1,
      });
    });
  }

  void _removeOrnamentDetail(int index) {
    setState(() {
      _ornamentDetails.removeAt(index);
    });
  }

  void _updateOrnamentDetail(int index, String field, dynamic value) {
    setState(() {
      _ornamentDetails[index][field] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Update Order'),
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Update Order'),
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppConstants.errorColor,
              ),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'Error loading order',
                style: AppConstants.headingSmall.copyWith(
                  color: AppConstants.errorColor,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                _error!,
                style: AppConstants.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingM),
              CustomButton(
                onPressed: _loadOrder,
                text: 'Retry',
                icon: Icons.refresh,
              ),
            ],
          ),
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Update Order'),
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Update Order #${_order!.orderNo}'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Information
              _buildSectionHeader('Order Information'),
              const SizedBox(height: AppConstants.spacingM),

              CustomTextField(
                controller: _descriptionController,
                labelText: 'Description',
                hintText: 'Enter order description',
                prefixIcon: Icons.description,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppConstants.spacingM),

              CustomTextField(
                controller: _amountController,
                labelText: 'Amount',
                hintText: 'Enter order amount',
                prefixIcon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Amount is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppConstants.spacingM),

              CustomTextField(
                controller: _orderTypeController,
                labelText: 'Order Type',
                hintText: 'Enter order type',
                prefixIcon: Icons.category,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Order type is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppConstants.spacingM),

              // Date Picker
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                      _orderDateController.text =
                          date.toIso8601String().split('T')[0];
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Order Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_orderDateController.text),
                ),
              ),

              const SizedBox(height: AppConstants.spacingM),

              // Status Dropdown
              DropdownButtonFormField<OrderStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.info),
                  border: OutlineInputBorder(),
                ),
                items:
                    OrderStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(_getStatusText(status)),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedStatus = value);
                  }
                },
              ),

              const SizedBox(height: AppConstants.spacingM),

              CustomTextField(
                controller: _notesController,
                labelText: 'Notes',
                hintText: 'Enter additional notes',
                prefixIcon: Icons.note,
                maxLines: 3,
              ),

              const SizedBox(height: AppConstants.spacingL),

              // Images Section
              _buildSectionHeader('Images'),
              const SizedBox(height: AppConstants.spacingM),

              if (_images.isNotEmpty)
                ..._images.asMap().entries.map((entry) {
                  final index = entry.key;
                  final imageUrl = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(
                      bottom: AppConstants.spacingS,
                    ),
                    padding: const EdgeInsets.all(AppConstants.spacingS),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppConstants.textSecondaryColor.withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            imageUrl,
                            style: AppConstants.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: AppConstants.errorColor,
                          ),
                          onPressed: () => _removeImage(index),
                        ),
                      ],
                    ),
                  );
                }).toList(),

              CustomButton(
                onPressed: _addImage,
                text: 'Add Image',
                icon: Icons.add_photo_alternate,
                backgroundColor: AppConstants.accentColor,
                isFullWidth: true,
              ),

              const SizedBox(height: AppConstants.spacingL),

              // Ornament Details Section
              _buildSectionHeader('Ornament Details'),
              const SizedBox(height: AppConstants.spacingM),

              if (_ornamentDetails.isNotEmpty)
                ..._ornamentDetails.asMap().entries.map((entry) {
                  final index = entry.key;
                  final detail = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(
                      bottom: AppConstants.spacingM,
                    ),
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceColor,
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      border: Border.all(
                        color: AppConstants.textSecondaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ornament ${index + 1}',
                              style: AppConstants.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: AppConstants.errorColor,
                              ),
                              onPressed: () => _removeOrnamentDetail(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.spacingS),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: detail['name'],
                                ),
                                onChanged:
                                    (value) => _updateOrnamentDetail(
                                      index,
                                      'name',
                                      value,
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingS),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Material',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: detail['material'],
                                ),
                                onChanged:
                                    (value) => _updateOrnamentDetail(
                                      index,
                                      'material',
                                      value,
                                    ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppConstants.spacingS),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Weight',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(
                                  text: detail['weight'].toString(),
                                ),
                                onChanged:
                                    (value) => _updateOrnamentDetail(
                                      index,
                                      'weight',
                                      double.tryParse(value) ?? 0.0,
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingS),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Purity',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: detail['purity'],
                                ),
                                onChanged:
                                    (value) => _updateOrnamentDetail(
                                      index,
                                      'purity',
                                      value,
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingS),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(
                                  text: detail['quantity'].toString(),
                                ),
                                onChanged:
                                    (value) => _updateOrnamentDetail(
                                      index,
                                      'quantity',
                                      int.tryParse(value) ?? 0,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),

              CustomButton(
                onPressed: _addOrnamentDetail,
                text: 'Add Ornament Detail',
                icon: Icons.add,
                backgroundColor: AppConstants.successColor,
                isFullWidth: true,
              ),

              const SizedBox(height: AppConstants.spacingXL),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  onPressed: _isUpdating ? null : _updateOrder,
                  text: _isUpdating ? 'Updating...' : 'Update Order',
                  isLoading: _isUpdating,
                  backgroundColor: AppConstants.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: Text(
        title,
        style: AppConstants.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppConstants.primaryColor,
        ),
      ),
    );
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
}
