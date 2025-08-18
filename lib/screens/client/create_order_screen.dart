import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
  final _orderDateController = TextEditingController();

  bool _isLoading = false;
  DateTime? _selectedOrderDate;
  String _selectedOrderType = 'Single';
  List<Map<String, dynamic>> _ornamentDetails = [];
  List<PlatformFile> _selectedFiles = [];

  final List<String> _orderTypes = ['Single', 'Bulk', 'Custom'];

  @override
  void initState() {
    super.initState();
    _orderDateController.text = DateTime.now().toIso8601String().split('T')[0];
    _selectedOrderDate = DateTime.now();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _orderDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedOrderDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppConstants.primaryColor,
              onPrimary: Colors.white,
              surface: AppConstants.surfaceColor,
            ),
          ),
          child: child!,
        );
      },
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

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking files: $e')),
      );
    }
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
            notes: _notesController.text.trim(),
            orderType: _selectedOrderType,
            orderDate: _selectedOrderDate,
            ornamentDetails: _ornamentDetails.isNotEmpty ? _ornamentDetails : null,
            images: _selectedFiles.isNotEmpty ? _selectedFiles.map((file) => file.name).toList() : null,
            token: token,
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
        title: const Text('Create Order'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (currentUser != null) _buildClientInfoCard(currentUser),
                const SizedBox(height: AppConstants.spacingL),
                
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order Details', style: AppConstants.headingSmall),
                        const SizedBox(height: AppConstants.spacingM),
                        
                        CustomTextField(
                          controller: _descriptionController,
                          labelText: 'Description',
                          hintText: 'Describe your order',
                          prefixIcon: Icons.description,
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter description';
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
                                labelText: 'Amount',
                                hintText: 'Enter amount',
                                prefixIcon: Icons.attach_money,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter amount';
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
                                decoration: InputDecoration(
                                  labelText: 'Type',
                                  prefixIcon: Icon(Icons.category),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                                  ),
                                ),
                                items: _orderTypes.map((type) {
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
                            labelText: 'Date',
                            hintText: 'Select date',
                            prefixIcon: Icons.calendar_today,
                            enabled: false,
                          ),
                        ),
                        
                        const SizedBox(height: AppConstants.spacingM),
                        
                        CustomTextField(
                          controller: _notesController,
                          labelText: 'Notes',
                          hintText: 'Additional notes',
                          prefixIcon: Icons.note,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: AppConstants.spacingL),
                
                _buildOrnamentDetailsSection(),
                
                const SizedBox(height: AppConstants.spacingL),
                
                _buildFilesSection(),
                
                const SizedBox(height: AppConstants.spacingXL),
                
                CustomButton(
                  onPressed: _isLoading ? null : _createOrder,
                  text: _isLoading ? 'Creating...' : 'Create Order',
                  isLoading: _isLoading,
                  backgroundColor: AppConstants.successColor,
                ),
                
                const SizedBox(height: AppConstants.spacingM),
                
                CustomButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  text: 'Cancel',
                  isOutlined: true,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ornament Details', style: AppConstants.headingSmall),
                IconButton(
                  onPressed: _addOrnamentDetail,
                  icon: Icon(Icons.add_circle, color: AppConstants.primaryColor),
                ),
              ],
            ),
            if (_ornamentDetails.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingM),
              ..._ornamentDetails.asMap().entries.map((entry) {
                return _buildOrnamentDetailCard(entry.key, entry.value);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrnamentDetailCard(int index, Map<String, dynamic> detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingS),
      decoration: BoxDecoration(
        border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                  ),
                  onChanged: (value) => setState(() {
                    _ornamentDetails[index]['name'] = value;
                  }),
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Material',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                  ),
                  onChanged: (value) => setState(() {
                    _ornamentDetails[index]['material'] = value;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingS),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Weight (g)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() {
                    _ornamentDetails[index]['weight'] = double.tryParse(value) ?? 0.0;
                  }),
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Purity',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                  ),
                  onChanged: (value) => setState(() {
                    _ornamentDetails[index]['purity'] = value;
                  }),
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() {
                    _ornamentDetails[index]['quantity'] = int.tryParse(value) ?? 1;
                  }),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => _removeOrnamentDetail(index),
              icon: Icon(Icons.delete, color: AppConstants.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attachments', style: AppConstants.headingSmall),
            const SizedBox(height: AppConstants.spacingM),
            if (_selectedFiles.isNotEmpty) ...[
              Wrap(
                spacing: AppConstants.spacingS,
                runSpacing: AppConstants.spacingS,
                children: _selectedFiles.map((file) {
                  return Chip(
                    label: Text(
                      file.name,
                      style: AppConstants.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    avatar: Icon(
                      file.extension == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                      color: AppConstants.primaryColor,
                    ),
                    deleteIcon: Icon(Icons.close, size: 16),
                    deleteIconColor: AppConstants.errorColor,
                    onDeleted: () {
                      setState(() {
                        _selectedFiles.remove(file);
                      });
                    },
                    backgroundColor: AppConstants.surfaceColor,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppConstants.spacingM),
            ],
            CustomButton(
              onPressed: _pickFiles,
              text: 'Add Files',
              icon: Icons.attach_file,
              isOutlined: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfoCard(User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client Information', style: AppConstants.headingSmall),
            const SizedBox(height: AppConstants.spacingM),
            _buildInfoRow('Name', user.name),
            _buildInfoRow('Email', user.email),
            _buildInfoRow('Phone', user.phone),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}