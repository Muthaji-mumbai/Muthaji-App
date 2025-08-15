import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../models/order.dart';
import '../../models/user.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _orderTypeController = TextEditingController();
  final _orderDateController = TextEditingController();

  bool _isLoading = false;
  DateTime? _selectedOrderDate;
  String _selectedOrderType = 'Single';
  List<Map<String, dynamic>> _ornamentDetails = [];
  List<String> _selectedImages = [];

  final List<String> _orderTypes = ['Single', 'Bulk', 'Custom'];

  @override
  void initState() {
    super.initState();
    _orderTypeController.text = _selectedOrderType;
    _orderDateController.text = DateTime.now().toIso8601String().split('T')[0];
    _selectedOrderDate = DateTime.now();
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedOrderDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedOrderDate) {
      setState(() {
        _selectedOrderDate = picked;
        _orderDateController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  void _addOrnamentDetail() {
    setState(() {
      _ornamentDetails.add({
        'name': '',
        'material': '',
        'weight': 0.0,
        'purity': '',
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

  Future<void> _pickImages() async {
    // TODO: Implement image picker
    // For now, we'll use placeholder images
    setState(() {
      _selectedImages = ['sample_image_1.jpg', 'sample_image_2.jpg'];
    });
  }

  Future<void> _createOrder() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final currentUser = context.read<AuthProvider>().currentUser;
        final token = AuthService.currentToken;

        if (currentUser != null && token != null) {
          final order = await OrderService.createOrder(
            clientId: currentUser.id,
            clientName: currentUser.name,
            description: _descriptionController.text.trim(),
            amount: double.parse(_amountController.text),
            notes:
                _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
            orderType: _selectedOrderType,
            orderDate: _selectedOrderDate,
            ornamentDetails:
                _ornamentDetails.isNotEmpty ? _ornamentDetails : null,
            images: _selectedImages.isNotEmpty ? _selectedImages : null,
            token: token,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order created successfully! Order ID: ${order.id}',
                ),
                backgroundColor: AppConstants.successColor,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          throw Exception('User not authenticated');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create order: $e'),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Create New Order'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Info Card
                if (currentUser != null) _buildClientInfoCard(currentUser),

                const SizedBox(height: AppConstants.spacingL),

                // Order Form
                Text('Order Details', style: AppConstants.headingSmall),
                const SizedBox(height: AppConstants.spacingM),

                CustomTextField(
                  controller: _descriptionController,
                  labelText: 'Order Description',
                  hintText: 'Describe what you need...',
                  prefixIcon: Icons.description,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter order description';
                    }
                    if (value.length < 10) {
                      return 'Description must be at least 10 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppConstants.spacingM),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _amountController,
                        labelText: 'Amount (\$)',
                        hintText: 'Enter order amount',
                        prefixIcon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter order amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedOrderType,
                        decoration: const InputDecoration(
                          labelText: 'Order Type',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items:
                            _orderTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedOrderType = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppConstants.spacingM),

                GestureDetector(
                  onTap: _selectDate,
                  child: CustomTextField(
                    controller: _orderDateController,
                    labelText: 'Order Date',
                    hintText: 'Select order date',
                    prefixIcon: Icons.calendar_today,
                    enabled: false,
                  ),
                ),

                const SizedBox(height: AppConstants.spacingM),

                CustomTextField(
                  controller: _notesController,
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Any special requirements or notes...',
                  prefixIcon: Icons.note,
                  maxLines: 2,
                ),

                const SizedBox(height: AppConstants.spacingL),

                // Ornament Details Section
                _buildOrnamentDetailsSection(),

                const SizedBox(height: AppConstants.spacingL),

                // Images Section
                _buildImagesSection(),

                const SizedBox(height: AppConstants.spacingXL),

                // Submit Button
                CustomButton(
                  onPressed: _isLoading ? null : _createOrder,
                  text: _isLoading ? 'Creating Order...' : 'Create Order',
                  isLoading: _isLoading,
                  isFullWidth: true,
                  backgroundColor: AppConstants.successColor,
                ),

                const SizedBox(height: AppConstants.spacingM),

                // Cancel Button
                CustomButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  text: 'Cancel',
                  isOutlined: true,
                  isFullWidth: true,
                  backgroundColor: AppConstants.errorColor,
                  textColor: AppConstants.errorColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrnamentDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ornament Details (Optional)',
              style: AppConstants.headingSmall,
            ),
            TextButton.icon(
              onPressed: _addOrnamentDetail,
              icon: const Icon(Icons.add),
              label: const Text('Add Detail'),
            ),
          ],
        ),
        if (_ornamentDetails.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingM),
          ..._ornamentDetails.asMap().entries.map((entry) {
            final index = entry.key;
            final detail = entry.value;
            return _buildOrnamentDetailCard(index, detail);
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildOrnamentDetailCard(int index, Map<String, dynamic> detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Ring, Necklace',
                  ),
                  onChanged:
                      (value) => _updateOrnamentDetail(index, 'name', value),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Material',
                    hintText: 'e.g., Gold, Silver',
                  ),
                  onChanged:
                      (value) =>
                          _updateOrnamentDetail(index, 'material', value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Weight (g)',
                    hintText: '0.0',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged:
                      (value) => _updateOrnamentDetail(
                        index,
                        'weight',
                        double.tryParse(value) ?? 0.0,
                      ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Purity',
                    hintText: 'e.g., 24K, 18K',
                  ),
                  onChanged:
                      (value) => _updateOrnamentDetail(index, 'purity', value),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: '1',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged:
                      (value) => _updateOrnamentDetail(
                        index,
                        'quantity',
                        int.tryParse(value) ?? 1,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _removeOrnamentDetail(index),
                icon: const Icon(Icons.delete, color: AppConstants.errorColor),
                label: Text(
                  'Remove',
                  style: TextStyle(color: AppConstants.errorColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Images (Optional)', style: AppConstants.headingSmall),
        const SizedBox(height: AppConstants.spacingM),
        if (_selectedImages.isNotEmpty) ...[
          Wrap(
            spacing: AppConstants.spacingS,
            runSpacing: AppConstants.spacingS,
            children:
                _selectedImages.map((image) {
                  return Container(
                    padding: const EdgeInsets.all(AppConstants.spacingS),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceColor,
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                      border: Border.all(
                        color: AppConstants.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image, color: AppConstants.primaryColor),
                        const SizedBox(width: AppConstants.spacingXS),
                        Text(image, style: AppConstants.bodySmall),
                        const SizedBox(width: AppConstants.spacingXS),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.remove(image);
                            });
                          },
                          child: Icon(
                            Icons.close,
                            color: AppConstants.errorColor,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: AppConstants.spacingM),
        ],
        CustomButton(
          onPressed: _pickImages,
          text: 'Add Images',
          icon: Icons.add_photo_alternate,
          isOutlined: true,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildClientInfoCard(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
        border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Client Information',
            style: AppConstants.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppConstants.primaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          _buildInfoRow('Name', user.name),
          _buildInfoRow('Email', user.email),
          _buildInfoRow('Phone', user.phone),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppConstants.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppConstants.textSecondaryColor,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppConstants.bodyMedium)),
        ],
      ),
    );
  }
}
