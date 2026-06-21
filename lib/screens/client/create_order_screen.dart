import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../models/order.dart';
import '../../constants/app_constants.dart';
import '../../widgets/fallback_image.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../services/user_service.dart';
import '../../models/user.dart';
import 'package:http/http.dart' as http;

class CreateOrderScreen extends StatefulWidget {
  final Order? orderToEdit;
  final bool cloneFromOrder;
  const CreateOrderScreen({
    super.key,
    this.orderToEdit,
    this.cloneFromOrder = false,
  });

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
  // In clone mode, we prefill but treat as create (not edit)
  bool get _isEditMode =>
      widget.orderToEdit != null && widget.cloneFromOrder != true;
  Order? get _existingOrder => widget.orderToEdit;
  OrderStatus? _selectedStatus;
  List<Map<String, dynamic>> _ornamentDetails = [
    {
      'name': '',
      'categoryId': '',
      'size': '',
      'unit': '',
      'weight': 0,
      'purity': '',
      'quantity': 1,
      'colorstone': 'Same as image',
      'rhodium': 'Same as image',
      'dull': 'Same as image',
      'remarks': '',
      'deliverycount': null,
      'deliveryqty': null,
      'deliverydate': null,
      'deliverynote': '',
      'partialdelivery': [], // Store existing partial delivery entries
    },
  ];
  List<List<PlatformFile>> _ornamentImages = [[]];
  // For edit mode: store existing image URLs per ornament item (display only)
  List<List<String>> _existingOrnamentImageUrls = [[]];
  List<List<String>> _existingOrnamentBackupImageUrls = [[]];
  File? _currentEditingImage;
  final ImagePicker _picker = ImagePicker();
  List<Datum> _categories = [];
  bool _loadingCategories = true;
  String? _categoriesError;

  // Sharing intent listeners
  StreamSubscription? _intentDataStreamSubscription;

  // Party selection for bulk orders
  List<User> _allUsers = [];
  List<User> _filteredParties = [];
  bool _loadingParties = false;
  String? _partiesError;
  String? _selectedPartyId;
  String? _selectedPartyName;
  UserRole _selectedPartyRole = UserRole.customer; // Default to customer
  String _partySearchQuery = '';
  static const List<String> _purityOptions = [
    '18K Yellow gold',
    '18K Rose gold',
    '18K White gold',
    '22k',
    'Other',
  ];
  static const List<String> _colorstoneOptions = [
    'Red',
    'Blue',
    'Green',
    'Black',
    'White',
    'Others',
    'Same as image',
  ];
  static const List<String> _rhodiumOptions = [
    'Setting Rhodium',
    'Ganga Jamuna',
    'No Rhodium',
    'Same as image',
  ];
  static const List<String> _dullOptions = ['Dull', 'No Dull', 'Same as image'];

  static const List<String> _orderTypeOptions = ['Single', 'Bulk'];
  static const List<String> _priorityOptions = ['Regular', 'Urgent'];
  String _selectedPriority = 'Regular';
  String? _orderNo;

  List<String> get _availableOrderTypes {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser?.role == UserRole.employee) {
      return _orderTypeOptions; // Employee can only see bulk orders
    }
    return _orderTypeOptions; // Admin sees all options
  }

  Future<void> _updateOrder() async {
    if (_formKey.currentState!.validate() &&
        !_isLoading &&
        _existingOrder != null) {
      if (!_hasRequiredFiles()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode
                    ? 'You may add new files, but it is not required.'
                    : 'Please upload at least one file for the first item.',
              ),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
        return;
      }

      setState(() => _isLoading = true);
      try {
        final token = AuthService.currentToken;
        if (token == null) throw Exception('User not authenticated');

        final detailsPayload =
            _ornamentDetails.asMap().entries.map((entry) {
              final int i = entry.key;
              final d = entry.value;
              return {
                'name': d['categoryId'],
                // For bulk orders, pass empty strings for hidden fields
                'size': _isBulkOrderSimplifiedForm() ? '' : (d['size'] ?? ''),
                'unit':
                    _isBulkOrderSimplifiedForm() ? '' : _getUnitForDetail(d),
                'weight': _isBulkOrderSimplifiedForm() ? 0 : d['weight'],
                'purity': d['purity'],
                'quantity': d['quantity'],
                'colorstone':
                    _isBulkOrderSimplifiedForm()
                        ? ''
                        : (d['colorstone'] ?? 'Same as image'),
                'rhodium':
                    _isBulkOrderSimplifiedForm()
                        ? ''
                        : (d['rhodium'] ?? 'Same as image'),
                'dull':
                    _isBulkOrderSimplifiedForm()
                        ? ''
                        : (d['dull'] ?? 'Same as image'),
                if ((d['remarks'] as String).isNotEmpty)
                  'remarks': d['remarks'],
                'image': i < _existingOrnamentImageUrls.length
                    ? _existingOrnamentImageUrls[i]
                    : const <String>[],
                'backupimage': i < _existingOrnamentBackupImageUrls.length
                    ? _existingOrnamentBackupImageUrls[i]
                    : const <String>[],
                // Update delivery count to include new delivery qty
                if (_selectedStatus == OrderStatus.partialDelivery &&
                    d['deliveryqty'] != null)
                  'deliverycount':
                      (d['deliverycount'] ?? 0) + (d['deliveryqty'] as int)
                else if (d['deliverycount'] != null)
                  'deliverycount': d['deliverycount'],
                // Add partial delivery data when status is partial delivery
                if (_selectedStatus == OrderStatus.partialDelivery &&
                    d['deliveryqty'] != null &&
                    d['deliverydate'] != null)
                  'partialdelivery': [
                    ...List<Map<String, dynamic>>.from(
                      d['partialdelivery'] ?? [],
                    ),
                    {
                      'qty': d['deliveryqty'],
                      'deliverydate':
                          (d['deliverydate'] as DateTime).toIso8601String(),
                      if ((d['deliverynote'] ?? '').toString().isNotEmpty)
                        'deliverynote': d['deliverynote'],
                    },
                  ],
                // If not adding new partial delivery, preserve existing ones
                if (_selectedStatus == OrderStatus.partialDelivery &&
                    (d['deliveryqty'] == null || d['deliverydate'] == null) &&
                    d['partialdelivery'] != null &&
                    (d['partialdelivery'] as List).isNotEmpty)
                  'partialdelivery': d['partialdelivery'],
              };
            }).toList();

        final currentUser = context.read<AuthProvider>().currentUser;

        final updateData = <String, dynamic>{
          'orderdate':
              (_selectedOrderDate ?? DateTime.now()).toUtc().toIso8601String(),
          'ordertype': _selectedOrderType,
          'ornamentDetails': detailsPayload,
          'orderpriority': _selectedPriority,
          'updatedby': currentUser?.id,
          if (_orderNo != null && _orderNo!.isNotEmpty) 'orderno': _orderNo,
        };

        // Include status in update only for admin/employee users
        if (_selectedStatus != null && _shouldShowOrderTypeSelection()) {
          updateData['status'] = Order.statusToApiString(_selectedStatus!);
        }

        final updated = await OrderService.updateOrder(
          orderId: _existingOrder!.id,
          updateData: updateData,
          ornamentImages: _ornamentImages,
          token: token,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order updated successfully!'),
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

  @override
  void initState() {
    super.initState();
    if (widget.orderToEdit != null) {
      // Prefill for both real edit and clone-from-order flows
      _prefillFromExistingOrder();
      // If cloning, ensure we display as Create (isEditMode=false via getter)
    } else {
      _selectedOrderDate = DateTime.now();
      _orderDateController.text = _formatDateDDMMYYYY(_selectedOrderDate!);
    }
    _fetchCategories();
    // Load parties for bulk orders
    if (_shouldShowOrderTypeSelection()) {
      _fetchParties();
    }
    // Prefill orderNo if editing
    if (widget.orderToEdit != null && widget.orderToEdit!.orderNo != null) {
      _orderNo = widget.orderToEdit!.orderNo;
    }

    // Initialize sharing intent listeners
    _initSharingIntent();
  }

  @override
  void dispose() {
    _orderDateController.dispose();
    _pageController.dispose();
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set default order type based on user role
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser?.role == UserRole.employee &&
        _selectedOrderType == 'Single') {
      _selectedOrderType = 'Bulk';
    }
  }

  // Initialize sharing intent to receive shared images
  void _initSharingIntent() {
    // Listen to media sharing while app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<dynamic> sharedFiles) {
            if (sharedFiles.isNotEmpty) {
              _handleSharedFiles(sharedFiles);
            }
          },
          onError: (err) {
            print('Error receiving shared files: $err');
          },
        );

    // Get the media that was shared when the app was closed/not running
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<dynamic> sharedFiles,
    ) {
      if (sharedFiles.isNotEmpty) {
        _handleSharedFiles(sharedFiles);
      }
    });
  }

  // Handle shared files from gallery
  Future<void> _handleSharedFiles(List<dynamic> sharedFiles) async {
    try {
      List<PlatformFile> platformFiles = [];

      for (var sharedFile in sharedFiles) {
        if (sharedFile.type == SharedMediaType.image) {
          final file = File(sharedFile.path);
          if (await file.exists()) {
            // Read file bytes
            final bytes = await file.readAsBytes();
            final fileName = file.path.split('/').last;

            platformFiles.add(
              PlatformFile(
                name: fileName,
                size: bytes.length,
                bytes: bytes,
                path: sharedFile.path,
              ),
            );
          }
        }
      }

      if (platformFiles.isNotEmpty) {
        setState(() {
          // Add shared images to the first ornament detail
          _ornamentImages[0].addAll(platformFiles);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${platformFiles.length} image(s) added to Item 1'),
              backgroundColor: AppConstants.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error handling shared files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load shared images: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  String _formatDateDDMMYYYY(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  void _prefillFromExistingOrder() {
    final order = _existingOrder!;
    // For clones, use current date. For edits, use original order date.
    _selectedOrderDate =
        widget.cloneFromOrder
            ? DateTime.now()
            : (order.orderDate ?? order.createdAt);
    _orderDateController.text = _formatDateDDMMYYYY(_selectedOrderDate!);
    _selectedOrderType = order.orderType ?? 'Single';
    _selectedStatus = order.status;
    _selectedPriority = order.orderPriority ?? 'Regular';
    _orderNo = order.orderNo; // <-- Prefill orderNo

    // Map ornament details
    if (order.ornamentDetails.isNotEmpty) {
      _ornamentDetails =
          order.ornamentDetails
              .map(
                (d) => {
                  'name': d.name, // display name for the dropdown field
                  'categoryId': d.nameId, // id to send to API
                  'size': d.size ?? '', // from existing order if available
                  'unit': d.unit ?? '',
                  'weight': d.weight,
                  'purity': d.purity,
                  'quantity': d.quantity,
                  'colorstone': d.colorstone ?? 'Same as image',
                  'rhodium': d.rhodium ?? 'Same as image',
                  'dull': d.dull ?? 'Same as image',
                  'remarks': d.remarks ?? '',
                  'deliverycount': d.deliverycount,
                  'deliveryqty': null,
                  'deliverydate': null,
                  'deliverynote':
                      d.partialDelivery?.isNotEmpty == true
                          ? (d.partialDelivery!.last.deliverynote ?? '')
                          : '',
                  'partialdelivery':
                      d.partialDelivery?.map((e) => e.toJson()).toList() ?? [],
                },
              )
              .toList();
      // Setup image lists: existing URLs and empty new files
      _existingOrnamentImageUrls =
          order.ornamentDetails
              .map((d) => List<String>.from(d.images))
              .toList();
      _existingOrnamentBackupImageUrls =
          order.ornamentDetails
              .map((d) => List<String>.from(d.backupImages))
              .toList();
      _ornamentImages = List.generate(_ornamentDetails.length, (_) => []);
    } else {
      // Fallback to order-level images if any
      _existingOrnamentImageUrls = [List<String>.from(order.images)];
      _existingOrnamentBackupImageUrls = [List<String>.from(order.backupImages)];
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
      }
    }
  }

  Future<void> _fetchParties() async {
    setState(() {
      _loadingParties = true;
      _partiesError = null;
    });

    try {
      final token = AuthService.currentToken;
      if (token == null) {
        throw Exception('User not authenticated');
      }

      // Get all users
      final allUsers = await UserService.getAllUsers(token);
      setState(() {
        _allUsers = allUsers;
        _loadingParties = false;
        _filterParties(); // Apply initial filtering
      });
    } catch (e) {
      setState(() {
        _loadingParties = false;
        _partiesError = 'Failed to load parties: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading parties: $e')));
      }
    }
  }

  void _filterParties() {
    var filtered =
        _allUsers.where((user) => user.role == _selectedPartyRole).toList();

    if (_partySearchQuery.isNotEmpty) {
      final query = _partySearchQuery.toLowerCase();
      filtered =
          filtered.where((user) {
            return user.name.toLowerCase().contains(query) ||
                user.email.toLowerCase().contains(query);
          }).toList();
    }

    setState(() {
      _filteredParties = filtered;
    });
  }

  void _addOrnamentDetail() {
    setState(() {
      _ornamentDetails.add({
        'name': '',
        'categoryId': '',
        'size': '',
        'unit': '',
        'weight': 0,
        'purity': '',
        'quantity': 1,
        'colorstone': 'Same as image',
        'rhodium': 'Same as image',
        'dull': 'Same as image',
        'remarks': '',
        'deliverycount': null,
        'deliveryqty': null,
        'deliverydate': null,
        'deliverynote': '',
        'partialdelivery': [],
      });
      _ornamentImages.add([]);
      _existingOrnamentImageUrls.add([]);
      _existingOrnamentBackupImageUrls.add([]);
    });
  }

  void _removeOrnamentDetail(int index) {
    setState(() {
      _ornamentDetails.removeAt(index);
      _ornamentImages.removeAt(index);
      if (_existingOrnamentImageUrls.length > index) {
        _existingOrnamentImageUrls.removeAt(index);
      }
      if (_existingOrnamentBackupImageUrls.length > index) {
        _existingOrnamentBackupImageUrls.removeAt(index);
      }
    });
  }

  // Show dialog to choose between Gallery and File Manager
  Future<void> _showFilePickerOptions(int index) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppConstants.primaryColor,
                ),
                title: const Text('Gallery'),
                subtitle: const Text('Pick images from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery(index);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.folder,
                  color: AppConstants.primaryColor,
                ),
                title: const Text('File Manager'),
                subtitle: const Text('Pick files from device'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromFileManager(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick images from gallery using ImagePicker
  Future<void> _pickFromGallery(int index) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        List<PlatformFile> platformFiles = [];
        for (var image in images) {
          final bytes = await image.readAsBytes();
          platformFiles.add(
            PlatformFile(
              name: image.name,
              size: bytes.length,
              bytes: bytes,
              path: image.path,
            ),
          );
        }
        setState(() {
          _ornamentImages[index].addAll(platformFiles);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${platformFiles.length} image(s) added from gallery',
              ),
              backgroundColor: AppConstants.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // Pick files from file manager using FilePicker
  Future<void> _pickFromFileManager(int index) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'bmp',
          'webp',
          'heic',
          'heif',
          'pdf',
        ],
      );
      if (result != null) {
        setState(() {
          // Accept both images (with bytes) and PDFs (may have bytes or only path)
          _ornamentImages[index].addAll(result.files);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${result.files.length} file(s) added from file manager',
              ),
              backgroundColor: AppConstants.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
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
        builder:
            (editorContext) => ProImageEditor.memory(
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

  bool _areFilesRequiredForItem(int index) {
    // Edit mode → never required (existing images are already on the server)
    if (_isEditMode) return false;

    // Create mode → only the first item is required
    return index == 0;
  }

  bool _hasRequiredFiles() {
    return _ornamentImages.asMap().entries.every((entry) {
      final index = entry.key;
      if (!_areFilesRequiredForItem(index)) return true;

      // Check if we have new files for this item
      if (entry.value.isNotEmpty) return true;

      // If it's a clone, check if we have existing images from the original order
      if (widget.cloneFromOrder &&
          index < _existingOrnamentImageUrls.length &&
          _existingOrnamentImageUrls[index].isNotEmpty) {
        return true;
      }

      return false;
    });
  }

  Future<void> _createOrder() async {
    if (_formKey.currentState!.validate() && !_isLoading) {
      if (!_hasRequiredFiles()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode
                    ? 'You may add new files, but it is not required.'
                    : 'Please upload at least one file for the first item.',
              ),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
        return;
      }
      setState(() {
        _isLoading = true;
      });
      try {
        final currentUser = context.read<AuthProvider>().currentUser;
        final token = AuthService.currentToken;
        if (currentUser != null && token != null) {
          // If cloning and new files are added, the backend will drop existing network images.
          // Convert existing network images into new files to preserve them.
          if (widget.cloneFromOrder) {
            bool hasNewImages = _ornamentImages.any((list) => list.isNotEmpty);
            if (hasNewImages) {
              for (int i = 0; i < _existingOrnamentImageUrls.length; i++) {
                if (i >= _ornamentImages.length) continue;
                for (final url in _existingOrnamentImageUrls[i]) {
                  try {
                    final response = await http.get(Uri.parse(url));
                    if (response.statusCode == 200) {
                      final bytes = response.bodyBytes;
                      _ornamentImages[i].insert(
                        0,
                        PlatformFile(
                          name:
                              'cloned_${DateTime.now().millisecondsSinceEpoch}.jpg',
                          size: bytes.length,
                          bytes: bytes,
                        ),
                      );
                    }
                  } catch (e) {
                    print('Error downloading image: $e');
                  }
                }
                _existingOrnamentImageUrls[i].clear();
                if (_existingOrnamentBackupImageUrls.length > i) {
                  _existingOrnamentBackupImageUrls[i].clear();
                }
              }
            }
          }

          // Format the payload to match the required structure
          final detailsPayload = <Map<String, dynamic>>[];
          for (int i = 0; i < _ornamentDetails.length; i++) {
            final d = _ornamentDetails[i];
            final map = <String, dynamic>{
              'name': d['categoryId'], // Send category ID as name
              // For bulk orders, pass empty strings for hidden fields
              'size': _isBulkOrderSimplifiedForm() ? '' : (d['size'] ?? ''),
              'unit': _isBulkOrderSimplifiedForm() ? '' : _getUnitForDetail(d),
              'weight': _isBulkOrderSimplifiedForm() ? 0 : d['weight'],
              'purity': d['purity'],
              'quantity': d['quantity'],
              'colorstone':
                  _isBulkOrderSimplifiedForm()
                      ? ''
                      : (d['colorstone'] ?? 'Same as image'),
              'rhodium':
                  _isBulkOrderSimplifiedForm()
                      ? ''
                      : (d['rhodium'] ?? 'Same as image'),
              'dull':
                  _isBulkOrderSimplifiedForm()
                      ? ''
                      : (d['dull'] ?? 'Same as image'),
            };
            if ((d['remarks'] as String).isNotEmpty) {
              map['remarks'] = d['remarks'];
            }
            if (d['deliverycount'] != null) {
              map['deliverycount'] = d['deliverycount'];
            }
            // If cloning, include existing image URLs per item so backend saves them without multipart
            if (widget.cloneFromOrder) {
              map['image'] = _existingOrnamentImageUrls.length > i
                  ? List<String>.from(_existingOrnamentImageUrls[i])
                  : const <String>[];
              map['backupimage'] = _existingOrnamentBackupImageUrls.length > i
                  ? List<String>.from(_existingOrnamentBackupImageUrls[i])
                  : const <String>[];
            }
            detailsPayload.add(map);
          }

          final orderType =
              currentUser.role == UserRole.customer
                  ? 'Single'
                  : _selectedOrderType;

          final order = await OrderService.createOrder(
            clientId: currentUser.id,
            clientName: currentUser.name,
            orderDate: _selectedOrderDate,
            orderType: orderType,
            orderpriority: _selectedPriority,
            ornamentDetails: detailsPayload,

            ornamentImages: _ornamentImages,
            // Include party ID for bulk orders
            partyname:
                (_selectedOrderType == 'Bulk' ||
                        (_selectedOrderType == 'Single' &&
                            _selectedPartyId != null))
                    ? _selectedPartyId
                    : currentUser.id,
            token: token,
            orderno: _orderNo, // <-- Pass orderNo to API
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order created successfully! '),
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

  bool _shouldShowOrderTypeSelection() {
    final currentUser = context.read<AuthProvider>().currentUser;
    return currentUser != null &&
        (currentUser.role == UserRole.admin ||
            currentUser.role == UserRole.employee);
  }

  bool _isBulkOrderSimplifiedForm() {
    final currentUser = context.read<AuthProvider>().currentUser;
    return currentUser != null &&
        (currentUser.role == UserRole.employee ||
            currentUser.role == UserRole.admin) &&
        _selectedOrderType == 'Bulk';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedOrderDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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
          onChanged:
              (value) => setState(() {
                _ornamentDetails[index]['name'] = value;
              }),
          validator:
              (value) =>
                  value!.isEmpty ? 'Please enter category id/name' : null,
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
              style: const TextStyle(color: Colors.black),
              validator:
                  (value) => value!.isEmpty ? 'Please select a category' : null,
              enabled: false,
            ),
          ),
        );
  }

  Future<void> _showCategoryDialog(
    int index,
    Map<String, dynamic> detail,
  ) async {
    String searchQuery = '';
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCategories =
                _categories
                    .where(
                      (category) => category.categoryname
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase()),
                    )
                    .toList();
            return AlertDialog(
              title: const Text('Select Category'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
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
                                _ornamentDetails[index]['name'] =
                                    category.categoryname;
                                _ornamentDetails[index]['categoryId'] =
                                    category.id;
                                _ornamentDetails[index]['size'] = '';
                                _ornamentDetails[index]['unit'] = '';
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

  Datum? _findCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Build Size dropdown based on selected category's sizes
  Widget _buildSizeDropdown(int index, Map<String, dynamic> detail) {
    final String categoryId = (detail['categoryId'] as String?) ?? '';
    final Datum? cat = _findCategoryById(categoryId);
    final List<String> sizes = cat?.size ?? [];

    if (categoryId.isEmpty || sizes.isEmpty) {
      return DropdownButtonFormField<String>(
        style: const TextStyle(color: Colors.black),
        value: null,
        decoration: InputDecoration(
          labelText: 'Size',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingS,
            vertical: AppConstants.spacingS,
          ),
        ),
        items: const [],
        onChanged: null,
        hint: const Text('No sizes'),
      );
    }

    final String? current =
        (detail['size'] as String?)?.isNotEmpty == true
            ? detail['size'] as String
            : null;
    return DropdownButtonFormField<String>(
      style: const TextStyle(color: Colors.black),
      value: current,
      decoration: InputDecoration(
        labelText: 'Size',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingS,
          vertical: AppConstants.spacingS,
        ),
      ),
      items:
          sizes
              .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
              .toList(),
      onChanged: (val) {
        setState(() {
          _ornamentDetails[index]['size'] = val ?? '';
        });
      },
      validator:
          (val) =>
              (sizes.isNotEmpty && (val == null || val.isEmpty))
                  ? 'Select size'
                  : null,
    );
  }

  // Build Unit dropdown based on selected category's units
  Widget _buildUnitDropdown(int index, Map<String, dynamic> detail) {
    final String categoryId = (detail['categoryId'] as String?) ?? '';
    final Datum? cat = _findCategoryById(categoryId);
    final List<String> units = cat?.unit ?? [];

    if (categoryId.isEmpty || units.isEmpty) {
      return DropdownButtonFormField<String>(
        style: const TextStyle(color: Colors.black),
        value: null,
        decoration: InputDecoration(
          labelText: 'Unit',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingS,
            vertical: AppConstants.spacingS,
          ),
        ),
        items: const [],
        onChanged: null,
        hint: const Text('No units'),
      );
    }

    final String? current =
        (detail['unit'] as String?)?.isNotEmpty == true
            ? detail['unit'] as String
            : null;
    return DropdownButtonFormField<String>(
      style: const TextStyle(color: Colors.black),
      value: current,
      decoration: InputDecoration(
        labelText: 'Unit',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingS,
          vertical: AppConstants.spacingS,
        ),
      ),
      items:
          units
              .map((u) => DropdownMenuItem<String>(value: u, child: Text(u)))
              .toList(),
      onChanged: (val) {
        setState(() {
          _ornamentDetails[index]['unit'] = val ?? '';
        });
      },
      validator:
          (val) =>
              (units.isNotEmpty && (val == null || val.isEmpty))
                  ? 'Select unit'
                  : null,
    );
  }

  String _getUnitForDetail(Map<String, dynamic> detail) {
    final String categoryId = (detail['categoryId'] as String?) ?? '';
    if (categoryId.isEmpty) return 'g';
    // If user picked a unit for this detail, use it
    final String selected = (detail['unit'] as String?) ?? '';
    if (selected.isNotEmpty) return selected;
    // Else fallback to first unit of the category or 'g'
    final Datum? cat = _findCategoryById(categoryId);
    final List<String> units = cat?.unit ?? const [];
    return units.isNotEmpty ? units.first : 'g';
  }

  Widget _buildPartySelectionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Party',
          style: AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppConstants.spacingS),
        // Role filter tabs
        Row(
          children: [
            _buildRoleFilterChip('Customer', UserRole.customer),
            const SizedBox(width: AppConstants.spacingS),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        _loadingParties
            ? const Center(child: CircularProgressIndicator())
            : _partiesError != null
            ? Column(
              children: [
                Text(
                  _partiesError!,
                  style: TextStyle(color: AppConstants.errorColor),
                ),
                const SizedBox(height: AppConstants.spacingS),
                ElevatedButton(
                  onPressed: _fetchParties,
                  child: const Text('Retry'),
                ),
              ],
            )
            : GestureDetector(
              onTap: () => _showPartySelectionDialog(),
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Party Name',
                    hintText: 'Select a party',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingM,
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  controller: TextEditingController(
                    text: _selectedPartyName ?? '',
                  ),
                  style: const TextStyle(color: Colors.black),
                  validator: (value) {
                    if ((_selectedOrderType == 'Bulk' ||
                            _selectedOrderType == 'Single') &&
                        (value == null || value.isEmpty)) {
                      return 'Please select a party';
                    }
                    return null;
                  },
                  enabled: false,
                ),
              ),
            ),
      ],
    );
  }

  // New method to show searchable party selection dialog
  Future<void> _showPartySelectionDialog() async {
    String searchQuery = '';
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredParties =
                _allUsers.where((user) {
                  if (_selectedPartyRole != user.role) return false;
                  if (searchQuery.isEmpty) return true;
                  final query = searchQuery.toLowerCase();
                  return user.name.toLowerCase().contains(query) ||
                      user.email.toLowerCase().contains(query);
                }).toList();

            return AlertDialog(
              title: const Text('Select Party'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search by name or email',
                        hintText: 'Type to search...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppConstants.spacingS),
                    SizedBox(
                      height: 200, // Fixed height for scrollable list
                      child: ListView.builder(
                        itemCount: filteredParties.length,
                        itemBuilder: (context, i) {
                          final party = filteredParties[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spacingS,
                              vertical: 4.0,
                            ),
                            title: Text(
                              party.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              party.email,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedPartyId = party.id;
                                _selectedPartyName = party.name;
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

  Widget _buildRoleFilterChip(String label, UserRole role) {
    final isSelected = _selectedPartyRole == role;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPartyRole = role;
          _selectedPartyId = null; // Clear selection when changing role
          _selectedPartyName = null;
        });
        _filterParties();
      },
      backgroundColor: AppConstants.surfaceColor,
      selectedColor: AppConstants.primaryColor.withOpacity(0.2),
      checkmarkColor: AppConstants.primaryColor,
      labelStyle: TextStyle(
        color:
            isSelected
                ? AppConstants.primaryColor
                : AppConstants.textPrimaryColor,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  // Helpers to determine file type for preview and editing
  bool _isImageFile(PlatformFile file) {
    final ext = file.extension?.toLowerCase();
    const imgExts = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'heic',
      'heif',
    };
    return ext != null && imgExts.contains(ext);
  }

  bool _isPdfFile(PlatformFile file) {
    return (file.extension?.toLowerCase() == 'pdf');
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
                  onPressed:
                      _isLoading
                          ? null
                          : (_isEditMode ? _updateOrder : _createOrder),
                  text:
                      _isLoading
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
                if (_isEditMode && _existingOrder?.orderNo != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Order No: ${_existingOrder!.orderNo}',
                            style: TextStyle(
                              color: AppConstants.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_existingOrder!.partynameDisplay != null &&
                            _existingOrder!.partynameDisplay!.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Party Name: ${_existingOrder!.partynameDisplay}',
                              style: TextStyle(
                                color: AppConstants.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            // --- Order No field for Bulk orders (admin/employee only) ---
            if (_shouldShowOrderTypeSelection() &&
                _selectedOrderType == 'Bulk') ...[
              Text(
                'Order No',
                style: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              TextFormField(
                initialValue: _orderNo ?? '',
                decoration: InputDecoration(
                  labelText: 'Enter Order No',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingS,
                  ),
                ),
                onChanged: (val) => setState(() => _orderNo = val),
                validator: (val) {
                  if (_selectedOrderType == 'Bulk' &&
                      (val == null || val.isEmpty)) {
                    return 'Order No is required for bulk orders';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.spacingM),
            ],
            GestureDetector(
              onTap: _selectDate,
              child: CustomTextField(
                controller: _orderDateController,
                labelText: 'Order Date',
                hintText: 'Select date',
                enabled: false,
                validator:
                    (value) => value!.isEmpty ? 'Please select a date' : null,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Priority',
              style: AppConstants.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: AppConstants.spacingS,
                ),
              ),
              items:
                  _priorityOptions
                      .map(
                        (p) =>
                            DropdownMenuItem<String>(value: p, child: Text(p)),
                      )
                      .toList(),
              onChanged:
                  (val) => setState(() => _selectedPriority = val ?? 'Regular'),
            ),
            // Show order type selection only for admin and employee users (not when editing)
            if (_shouldShowOrderTypeSelection() && !_isEditMode) ...[
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'Order Type',
                style: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Wrap(
                spacing: AppConstants.spacingS,
                children:
                    _availableOrderTypes.map((type) {
                      final isSelected = _selectedOrderType == type;
                      return FilterChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedOrderType = type;
                            // Load parties when switching to bulk orders
                            if (type == 'Bulk' &&
                                _allUsers.isEmpty &&
                                !_loadingParties) {
                              _fetchParties();
                            }
                          });
                        },
                        backgroundColor: AppConstants.surfaceColor,
                        selectedColor: AppConstants.primaryColor.withOpacity(
                          0.2,
                        ),
                        checkmarkColor: AppConstants.primaryColor,
                        labelStyle: TextStyle(
                          color:
                              isSelected
                                  ? AppConstants.primaryColor
                                  : AppConstants.textPrimaryColor,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
              ),
            ],
            // Party Selection (always show for Bulk orders, optional for Single)
            if ((_selectedOrderType == 'Bulk' ||
                    (_selectedOrderType == 'Single' &&
                        _shouldShowOrderTypeSelection())) &&
                !_isEditMode) ...[
              const SizedBox(height: AppConstants.spacingM),
              _buildPartySelectionField(),
            ],
            // Show status only for admin/employee in edit mode
            if (_isEditMode && _shouldShowOrderTypeSelection()) ...[
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'Status',
                style: AppConstants.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                items:
                    OrderStatus.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.toString().split('.').last),
                          ),
                        )
                        .toList(),
                onChanged:
                    (val) => setState(() {
                      _selectedStatus = val;
                      // Set default delivery date to today when status changes to partial delivery
                      if (val == OrderStatus.partialDelivery) {
                        for (var detail in _ornamentDetails) {
                          if (detail['deliverydate'] == null) {
                            detail['deliverydate'] = DateTime.now();
                          }
                        }
                      }
                    }),
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
                  icon: Icon(
                    Icons.add_circle,
                    color: AppConstants.primaryColor,
                  ),
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
      margin: const EdgeInsets.only(bottom: AppConstants.spacingL),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with item number and delete button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item ${index + 1}',
                style: AppConstants.headingSmall.copyWith(
                  color: AppConstants.primaryColor,
                ),
              ),
              if (_ornamentDetails.length > 1)
                IconButton(
                  onPressed: () => _removeOrnamentDetail(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),

          // Category Selection
          _buildCategoryDropdown(index, detail),
          const SizedBox(height: AppConstants.spacingM),

          // Size and Unit Row - Hide for bulk orders
          if (!_isBulkOrderSimplifiedForm()) ...[
            Row(
              children: [
                Expanded(flex: 3, child: _buildSizeDropdown(index, detail)),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(flex: 2, child: _buildUnitDropdown(index, detail)),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
          ],

          // Weight, Purity, Quantity Row - Weight hidden for bulk orders
          Row(
            children: [
              // Weight field - Hide for bulk orders
              if (!_isBulkOrderSimplifiedForm()) ...[
                Expanded(
                  child: TextFormField(
                    key: ValueKey('weight_$index'),
                    initialValue: detail['weight'].toString(),
                    decoration: InputDecoration(
                      labelText: 'Weight (${_getUnitForDetail(detail)})',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: AppConstants.spacingS,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onTap: () {
                      // Auto-select all text when tapped for easy editing
                      Future.delayed(const Duration(milliseconds: 100), () {
                        final controller = TextEditingController(
                          text: detail['weight'].toString(),
                        );
                        controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: controller.text.length,
                        );
                      });
                    },
                    onChanged:
                        (value) => setState(() {
                          _ornamentDetails[index]['weight'] =
                              double.tryParse(value) ?? 0;
                        }),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter weight';
                      if (double.tryParse(value) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
              ],
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  style: const TextStyle(color: Colors.black),
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
                  isExpanded: true,
                  value:
                      (detail['purity'] as String?)?.isNotEmpty == true
                          ? detail['purity'] as String
                          : null,
                  items:
                      _purityOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(
                                option,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  selectedItemBuilder:
                      (context) =>
                          _purityOptions
                              .map(
                                (option) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    option,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                  onChanged:
                      (value) => setState(() {
                        _ornamentDetails[index]['purity'] = value ?? '';
                      }),
                  validator:
                      (value) =>
                          (value == null || value.isEmpty) ? 'Select' : null,
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: detail['quantity'].toString(),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingS,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged:
                      (value) => setState(() {
                        _ornamentDetails[index]['quantity'] =
                            int.tryParse(value) ?? 1;
                      }),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter qty';
                    if (int.tryParse(value) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),

          // Colorstone and Rhodium Row - Hide for bulk orders
          if (!_isBulkOrderSimplifiedForm()) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Colorstone',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: AppConstants.spacingS,
                      ),
                    ),
                    value:
                        (detail['colorstone'] as String?)?.isNotEmpty == true
                            ? detail['colorstone'] as String
                            : 'Same as image',
                    items:
                        _colorstoneOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() {
                          _ornamentDetails[index]['colorstone'] =
                              value ?? 'Same as image';
                        }),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Rhodium',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: AppConstants.spacingS,
                      ),
                    ),
                    value:
                        (detail['rhodium'] as String?)?.isNotEmpty == true
                            ? detail['rhodium'] as String
                            : 'Same as image',
                    items:
                        _rhodiumOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option,
                                child: Text(
                                  option,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() {
                          _ornamentDetails[index]['rhodium'] =
                              value ?? 'Same as image';
                        }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),

            // Dull Row
            DropdownButtonFormField<String>(
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: 'Dull',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: AppConstants.spacingS,
                ),
              ),
              value:
                  (detail['dull'] as String?)?.isNotEmpty == true
                      ? detail['dull'] as String
                      : 'Same as image',
              items:
                  _dullOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() {
                    _ornamentDetails[index]['dull'] = value ?? 'Same as image';
                  }),
            ),
            const SizedBox(height: AppConstants.spacingM),
          ],

          // Remarks field - Always show
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
            keyboardType: TextInputType.multiline,
            maxLines: null,
            minLines: 3,
            expands: false,
            onChanged:
                (value) => setState(() {
                  _ornamentDetails[index]['remarks'] = value;
                }),
          ),
          const SizedBox(height: AppConstants.spacingM),

          // Partial Delivery fields - only show when status is partialDelivery
          if (_isEditMode &&
              _selectedStatus == OrderStatus.partialDelivery) ...[
            // Delivery Count (Read-only display)
            TextFormField(
              initialValue: detail['deliverycount']?.toString() ?? '0',
              decoration: InputDecoration(
                labelText: 'Total Delivery Count',
                hintText: 'Total delivered quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: AppConstants.spacingS,
                ),
                suffixIcon: Icon(
                  Icons.inventory_outlined,
                  color: AppConstants.primaryColor,
                ),
              ),
              enabled: false,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: AppConstants.spacingM),
            // Delivery Qty (Input field for new delivery)
            TextFormField(
              initialValue: detail['deliveryqty']?.toString() ?? '',
              decoration: InputDecoration(
                labelText: 'Delivery Qty',
                hintText: 'Enter quantity to deliver now',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: AppConstants.spacingS,
                ),
                suffixIcon: Icon(
                  Icons.local_shipping_outlined,
                  color: AppConstants.primaryColor,
                ),
                helperText: 'This will be added to total delivery count',
              ),
              keyboardType: TextInputType.number,
              onChanged:
                  (value) => setState(() {
                    final qty = value.isEmpty ? null : int.tryParse(value);
                    _ornamentDetails[index]['deliveryqty'] = qty;
                  }),
              validator: (value) {
                if (_selectedStatus == OrderStatus.partialDelivery) {
                  if (value == null || value.isEmpty) {
                    return 'Enter delivery qty for partial delivery';
                  }
                  final deliveryQty = int.tryParse(value);
                  if (deliveryQty == null) {
                    return 'Enter valid number';
                  }
                  if (deliveryQty <= 0) {
                    return 'Must be greater than 0';
                  }
                  final quantity = detail['quantity'] as int;
                  final currentDeliveryCount = detail['deliverycount'] ?? 0;
                  final newTotal = currentDeliveryCount + deliveryQty;
                  if (newTotal > quantity) {
                    return 'Total delivery ($newTotal) cannot exceed quantity ($quantity)';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: AppConstants.spacingM),
            // Delivery Note
            TextFormField(
              initialValue: detail['deliverynote']?.toString() ?? '',
              decoration: InputDecoration(
                labelText: 'Delivery Note',
                hintText: 'Add any notes for this delivery',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: AppConstants.spacingS,
                ),
                suffixIcon: Icon(
                  Icons.note_outlined,
                  color: AppConstants.primaryColor,
                ),
              ),
              maxLines: 3,
              minLines: 1,
              onChanged:
                  (value) => setState(() {
                    _ornamentDetails[index]['deliverynote'] = value;
                  }),
            ),
            const SizedBox(height: AppConstants.spacingM),
            // Delivery Date
            GestureDetector(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: detail['deliverydate'] ?? DateTime.now(),
                  firstDate: DateTime(2020),
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
                if (picked != null) {
                  setState(() {
                    _ornamentDetails[index]['deliverydate'] = picked;
                  });
                }
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Delivery Date',
                    hintText: 'Select delivery date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingS,
                    ),
                    suffixIcon: Icon(
                      Icons.calendar_today,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                  controller: TextEditingController(
                    text:
                        detail['deliverydate'] != null
                            ? _formatDateDDMMYYYY(detail['deliverydate'])
                            : _formatDateDDMMYYYY(DateTime.now()),
                  ),
                  validator: (value) {
                    if (_selectedStatus == OrderStatus.partialDelivery &&
                        (value == null || value.isEmpty)) {
                      return 'Please select delivery date';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppConstants.spacingS,
              children: [
                Text(
                  'Files for item ${index + 1}',
                  style: AppConstants.bodyMedium,
                ),
                if (_isPickingImage)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showFilePickerOptions(index),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Add Files'),
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
                separatorBuilder:
                    (_, __) => const SizedBox(width: AppConstants.spacingS),
                itemBuilder: (context, imgIdx) {
                  final url = _existingOrnamentImageUrls[index][imgIdx];
                  final backupUrl = (index < _existingOrnamentBackupImageUrls.length &&
                          _existingOrnamentBackupImageUrls[index].length > imgIdx)
                      ? _existingOrnamentBackupImageUrls[index][imgIdx]
                      : null;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                        child: FallbackNetworkImage(
                          primaryUrl: url,
                          backupUrl: backupUrl,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: InkWell(
                          onTap: () => setState(() {
                            _existingOrnamentImageUrls[index].removeAt(imgIdx);
                            if (_existingOrnamentBackupImageUrls.length > index &&
                                _existingOrnamentBackupImageUrls[index].length > imgIdx) {
                              _existingOrnamentBackupImageUrls[index].removeAt(imgIdx);
                            }
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppConstants.errorColor,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
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
                separatorBuilder:
                    (_, __) => const SizedBox(width: AppConstants.spacingS),
                itemBuilder: (context, imgIdx) {
                  final file = _ornamentImages[index][imgIdx];
                  final bytes = file.bytes;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                        child: SizedBox(
                          width: 90,
                          height: 90,
                          child:
                              _isPdfFile(file)
                                  ? Container(
                                    color: Colors.grey.shade100,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf,
                                          color: Colors.red,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0,
                                          ),
                                          child: Text(
                                            (file.name),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : (bytes != null
                                      ? Image.memory(
                                        bytes,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                      )
                                      : Container(
                                        color: Colors.grey.shade100,
                                        child: Icon(
                                          Icons.image,
                                          color: Colors.grey.shade400,
                                        ),
                                      )),
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: InkWell(
                          onTap:
                              () => setState(
                                () => _ornamentImages[index].removeAt(imgIdx),
                              ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppConstants.errorColor,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (_isImageFile(file) && bytes != null)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: GestureDetector(
                            onTap: () => _showImageEditorForItem(index, imgIdx),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
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
