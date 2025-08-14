import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/order_service.dart';
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
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final currentUser = context.read<AuthProvider>().currentUser;
        if (currentUser != null) {
          final order = OrderService.createOrder(
            clientId: currentUser.id,
            clientName: currentUser.name,
            description: _descriptionController.text.trim(),
            amount: double.parse(_amountController.text),
            notes: _notesController.text.trim().isEmpty 
                ? null 
                : _notesController.text.trim(),
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order created successfully! Order ID: ${order.id}'),
                backgroundColor: AppConstants.successColor,
              ),
            );
            Navigator.pop(context, true);
          }
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
                Text(
                  'Order Details',
                  style: AppConstants.headingSmall,
                ),
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
                
                CustomTextField(
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
                
                const SizedBox(height: AppConstants.spacingM),
                
                CustomTextField(
                  controller: _notesController,
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Any special requirements or notes...',
                  prefixIcon: Icons.note,
                  maxLines: 2,
                ),
                
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

  Widget _buildClientInfoCard(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.2),
        ),
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
}
