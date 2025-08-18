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

class _CreateOrderScreenState extends State<CreateOrderScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _orderDateController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _orderDateController.dispose();
    _animationController.dispose();
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
        withData: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: $e'),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
        ),
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
            ornamentDetails:
                _ornamentDetails.isNotEmpty ? _ornamentDetails : null,
            images:
                _selectedFiles.isNotEmpty
                    ? _selectedFiles.map((file) => file.name).toList()
                    : null,
            token: token,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        'Order created successfully! ID: ${order.id}',
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppConstants.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
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
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: AppConstants.spacingS),
                  Expanded(child: Text('Failed to create order: $e')),
                ],
              ),
              backgroundColor: AppConstants.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppConstants.primaryColor,
                    AppConstants.secondaryColor.withOpacity(0.8),
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  'Create New Order',
                  style: AppConstants.headingMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingL),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProgressIndicator(),
                        const SizedBox(height: AppConstants.spacingXL),
                        if (currentUser != null)
                          _buildClientInfoCard(currentUser),
                        if (currentUser != null)
                          const SizedBox(height: AppConstants.spacingXL),
                        _buildOrderDetailsCard(),
                        const SizedBox(height: AppConstants.spacingXL),
                        _buildOrnamentSection(),
                        const SizedBox(height: AppConstants.spacingXL),
                        _buildFilesSection(),
                        const SizedBox(height: AppConstants.spacingXL),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildProgressStep(1, 'Details', true),
          Container(
            height: 2,
            width: 60,
            color: AppConstants.primaryColor.withOpacity(0.3),
          ),
          _buildProgressStep(2, 'Ornaments', _ornamentDetails.isNotEmpty),
          Container(
            height: 2,
            width: 60,
            color: AppConstants.primaryColor.withOpacity(0.3),
          ),
          _buildProgressStep(3, 'Files', _selectedFiles.isNotEmpty),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, bool isActive) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor:
              isActive
                  ? AppConstants.primaryColor
                  : AppConstants.textSecondaryColor.withOpacity(0.2),
          child: Text(
            '$step',
            style: AppConstants.bodySmall.copyWith(
              color: isActive ? Colors.white : AppConstants.textSecondaryColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppConstants.bodySmall.copyWith(
            color:
                isActive
                    ? AppConstants.primaryColor
                    : AppConstants.textSecondaryColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildClientInfoCard(User user) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: AppConstants.primaryColor),
              const SizedBox(width: AppConstants.spacingM),
              Text('Client Information', style: AppConstants.headingSmall),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          _buildInfoRow('Name', user.name),
          _buildInfoRow('Email', user.email),
          _buildInfoRow('Phone', user.phone ?? ''),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AppConstants.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppConstants.textPrimaryColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppConstants.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: AppConstants.accentColor),
              const SizedBox(width: AppConstants.spacingM),
              Text('Order Details', style: AppConstants.headingSmall),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          CustomTextField(
            controller: _descriptionController,
            labelText: 'Description',
            hintText: 'Describe your jewelry order',
            prefixIcon: Icons.description,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Please enter description';
              if (value.length < 10) return 'Minimum 10 characters required';
              return null;
            },
          ),
          const SizedBox(height: AppConstants.spacingL),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _amountController,
                  labelText: 'Amount',
                  hintText: '₹0.00',
                  prefixIcon: Icons.currency_rupee,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter amount';
                    if (double.tryParse(value) == null ||
                        double.parse(value) <= 0)
                      return 'Enter valid amount';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(child: _buildDropdown()),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          CustomTextField(
            controller: _orderDateController,
            labelText: 'Delivery Date',
            hintText: 'Select date',
            prefixIcon: Icons.calendar_today,

            onTap: _selectDate,
          ),
          const SizedBox(height: AppConstants.spacingL),
          CustomTextField(
            controller: _notesController,
            labelText: 'Special Instructions',
            hintText: 'Any special requirements',
            prefixIcon: Icons.note,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type',
          style: AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppConstants.spacingS),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            border: Border.all(
              color: AppConstants.primaryColor.withOpacity(0.2),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedOrderType,
              items:
                  _orderTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type, style: AppConstants.bodyMedium),
                    );
                  }).toList(),
              onChanged: (value) => setState(() => _selectedOrderType = value!),
              dropdownColor: AppConstants.surfaceColor,
              icon: Icon(
                Icons.arrow_drop_down,
                color: AppConstants.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrnamentSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.diamond, color: AppConstants.warningColor),
              const SizedBox(width: AppConstants.spacingM),
              Text('Ornament Details', style: AppConstants.headingSmall),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.add, color: AppConstants.primaryColor),
                onPressed: _addOrnamentDetail,
              ),
            ],
          ),
          if (_ornamentDetails.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.spacingL),
              child: Text(
                'No ornament details added. Click + to add.',
                style: AppConstants.bodyMedium.copyWith(
                  color: AppConstants.textSecondaryColor,
                ),
              ),
            )
          else
            ..._ornamentDetails.asMap().entries.map((entry) {
              final index = entry.key;
              final detail = entry.value;
              return Padding(
                padding: const EdgeInsets.only(top: AppConstants.spacingM),
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundColor,
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    border: Border.all(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text('Item ${index + 1}')),
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          color: AppConstants.errorColor,
                        ),
                        onPressed: () => _removeOrnamentDetail(index),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFilesSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, color: AppConstants.accentColor),
              const SizedBox(width: AppConstants.spacingM),
              Text('Attachments', style: AppConstants.headingSmall),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          CustomButton(
            text: 'Upload Files',
            icon: Icons.upload,
            onPressed: _pickFiles,
            backgroundColor: AppConstants.primaryColor,
          ),
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.spacingM),
              child: Wrap(
                spacing: AppConstants.spacingM,
                runSpacing: AppConstants.spacingM,
                children:
                    _selectedFiles
                        .map(
                          (file) => Chip(
                            label: Text(
                              file.name,
                              style: AppConstants.bodySmall,
                            ),
                            onDeleted: () {
                              setState(() {
                                _selectedFiles.remove(file);
                              });
                            },
                          ),
                        )
                        .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CustomButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
          backgroundColor: AppConstants.errorColor,
        ),
        const SizedBox(width: AppConstants.spacingM),
        CustomButton(
          text: 'Create Order',
          onPressed: _createOrder,
          backgroundColor: AppConstants.successColor,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
