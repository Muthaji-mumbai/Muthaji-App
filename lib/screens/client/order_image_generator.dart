import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soloshine/constants/app_constants.dart';
import '../../models/order.dart';
import '../../widgets/fallback_image.dart';

class OrderImageGenerator extends StatefulWidget {
  final Order order;
  const OrderImageGenerator({super.key, required this.order});

  @override
  State<OrderImageGenerator> createState() => _OrderImageGeneratorState();
}

class _OrderImageGeneratorState extends State<OrderImageGenerator> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final Map<int, GlobalKey> _ornamentKeys = {};
  PageController? _ornamentPageController;
  int _currentOrnamentIndex = 0;
  bool _isGeneratingImage = false;

  @override
  void initState() {
    super.initState();
    _ornamentPageController = PageController();
  }

  @override
  void dispose() {
    _ornamentPageController?.dispose();
    super.dispose();
  }

  List<String> get _currentOrnamentImages {
    if (widget.order.ornamentDetails.isEmpty) return widget.order.images;
    final selectedOrnament =
        widget.order.ornamentDetails[_currentOrnamentIndex];
    return selectedOrnament.images.isNotEmpty
        ? selectedOrnament.images
        : widget.order.images;
  }

  GlobalKey _ensureOrnamentKey(int ornamentIndex) {
    if (!_ornamentKeys.containsKey(ornamentIndex)) {
      _ornamentKeys[ornamentIndex] = GlobalKey();
    }
    return _ornamentKeys[ornamentIndex]!;
  }

  Future<void> _waitForBuild() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RepaintBoundary(
          key: _repaintBoundaryKey,
          child: Container(
            color: Colors.grey[50],
            child:
                widget.order.ornamentDetails.isEmpty
                    ? _buildSingleOrderView()
                    : _buildMultiOrnamentView(),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.grey[800],
      elevation: 1,
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Order Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          Text(
            '#${widget.order.id.substring(0, 8).toUpperCase()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(widget.order.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getStatusColor(widget.order.status).withOpacity(0.3),
              ),
            ),
            child: Text(
              _getStatusText(widget.order.status),
              style: TextStyle(
                color: _getStatusColor(widget.order.status),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ElevatedButton.icon(
            onPressed: _isGeneratingImage ? null : _generateAndShareImage,
            icon:
                _isGeneratingImage
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Icon(Icons.share, size: 16),
            label: Text(
              _isGeneratingImage ? 'Sharing...' : 'Share',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isGeneratingImage ? Colors.grey : Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleOrderView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final key = _ensureOrnamentKey(-1);
        return _buildOrderPage(
          pageKey: key,
          ornamentName: 'Order Items',
          purity: '-',
          unit: '-',
          size: '-',
          colorstone: '-',
          rhodium: '-',
          dull: '-',
          weight: '-',
          quantity: '-',
          remarks: widget.order.notes ?? '',
          images: widget.order.images,
          backupImages: widget.order.backupImages,
          width: constraints.maxWidth,
        );
      },
    );
  }

  Widget _buildMultiOrnamentView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ornamentPageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentOrnamentIndex = index;
                  });
                },
                itemCount: widget.order.ornamentDetails.length,
                itemBuilder: (context, index) {
                  final ornament = widget.order.ornamentDetails[index];
                  final images =
                      ornament.images.isNotEmpty
                          ? ornament.images
                          : widget.order.images;
                  final backupImages =
                      ornament.backupImages.isNotEmpty
                          ? ornament.backupImages
                          : widget.order.backupImages;
                  final key = _ensureOrnamentKey(index);
                  return _buildOrderPage(
                    pageKey: key,
                    ornamentName: ornament.name,
                    purity: ornament.purity,
                    unit: ornament.unit ?? '-',
                    size: ornament.size ?? '-',
                    colorstone: ornament.colorstone ?? '-',
                    rhodium: ornament.rhodium ?? '-',
                    dull: ornament.dull ?? '-',
                    weight: '${ornament.weight}g',
                    quantity: '${ornament.quantity}',
                    remarks: ornament.remarks ?? '',
                    images: images,
                    backupImages: backupImages,
                    width: constraints.maxWidth,
                  );
                },
              ),
            ),
            if (widget.order.ornamentDetails.length > 1)
              _buildOrnamentIndicators(),
          ],
        );
      },
    );
  }

  Widget _buildOrderPage({
    required GlobalKey pageKey,
    required String ornamentName,
    required String purity,
    required String weight,
    required String quantity,
    required String remarks,
    required List<String> images,
    required List<String> backupImages,
    required String unit,
    required String size,
    required String colorstone,
    required String rhodium,
    required String dull,
    required double width,
  }) {
    return RepaintBoundary(
      key: pageKey,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            if (isCompact) {
              return _buildCompactLayout(
                ornamentName,
                purity,
                weight,
                quantity,
                remarks,
                unit,
                size,
                colorstone,
                rhodium,
                dull,
                images,
                backupImages,
                constraints.maxWidth,
              );
            } else {
              return _buildWideLayout(
                ornamentName,
                purity,
                weight,
                quantity,
                remarks,
                unit,
                size,
                colorstone,
                rhodium,
                dull,
                images,
                backupImages,
                constraints.maxWidth,
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildCompactLayout(
    String ornamentName,
    String purity,
    String weight,
    String quantity,
    String remarks,
    String unit,
    String size,
    String colorstone,
    String rhodium,
    String dull,
    List<String> images,
    List<String> backupImages,
    double width,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blue[600], size: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ornamentName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      widget.order.orderDate != null
                          ? _formatDate(widget.order.orderDate!)
                          : '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                    // Show party name for bulk orders
                    if (widget.order.orderType == 'Bulk' &&
                        widget.order.partynameDisplay != null)
                      Text(
                        'Party: ${widget.order.partynameDisplay}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple[700],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.order.clientName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${widget.order.orderNo ?? widget.order.id.substring(0, 8).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildDetailsGrid(
            ornamentName,
            purity,
            weight,
            quantity,
            remarks,
            unit,
            size,
            colorstone,
            rhodium,
            dull,
            width,
          ),
        ),
        if (images.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildImagesGrid(images, backupImages, width),
          ),
        ] else
          const Expanded(child: Center(child: _NoImagesWidget())),
      ],
    );
  }

  Widget _buildWideLayout(
    String ornamentName,
    String purity,
    String weight,
    String quantity,
    String remarks,
    String unit,
    String size,
    String colorstone,
    String rhodium,
    String dull,
    List<String> images,
    List<String> backupImages,
    double width,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ornamentName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildDetailsGrid(
                    ornamentName,
                    purity,
                    weight,
                    quantity,
                    remarks,
                    unit,
                    size,
                    colorstone,
                    rhodium,
                    dull,
                    width,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: Colors.grey[200]),
        Expanded(
          flex: 3,
          child:
              images.isNotEmpty
                  ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildImagesGrid(images, backupImages, width),
                  )
                  : const Center(child: _NoImagesWidget()),
        ),
      ],
    );
  }

  Widget _buildDetailsGrid(
    String ornamentName,
    String purity,
    String weight,
    String quantity,
    String remarks,
    String unit,
    String size,
    String colorstone,
    String rhodium,
    String dull,
    double width,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Status chip at the top of details grid
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.order.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(widget.order.status).withOpacity(0.3),
                ),
              ),
              child: Text(
                _getStatusText(widget.order.status),
                style: TextStyle(
                  color: _getStatusColor(widget.order.status),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _buildDetailRow('Purity', purity),
          _buildDetailRow('Unit', unit),
          _buildDetailRow('Size', size),
          _buildDetailRow('Weight', weight),
          _buildDetailRow('Quantity', quantity),
          _buildDetailRow('Colorstone', colorstone),
          _buildDetailRow('Rhodium', rhodium),
          _buildDetailRow('Dull', dull),
          if (remarks.isNotEmpty) ...[_buildRemarksSection(remarks)],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksSection(String remarks) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_outlined, size: 14, color: Colors.amber[700]),
              const SizedBox(width: 4),
              Text(
                'Remarks',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            remarks,
            style: TextStyle(
              fontSize: 9,
              color: Colors.amber[800],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesGrid(List<String> images, List<String>? backupImages, double width) {
    if (images.isEmpty) return const _NoImagesWidget();

    const int gridCount = 6; // Fixed 2x3 grid (6 slots)

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7, // Adjusted for 2x3 grid
      ),
      itemCount: gridCount,
      itemBuilder: (context, index) {
        if (index < images.length) {
          final backupUrl = (backupImages != null && backupImages.length > index) ? backupImages[index] : null;
          return _buildImageCard(images[index], backupUrl);
        } else {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey[200]!),
            ),
          ); // Empty container for unused grid slots
        }
      },
    );
  }

  int _getDynamicGridCount(double width, int gridCount) {
    return 3; // Always 3 columns for 2x3 grid
  }

  Widget _buildImageCard(String imageUrl, String? backupUrl) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FallbackNetworkImage(
          primaryUrl: imageUrl,
          backupUrl: backupUrl,
          fit: BoxFit.cover,
          errorWidget: Container(
            color: Colors.red[50],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: Colors.red[300],
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Failed to load',
                    style: TextStyle(fontSize: 10, color: Colors.red[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrnamentIndicators() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                widget.order.ornamentDetails.length,
                (index) => GestureDetector(
                  onTap: () {
                    _ornamentPageController?.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _currentOrnamentIndex ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color:
                          index == _currentOrnamentIndex
                              ? Colors.blue
                              : Colors.grey[300],
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

  Future<void> _generateAndShareImage() async {
    if (_isGeneratingImage) return;
    setState(() => _isGeneratingImage = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text('Preparing all ornament details for sharing...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );

      final List<Uint8List> pagePngs = [];

      if (widget.order.ornamentDetails.isEmpty) {
        final index = -1;
        _ensureOrnamentKey(index);
        final key = _ornamentKeys[index]!;
        final boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final pageImage = await boundary.toImage(pixelRatio: 3.0);
          final pageBytes = await pageImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (pageBytes != null) {
            pagePngs.add(pageBytes.buffer.asUint8List());
          }
        }
      } else {
        final int originalIndex = _currentOrnamentIndex;
        final int totalOrnaments = widget.order.ornamentDetails.length;

        for (int i = 0; i < totalOrnaments; i++) {
          _ornamentPageController?.jumpToPage(i);
          if (mounted) {
            setState(() {
              _currentOrnamentIndex = i;
            });
          }

          await _waitForBuild();

          final key = _ornamentKeys[i] ?? _ensureOrnamentKey(i);
          final boundary =
              key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            final pageImage = await boundary.toImage(pixelRatio: 3.0);
            final pageBytes = await pageImage.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (pageBytes != null) {
              pagePngs.add(pageBytes.buffer.asUint8List());
            }
          }
        }

        if (mounted) {
          _ornamentPageController?.jumpToPage(originalIndex);
          setState(() {
            _currentOrnamentIndex = originalIndex;
          });
          await _waitForBuild();
        }
      }

      if (pagePngs.isEmpty) {
        throw Exception('No images could be generated');
      }

      final files = <XFile>[];
      if (kIsWeb) {
        for (int i = 0; i < pagePngs.length; i++) {
          files.add(
            XFile.fromData(
              pagePngs[i],
              mimeType: 'image/png',
              name: 'order_${widget.order.id}_page${i + 1}.png',
            ),
          );
        }
      } else {
        final directory = await getTemporaryDirectory();
        for (int i = 0; i < pagePngs.length; i++) {
          final file = File(
            '${directory.path}/order_${widget.order.id}_page${i + 1}.png',
          );
          await file.writeAsBytes(pagePngs[i]);
          files.add(XFile(file.path));
        }
      }

      await Share.shareXFiles(
        files,
        text:
            'Order Details - ${widget.order.orderNo},${widget.order.clientName}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Text('All ornament details shared successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to share: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingImage = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // Helper to get readable status string
  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.Casted:
        return 'Casted';
      case OrderStatus.Wax:
        return 'Wax';
      case OrderStatus.DC:
        return 'DC';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.delay:
        return 'Delay';
      case OrderStatus.due:
        return 'Due';
      case OrderStatus.partialDelivery:
        return 'Partial Delivery';
      case OrderStatus.PendingDisp:
        return 'PendingDisp';
      case OrderStatus.Completed:
        return 'Completed';
      case OrderStatus.Delivered:
        return 'Delivered';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFF9800); // Orange
      case OrderStatus.Casted:
        return const Color(0xFF2196F3); // Blue
      case OrderStatus.Wax:
        return const Color(0xFF9C27B0); // Purple
      case OrderStatus.DC:
        return const Color(0xFF4CAF50); // Green
      case OrderStatus.cancelled:
        return const Color(0xFFF44336); // Red
      case OrderStatus.delay:
        return const ui.Color.fromARGB(255, 0, 0, 0); // Black
      case OrderStatus.due:
        return const Color(0xFFF44336); // Red
      case OrderStatus.partialDelivery:
        return Colors.teal; // fallback
      case OrderStatus.PendingDisp:
        return Colors.amber;
      case OrderStatus.Completed:
        return AppConstants.Completed;
      case OrderStatus.Delivered:
        return AppConstants.deliveredColor;
    }
  }
}

class _NoImagesWidget extends StatelessWidget {
  const _NoImagesWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No Images Available',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Images will appear here when uploaded',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
