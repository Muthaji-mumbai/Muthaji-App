import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../constants/app_constants.dart';
import '../../models/order.dart';

class OrderImageGenerator extends StatefulWidget {
  final Order order;
  const OrderImageGenerator({super.key, required this.order});
  @override
  State<OrderImageGenerator> createState() => _OrderImageGeneratorState();
}

class _OrderImageGeneratorState extends State<OrderImageGenerator> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  // One key per generated page so we can export all composed images
  final List<GlobalKey> _pageKeys = [];
  PageController? _ornamentPageController;
  PageController? _imagePageController; // pager for generated pages per ornament
  int _currentOrnamentIndex = 0;
  int _currentImageIndex = 0; // page index within generated pages
  bool _isGeneratingImage = false;

  @override
  void initState() {
    super.initState();
    _ornamentPageController = PageController();
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _ornamentPageController?.dispose();
    _imagePageController?.dispose();
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

  // Partition images into pages with up to 3 images per page
  List<List<String>> _partitionImages(List<String> images, {int pageSize = 3}) {
    final List<List<String>> pages = [];
    for (int i = 0; i < images.length; i += pageSize) {
      pages.add(images.sublist(i, i + pageSize > images.length ? images.length : i + pageSize));
    }
    return pages.isEmpty ? [[]] : pages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: RepaintBoundary(
        key: _repaintBoundaryKey,
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: widget.order.ornamentDetails.isEmpty
              ? _buildSingleOrderView()
              : _buildMultiOrnamentView(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      centerTitle: true,
      title: Column(
        children: [
          Text(
            'Order Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            '#${widget.order.id.substring(0, 8).toUpperCase()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Material(
            color:
                _isGeneratingImage
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isGeneratingImage ? null : _generateAndShareImage,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isGeneratingImage)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF64748B),
                        ),
                      )
                    else
                      Icon(Icons.share_outlined, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _isGeneratingImage ? 'Sharing...' : 'Share',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color:
                            _isGeneratingImage
                                ? const Color(0xFF64748B)
                                : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleOrderView() {
    final pages = _partitionImages(widget.order.images);
    _rebuildPageKeys(pages.length);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _imagePageController,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemCount: pages.length,
            itemBuilder: (context, index) => _buildComposedPage(
              pageKey: _pageKeys[index],
              ornamentName: 'Order',
              purity: '-',
              weight: '-',
              quantity: '-',
              remarks: widget.order.notes ?? '',
              images: pages[index],
            ),
          ),
        ),
        if (pages.length > 1) _buildGeneratedPageIndicators(pages.length),
      ],
    );
  }

  Widget _buildMultiOrnamentView() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _ornamentPageController,
            onPageChanged: (index) {
              setState(() {
                _currentOrnamentIndex = index;
                _currentImageIndex = 0;
                _imagePageController = PageController();
              });
            },
            itemCount: widget.order.ornamentDetails.length,
            itemBuilder: (context, index) {
              final ornament = widget.order.ornamentDetails[index];
              final images = ornament.images.isNotEmpty ? ornament.images : widget.order.images;
              final pages = _partitionImages(images);
              _rebuildPageKeys(pages.length);
              return Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _imagePageController,
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      itemCount: pages.length,
                      itemBuilder: (context, pageIdx) => _buildComposedPage(
                        pageKey: _pageKeys[pageIdx],
                        ornamentName: ornament.name,
                        purity: ornament.purity,
                        weight: '${ornament.weight}g',
                        quantity: '${ornament.quantity}',
                        remarks: ornament.remarks ?? '',
                        images: pages[pageIdx],
                      ),
                    ),
                  ),
                  if (pages.length > 1) _buildGeneratedPageIndicators(pages.length),
                ],
              );
            },
          ),
        ),
        if (widget.order.ornamentDetails.length > 1) _buildModernPageIndicators(),
      ],
    );
  }

  // Build a composed single page similar to the sample: details on left, images on right
  Widget _buildComposedPage({
    required GlobalKey pageKey,
    required String ornamentName,
    required String purity,
    required String weight,
    required String quantity,
    required String remarks,
    required List<String> images,
  }) {
    return RepaintBoundary(
      key: pageKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // Keep a nice readable width on desktop, narrower on mobile
                  maxWidth: isMobile ? 640 : 1000,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Details top
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildDetailsTable(
                                  ornamentName, purity, weight, quantity, remarks),
                            ),
                            // Images bottom
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: _buildImagesGridForPage(images, isMobile: true),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left: Details table
                            Expanded(
                              flex: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: _buildDetailsTable(
                                    ornamentName, purity, weight, quantity, remarks),
                              ),
                            ),
                            // Right: Images box
                            Expanded(
                              flex: 18,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: _buildImagesGridForPage(images),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailsTable(String ornamentName, String purity, String weight, String quantity, String remarks) {
    Text _cell(String text, {bool bold = false, Color? color}) => Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? const Color(0xFF0F172A),
          ),
        );
    Widget row(String label, String value, {bool emphasize = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              SizedBox(width: 110, child: _cell('$label :', bold: true, color: const Color(0xFF334155))),
              const SizedBox(width: 8),
              Expanded(child: _cell(value, bold: emphasize, color: emphasize ? const Color(0xFF111827) : null)),
            ],
          ),
        );

    return Column(
      children: [
        row('Order No.', widget.order.orderNo ?? widget.order.id.substring(0, 8).toUpperCase(), emphasize: true),
        row('Order Date', _formatDate(widget.order.orderDate ?? widget.order.createdAt)),
        row('Party Name', widget.order.clientName),
        row('Items', ornamentName, emphasize: true),
        row('Purity', purity),
        row('Weight', weight),
        row('Quantity', quantity),
        row('Remarks', remarks.isNotEmpty ? remarks : '-'),
      ],
    );
  }

  Widget _buildImagesGridForPage(List<String> images, {bool isMobile = false}) {
    if (images.isEmpty) {
      return Center(child: _buildNoImagesState());
    }
    // Layout: if 1 => big; if 2-3 => grid that fits
    if (images.length == 1) {
      return _buildModernImageCard(images.first, height: isMobile ? 240 : null);
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3 / 4,
        ),
        itemCount: images.length,
        itemBuilder: (context, i) => _buildModernImageCard(
          images[i],
          height: isMobile ? 160 : 220,
        ),
      ),
    );
  }

  // Page indicators for generated pages
  Widget _buildGeneratedPageIndicators(int length) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(length, (i) => _dot(i == _currentImageIndex)),
      ),
    );
  }

  Widget _dot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      width: active ? 18 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: active ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
      ),
    );
  }

  void _rebuildPageKeys(int length) {
    _pageKeys
      ..clear()
      ..addAll(List.generate(length, (_) => GlobalKey()));
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: const Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order tracking and details',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(widget.order.statusText),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoGrid(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = const Color(0xFF10B981).withOpacity(0.1);
        textColor = const Color(0xFF10B981);
        break;
      case 'pending':
        backgroundColor = const Color(0xFFF59E0B).withOpacity(0.1);
        textColor = const Color(0xFFF59E0B);
        break;
      case 'processing':
        backgroundColor = const Color(0xFF3B82F6).withOpacity(0.1);
        textColor = const Color(0xFF3B82F6);
        break;
      default:
        backgroundColor = const Color(0xFF64748B).withOpacity(0.1);
        textColor = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                'Order Number',
                widget.order.orderNo!,
                Icons.tag,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoItem(
                'Created',
                _formatDate(widget.order.createdAt),
                Icons.calendar_today,
              ),
            ),
          ],
        ),
        if (widget.order.orderDate != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Order Date',
                  _formatDate(widget.order.orderDate!),
                  Icons.event,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrnamentCard(ornament) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.diamond,
                  color: const Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ornament.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ornament Details',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildOrnamentSpecs(ornament),
          if (ornament.remarks != null && ornament.remarks!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildRemarksSection(ornament.remarks!),
          ],
        ],
      ),
    );
  }

  Widget _buildOrnamentSpecs(ornament) {
    return Row(
      children: [
        Expanded(
          child: _buildSpecItem(
            'Purity',
            ornament.purity.toString(),
            Icons.verified_outlined,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSpecItem(
            'Weight',
            '${ornament.weight}g',
            Icons.scale_outlined,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSpecItem(
            'Quantity',
            '${ornament.quantity}',
            Icons.inventory_2_outlined,
            const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksSection(String remarks) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD97706).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_outlined,
                size: 16,
                color: const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              Text(
                'Special Notes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            remarks,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF92400E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection(List<String> images, String title) {
    if (images.isEmpty) {
      return _buildNoImagesState();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: const Color(0xFF8B5CF6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${images.length} image${images.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: images.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder:
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildModernImageCard(images[index]),
                ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildModernImageCard(String imageUrl, {double? height}) {
    final double cardHeight = height ?? MediaQuery.of(context).size.height * 0.35;
    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF1F5F9),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: const Color(0xFFF1F5F9),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading image...',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: const Color(0xFFFEF2F2),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.broken_image_outlined,
                size: 32,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Image not available',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Failed to load image',
              style: TextStyle(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImagesState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF64748B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 48,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Images Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Images will appear here when uploaded',
              style: TextStyle(fontSize: 14, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPageIndicators() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withOpacity(0.1),
                  blurRadius: 10,
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
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentOrnamentIndex ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color:
                          index == _currentOrnamentIndex
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFE2E8F0),
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
    setState(() {
      _isGeneratingImage = true;
    });

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Text('Preparing order details for sharing...'),
            ],
          ),
          backgroundColor: const Color(0xFF3B82F6),
          duration: const Duration(seconds: 2),
        ),
      );

      // Capture the entire screen
      RenderRepaintBoundary boundary =
          _repaintBoundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Collect page images (bytes) from composed pages
      final List<Uint8List> pagePngs = [];
      for (int i = 0; i < _pageKeys.length; i++) {
        final key = _pageKeys[i];
        final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) continue;
        final pageImage = await boundary.toImage(pixelRatio: 3.0);
        final pageBytes = await pageImage.toByteData(format: ui.ImageByteFormat.png);
        if (pageBytes == null) continue;
        pagePngs.add(pageBytes.buffer.asUint8List());
      }

      // Add the main screen capture first
      pagePngs.insert(0, pngBytes);

      if (kIsWeb) {
        // Web: share in-memory files without path_provider
        final files = <XFile>[];
        for (int i = 0; i < pagePngs.length; i++) {
          files.add(XFile.fromData(
            pagePngs[i],
            mimeType: 'image/png',
            name: 'order_${widget.order.id}_$i.png',
          ));
        }
        await Share.shareXFiles(files, text: 'Order Details - ${widget.order.id}');
      } else {
        // Mobile/Desktop: write to temp directory and share file paths
        final directory = await getTemporaryDirectory();
        final files = <XFile>[];
        for (int i = 0; i < pagePngs.length; i++) {
          final file = File('${directory.path}/generated_${widget.order.id}_${_currentOrnamentIndex}_$i.png');
          await file.writeAsBytes(pagePngs[i]);
          files.add(XFile(file.path));
        }
        await Share.shareXFiles(files, text: 'Order Details - ${widget.order.id}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 16),
                Text('Order details shared successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 16),
                Expanded(child: Text('Failed to share: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingImage = false;
        });
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
}
