import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../providers/auth_provider.dart';
import '../../models/order.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../models/user.dart';

class CreateOrderScreen extends StatefulWidget {
  final Order? orderToEdit;
  const CreateOrderScreen({super.key, this.orderToEdit});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  final _orderDateController = TextEditingController();
  bool _isLoading = false;
  bool _isPickingImage = false;
  DateTime? _selectedOrderDate;
  String _selectedOrderType = 'Single';
  bool get _isEditMode => widget.orderToEdit != null;
  Order? get _existingOrder => widget.orderToEdit;
  OrderStatus? _selectedStatus;
  List<Map<String, dynamic>> _ornamentDetails = [
    {
      'name': '',
      'categoryId': '', 
      'weight': 0.0,
      'purity': '',
      'quantity': 1,
      'remarks': '',
    }
  ];
  List<List<PlatformFile>> _ornamentImages = [[]];
  // For edit mode: store existing image URLs per ornament item (display only)
  List<List<String>> _existingOrnamentImageUrls = [[]];
  File? _currentEditingImage;
  final ImagePicker _picker = ImagePicker();
  List<Datum> _categories = []; 
  bool _loadingCategories = true; 
  String? _categoriesError; 
  static const List<String> _purityOptions = [
    '18K Yellow gold',
    '18K Rose gold', 
    '18K White gold',
    'Other'
  ];
  
  static const List<String> _orderTypeOptions = [
    'Single',
    'Bulk'
  ];

  Future<void> _updateOrder() async {
    if (_formKey.currentState!.validate() && !_isLoading && _existingOrder != null) {
      setState(() => _isLoading = true);
      try {
        final token = AuthService.currentToken;
        if (token == null) throw Exception('User not authenticated');

        final detailsPayload = _ornamentDetails.map((d) => {
              'name': d['categoryId'],
              'weight': d['weight'],
              'purity': d['purity'],
              'quantity': d['quantity'],
              if ((d['remarks'] as String).isNotEmpty) 'remarks': d['remarks'],
            }).toList();

        final updateData = <String, dynamic>{
          'orderdate': (_selectedOrderDate ?? DateTime.now()).toIso8601String().split('T').first,
          'ordertype': _selectedOrderType,
          'ornamentDetails': detailsPayload,
        };
        // Include status in update only for admin/employee users
        if (_selectedStatus != null && _shouldShowOrderTypeSelection()) {
          updateData['status'] = _selectedStatus!.toString().split('.').last;
        }

        final updated = await OrderService.updateOrder(
          orderId: _existingOrder!.id,
          updateData: updateData,
          token: token,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order updated successfully! Order ID: ${updated.id}'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // List<List<PlatformFile>> _ornamentImages = [[]];
  // // For edit mode: store existing image URLs per ornament item (display only)
  // List<List<String>> _existingOrnamentImageUrls = [[]];
  // File? _currentEditingImage;
  // final ImagePicker _picker = ImagePicker();
  // List<Datum> _categories = []; 
  // bool _loadingCategories = true; 
  // String? _categoriesError; 
  // static const List<String> _purityOptions = [
  //   '18K Yellow gold',
  //   '18K Rose gold', 
  //   '18K White gold',
  //   'Other'
  // ];
  
  // static const List<String> _orderTypeOptions = [
  //   'Single',
  //   'Bulk'
  // ];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _prefillFromExistingOrder();
    } else {
      _selectedOrderDate = DateTime.now();
      _orderDateController.text = _formatDateDDMMYYYY(_selectedOrderDate!);
    }
    _fetchCategories(); 
  }

  String _formatDateDDMMYYYY(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  void _prefillFromExistingOrder() {
    final order = _existingOrder!;
    _selectedOrderDate = order.orderDate ?? order.createdAt;
    _orderDateController.text = _formatDateDDMMYYYY(_selectedOrderDate!);
    _selectedOrderType = order.orderType ?? 'Single';
    _selectedStatus = order.status;

    // Map ornament details
    if (order.ornamentDetails.isNotEmpty) {
      _ornamentDetails = order.ornamentDetails.map((d) => {
            'name': d.name, // display name for the dropdown field
            'categoryId': d.nameId, // id to send to API
            'weight': d.weight,
            'purity': d.purity,
            'quantity': d.quantity,
            'remarks': d.remarks ?? '',
          }).toList();
      // Setup image lists: existing URLs and empty new files
      _existingOrnamentImageUrls = order.ornamentDetails
          .map((d) => List<String>.from(d.images))
          .toList();
      _ornamentImages = List.generate(_ornamentDetails.length, (_) => []);
    } else {
      // Fallback to order-level images if any
      _existingOrnamentImageUrls = [List<String>.from(order.images)];
      _ornamentImages = [[]];
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final token = AuthService.currentToken;
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await CategoryService.getAllCategories(token);
      setState(() {
        _categories = response.data; 
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _loadingCategories = false;
        _categoriesError = 'Failed to load categories: $e. Enter manually.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  void _addOrnamentDetail() {
    setState(() {
      _ornamentDetails.add({
        'name': '',
        'categoryId': '', 
        'weight': 0.0,
        'purity': '',
        'quantity': 1,
        'remarks': '',
      });
      _ornamentImages.add([]);
    });
  }

  void _removeOrnamentDetail(int index) {
    setState(() {
      _ornamentDetails.removeAt(index);
      _ornamentImages.removeAt(index);
    });
  }

  Future<void> _pickImagesForItem(int index) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.image,
      );
      if (result != null) {
        setState(() {
          _ornamentImages[index].addAll(result.files.where((f) => f.bytes != null));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _showImageEditorForItem(int itemIndex, int editingIndex) async {
    final bytes = _ornamentImages[itemIndex][editingIndex].bytes;
    if (bytes == null) return;

    final edited = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(
        builder: (editorContext) => ProImageEditor.memory(
          bytes,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              Navigator.of(editorContext).pop(bytes);
            },
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (edited != null) {
      setState(() {
        _ornamentImages[itemIndex][editingIndex] = PlatformFile(
          name: 'edited_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          size: edited.length,
          bytes: edited,
        );
      });
    }
  }

  Future<void> _createOrder() async {
    if (_formKey.currentState!.validate() && !_isLoading) {
      setState(() {
        _isLoading = true;
      });
      try {
        final currentUser = context.read<AuthProvider>().currentUser;
        final token = AuthService.currentToken;
        if (currentUser != null && token != null) {
          // Format the payload to match the required structure
          final detailsPayload = _ornamentDetails.map((d) => {
                'name': d['categoryId'], // Send category ID as name
                'weight': d['weight'],
                'purity': d['purity'],
                'quantity': d['quantity'],
                if ((d['remarks'] as String).isNotEmpty) 'remarks': d['remarks'],
              }).toList();

          // For customers, always use 'Single' order type regardless of selection
          final orderType = currentUser.role == UserRole.client ? 'Single' : _selectedOrderType;
          
          final order = await OrderService.createOrder(
            clientId: currentUser.id,
            clientName: currentUser.name,
            orderDate: _selectedOrderDate,
            orderType: orderType,
            ornamentDetails: detailsPayload,
            ornamentImages: _ornamentImages,
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
  void dispose() {
    _orderDateController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _shouldShowOrderTypeSelection() {
    final currentUser = context.read<AuthProvider>().currentUser;
    return currentUser != null && 
           (currentUser.role == UserRole.admin || currentUser.role == UserRole.employee);
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
            dialogBackgroundColor: AppConstants.backgroundColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedOrderDate) {
      setState(() {
        _selectedOrderDate = picked;
        _orderDateController.text = _formatDateDDMMYYYY(picked);
      });
    }
  }

  // Custom searchable dropdown widget
  Widget _buildCategoryDropdown(int index, Map<String, dynamic> detail) {
    return _loadingCategories
        ? const Center(child: CircularProgressIndicator())
        : _categoriesError != null
            ? TextFormField(
                initialValue: detail['name'],
                decoration: InputDecoration(
                  labelText: 'Category ID / Name ($_categoriesError)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingS,
                  ),
                ),
                onChanged: (value) => setState(() {
                  _ornamentDetails[index]['name'] = value;
                }),
                validator: (value) => value!.isEmpty ? 'Please enter category id/name' : null,
              )
            : GestureDetector(
                onTap: () => _showCategoryDialog(index, detail),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Category ID / Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusS),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: AppConstants.spacingS,
                      ),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    controller: TextEditingController(text: detail['name']),
                    validator: (value) => value!.isEmpty ? 'Please select a category' : null,
                    enabled: false,
                  ),
                ),
              );
  }

  Future<void> _showCategoryDialog(int index, Map<String, dynamic> detail) async {
    String searchQuery = '';
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCategories = _categories
                .where((category) => category.categoryname.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();
            return AlertDialog(
              title: const Text('Select Category'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Search',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: filteredCategories.length,
                        itemBuilder: (context, i) {
                          final category = filteredCategories[i];
                          return ListTile(
                            title: Text(category.categoryname),
                            onTap: () {
                              setState(() {
                                _ornamentDetails[index]['name'] = category.categoryname;
                                _ornamentDetails[index]['categoryId'] = category.id; 
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Update Order' : 'Create Order'),
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
                _buildOrderDetailsSection(),
                const SizedBox(height: AppConstants.spacingXL),
                _buildOrnamentDetailsSection(),
                const SizedBox(height: AppConstants.spacingXL),
                CustomButton(
                  onPressed: _isLoading
                      ? null
                      : (_isEditMode ? _updateOrder : _createOrder),
                  text: _isLoading
                      ? (_isEditMode ? 'Updating...' : 'Creating...')
                      : (_isEditMode ? 'Update Order' : 'Create Order'),
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

  Widget _buildOrderDetailsSection() {
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
                Text('Order Details', style: AppConstants.headingSmall),
                if (_isEditMode && _existingOrder?.orderNo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Order No: ${_existingOrder!.orderNo}',
                      style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.w600),
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
                hintText: 'Select date',
                enabled: false,
                validator: (value) => value!.isEmpty ? 'Please select a date' : null,
              ),
            ),
            // Show order type selection only for admin and employee users
            if (_shouldShowOrderTypeSelection()) ...[
              const SizedBox(height: AppConstants.spacingM),
              Text('Order Type', style: AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppConstants.spacingS),
              Wrap(
                spacing: AppConstants.spacingS,
                children: _orderTypeOptions.map((type) {
                  final isSelected = _selectedOrderType == type;
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedOrderType = type;
                      });
                    },
                    backgroundColor: AppConstants.surfaceColor,
                    selectedColor: AppConstants.primaryColor.withOpacity(0.2),
                    checkmarkColor: AppConstants.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? AppConstants.primaryColor : AppConstants.textPrimaryColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ],
            // Show status only for admin/employee in edit mode (hide for customers)
            if (_isEditMode && _shouldShowOrderTypeSelection()) ...[
              const SizedBox(height: AppConstants.spacingM),
              Text('Status', style: AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppConstants.spacingS),
              DropdownButtonFormField<OrderStatus>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingS,
                  ),
                ),
                items: OrderStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.toString().split('.').last),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedStatus = val),
              ),
            ],
          ],
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
            const SizedBox(height: AppConstants.spacingM),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ornamentDetails.length,
              itemBuilder: (context, index) {
                return _buildOrnamentDetailCard(index, _ornamentDetails[index]);
              },
            ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildCategoryDropdown(index, detail),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: detail['weight'].toString(),
                  decoration: InputDecoration(
                    labelText: 'Weight (g)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingS,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() {
                    _ornamentDetails[index]['weight'] = double.tryParse(value) ?? 0.0;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter weight';
                    if (double.tryParse(value) == null) return 'Invalid weight';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Purity',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingS,
                    ),
                  ),
                  value: (detail['purity'] as String?)?.isNotEmpty == true ? detail['purity'] as String : null,
                  items: _purityOptions
                      .map((option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _ornamentDetails[index]['purity'] = value ?? '';
                  }),
                  validator: (value) => (value == null || value.isEmpty) ? 'Please select purity' : null,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: detail['quantity'].toString(),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingS,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() {
                    _ornamentDetails[index]['quantity'] = int.tryParse(value) ?? 1;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter quantity';
                    if (int.tryParse(value) == null) return 'Invalid quantity';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          TextFormField(
            initialValue: detail['remarks'],
            decoration: InputDecoration(
              labelText: 'Remarks',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingS,
                vertical: AppConstants.spacingS,
              ),
            ),
            onChanged: (value) => setState(() {
              _ornamentDetails[index]['remarks'] = value;
            }),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppConstants.spacingS,
              children: [
                Text('Images for item ${index + 1}', style: AppConstants.bodyMedium),
                if (_isPickingImage)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primaryColor),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _pickImagesForItem(index),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add Images'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          if (_existingOrnamentImageUrls.length > index &&
              _existingOrnamentImageUrls[index].isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _existingOrnamentImageUrls[index].length,
                separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spacingS),
                itemBuilder: (context, imgIdx) {
                  final url = _existingOrnamentImageUrls[index][imgIdx];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    child: Image.network(url, width: 90, height: 90, fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                              width: 90,
                              height: 90,
                              color: Colors.grey.shade100,
                              child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                            )),
                  );
                },
              ),
            ),
          if (_ornamentImages[index].isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _ornamentImages[index].length,
                separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spacingS),
                itemBuilder: (context, imgIdx) {
                  final file = _ornamentImages[index][imgIdx];
                  final bytes = file.bytes;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppConstants.radiusS),
                        child: bytes != null ? Image.memory(bytes, width: 90, height: 90, fit: BoxFit.cover) : const SizedBox(width: 90, height: 90),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: InkWell(
                          onTap: () => setState(() => _ornamentImages[index].removeAt(imgIdx)),
                          child: Container(
                            decoration: BoxDecoration(color: AppConstants.errorColor, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: GestureDetector(
                          onTap: () => _showImageEditorForItem(index, imgIdx),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
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
}