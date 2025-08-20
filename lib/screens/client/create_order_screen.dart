import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  final _orderDateController = TextEditingController();
  bool _isLoading = false;
  bool _isPickingImage = false; // Loader for image picking
  DateTime? _selectedOrderDate;
  String _selectedOrderType = 'Single';
  List<Map<String, dynamic>> _ornamentDetails = [
    {
      'name': '',
      'material': 'Gold',
      'weight': 0.0,
      'purity': '18K',
      'quantity': 1,
    }
  ];
  List<PlatformFile> _selectedFiles = [];
  File? _currentEditingImage;
  final ImagePicker _picker = ImagePicker();

  final List<String> _orderTypes = ['Single', 'Bulk']; // Limited to Single and Bulk
  final List<String> _materials = ['Gold', 'Rose Gold', 'White Gold', 'Platinum'];
  final List<String> _purities = ['18K', '22K', '24K'];

  @override
  void initState() {
    super.initState();
    _orderDateController.text = DateTime.now().toIso8601String().split('T')[0];
    _selectedOrderDate = DateTime.now();
  }

  void _addOrnamentDetail() {
    setState(() {
      _ornamentDetails.add({
        'name': '',
        'material': 'Gold',
        'weight': 0.0,
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

  Future<void> _pickImage() async {
    if (_isPickingImage) return; // Prevent multiple clicks
    setState(() {
      _isPickingImage = true;
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusM)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setState(() {
                    _selectedFiles.add(PlatformFile(
                      name: image.name,
                      size: bytes.length,
                      bytes: bytes,
                    ));
                    _isPickingImage = false;
                  });
                } else {
                  setState(() {
                    _isPickingImage = false;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setState(() {
                    _selectedFiles.add(PlatformFile(
                      name: image.name,
                      size: bytes.length,
                      bytes: bytes,
                    ));
                    _isPickingImage = false;
                  });
                } else {
                  setState(() {
                    _isPickingImage = false;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    allowMultiple: true,
                    withData: true,
                    type: FileType.image,
                  );
                  if (result != null) {
                    setState(() {
                      _selectedFiles.addAll(result.files);
                      _isPickingImage = false;
                    });
                  } else {
                    setState(() {
                      _isPickingImage = false;
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error picking files: $e')),
                  );
                  setState(() {
                    _isPickingImage = false;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _orderDateController.dispose();
    _pageController.dispose();
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
            dialogBackgroundColor: AppConstants.backgroundColor,
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

  Future<void> _showImageEditor(int editingIndex) async {
    final bytes = _selectedFiles[editingIndex].bytes;
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
        _selectedFiles[editingIndex] = PlatformFile(
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
          final order = await OrderService.createOrder(
            clientId: currentUser.id,
            clientName: currentUser.name,
            orderType: _selectedOrderType,
            orderDate: _selectedOrderDate,
            ornamentDetails: _ornamentDetails.isNotEmpty ? _ornamentDetails : null,
            files: _selectedFiles.isNotEmpty ? _selectedFiles : null,
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
                _buildOrderDetailsSection(),
                const SizedBox(height: AppConstants.spacingXL),
                _buildImageSection(),
                const SizedBox(height: AppConstants.spacingXL),
                _buildOrnamentDetailsSection(),
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
            Text('Order Details', style: AppConstants.headingSmall),
            const SizedBox(height: AppConstants.spacingM),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedOrderType,
                    decoration: InputDecoration(
                      labelText: 'Order Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusS),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: AppConstants.spacingS,
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
                    validator: (value) => value == null ? 'Please select an order type' : null,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingL),
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: _selectDate,
                    child: CustomTextField(
                      controller: _orderDateController,
                      labelText: 'Order Date',
                      hintText: 'Select date',
                      prefixIcon: Icons.calendar_today,
                      enabled: false,
                      validator: (value) => value!.isEmpty ? 'Please select a date' : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
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
                Text('Images', style: AppConstants.headingSmall),
                if (_isPickingImage)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppConstants.primaryColor,
                      strokeWidth: 2,
                    ),
                  )
                else
                  FloatingActionButton.small(
                    heroTag: 'pickImageFab',
                    onPressed: _pickImage,
                    backgroundColor: AppConstants.primaryColor,
                    child: const Icon(Icons.add_a_photo),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            SizedBox(
              height: 200,
              child: Container(
                decoration: BoxDecoration(
                  color: AppConstants.surfaceColor,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  border: Border.all(color: AppConstants.primaryColor.withOpacity(0.15)),
                ),
                child: Center(
                  child: _isPickingImage
                      ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                      : (_selectedFiles.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined, size: 64, color: AppConstants.textSecondaryColor),
                                const SizedBox(height: AppConstants.spacingS),
                                Text('No images selected', style: AppConstants.bodySmall),
                              ],
                            )
                          : PageView.builder(
                              controller: _pageController,
                              itemCount: _selectedFiles.length,
                              itemBuilder: (context, index) {
                                final file = _selectedFiles[index];
                                final img = file.bytes;
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                                    child: img != null
                                        ? Image.memory(img, fit: BoxFit.contain)
                                        : const SizedBox.shrink(),
                                  ),
                                );
                              },
                            )),
                ),
              ),
            ),
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingM),
              _buildImagePreviewStrip(),
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
                child: TextFormField(
                  initialValue: detail['name'],
                  decoration: InputDecoration(
                    labelText: 'Name',
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
                  validator: (value) => value!.isEmpty ? 'Please enter ornament name' : null,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: detail['material'],
                  decoration: InputDecoration(
                    labelText: 'Material',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingS,
                    ),
                  ),
                  items: _materials.map((material) {
                    return DropdownMenuItem(
                      value: material,
                      child: Text(material),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _ornamentDetails[index]['material'] = value!;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a material' : null,
                ),
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
                  value: detail['purity'],
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
                  items: _purities.map((purity) {
                    return DropdownMenuItem(
                      value: purity,
                      child: Text(purity),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _ornamentDetails[index]['purity'] = value!;
                    });
                  },
                  validator: (value) => value == null ? 'Please select purity' : null,
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

  Widget _buildImagePreviewStrip() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spacingS),
        itemBuilder: (context, index) {
          return _buildImageThumb(_selectedFiles[index], index);
        },
      ),
    );
  }

  Widget _buildImageThumb(PlatformFile file, int index, {double size = 90}) {
    final isPdf = (file.extension ?? '').toLowerCase() == 'pdf';
    Widget content;
    if (!isPdf && file.bytes != null && file.bytes!.isNotEmpty) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        child: Image.memory(
          file.bytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
          border: Border.all(color: AppConstants.primaryColor.withOpacity(0.15)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: AppConstants.primaryColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  file.name,
                  style: AppConstants.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            right: -6,
            top: -6,
            child: InkWell(
              onTap: () => setState(() => _selectedFiles.removeAt(index)),
              child: Container(
                decoration: BoxDecoration(
                  color: AppConstants.errorColor,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => _showImageEditor(index),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.edit, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}