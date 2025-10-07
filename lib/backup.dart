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
  final Map<int, List<GlobalKey>> _ornamentPageKeys = {};
  PageController? _ornamentPageController;
  PageController? _imagePageController;
  int _currentOrnamentIndex = 0;
  int _currentImageIndex = 0;
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

  List<List<String>> _partitionImages(List<String> images, {int pageSize = 4}) {
    final List<List<String>> pages = [];
    for (int i = 0; i < images.length; i += pageSize) {
      pages.add(
        images.sublist(
          i,
          i + pageSize > images.length ? images.length : i + pageSize,
        ),
      );
    }
    return pages.isEmpty ? [[]] : pages;
  }

  List<GlobalKey> _ensurePageKeys(int ornamentIndex, int pageCount) {
    final existing = _ornamentPageKeys[ornamentIndex] ?? [];
    if (existing.length != pageCount) {
      _ornamentPageKeys[ornamentIndex] = List.generate(
        pageCount,
        (_) => GlobalKey(),
      );
    }
    return _ornamentPageKeys[ornamentIndex]!;
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
          child:
              widget.order.ornamentDetails.isEmpty
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
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          Text(
            '#${widget.order.id.substring(0, 8).toUpperCase()}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: Material(
            color:
                _isGeneratingImage
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _isGeneratingImage ? null : _generateAndShareImage,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isGeneratingImage)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF64748B),
                        ),
                      )
                    else
                      Icon(Icons.share_outlined, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _isGeneratingImage ? 'Sharing...' : 'Share',
                      style: TextStyle(
                        fontSize: 12,
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
    final keys = _ensurePageKeys(-1, pages.length);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _imagePageController,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemCount: pages.length,
            itemBuilder:
                (context, index) => _buildComposedPage(
                  pageKey: keys[index],
                  ornamentName: 'Order',
                  purity: '-',
                  unit: '-',
                  size: '-',
                  colorstone: '-',
                  rhodium: '-',
                  dull: '-',
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
              final images =
                  ornament.images.isNotEmpty
                      ? ornament.images
                      : widget.order.images;
              final pages = _partitionImages(images);
              final keys = _ensurePageKeys(index, pages.length);
              return Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _imagePageController,
                      onPageChanged:
                          (i) => setState(() => _currentImageIndex = i),
                      itemCount: pages.length,
                      itemBuilder:
                          (context, pageIdx) => _buildComposedPage(
                            pageKey: keys[pageIdx],
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
                            images: pages[pageIdx],
                          ),
                    ),
                  ),
                  if (pages.length > 1)
                    _buildGeneratedPageIndicators(pages.length),
                ],
              );
            },
          ),
        ),
        if (widget.order.ornamentDetails.length > 1)
          _buildModernPageIndicators(),
      ],
    );
  }

  Widget _buildComposedPage({
    required GlobalKey pageKey,
    required String ornamentName,
    required String purity,
    required String weight,
    required String quantity,
    required String remarks,
    required List<String> images,
    required String unit,
    required String size,
    required String colorstone,
    required String rhodium,
    required String dull,
  }) {
    return RepaintBoundary(
      key: pageKey,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? 600 : 900),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child:
                      isMobile
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: _buildDetailsTable(
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
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: _buildImagesGridForPage(
                                      images,
                                      isMobile: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                          : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 10,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: _buildDetailsTable(
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
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 15,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
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

  Widget _buildDetailsTable(
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
  ) {
    Text cell(String text, {bool bold = false, Color? color}) => Text(
      text,
      style: TextStyle(
        fontSize: 12, // Reduced from 14
        fontWeight:
            bold ? FontWeight.w700 : FontWeight.w400, // Adjusted weights
        color: color ?? const Color(0xFF0F172A),
      ),
    );
    Widget row(String label1, String value1, String label2, String value2) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Flexible(
                flex: 1,
                child: cell(
                  '$label1 :',
                  bold: true,
                  color: const Color(0xFF334155),
                ),
              ),
              Flexible(
                flex: 2,
                child: cell(value1, color: const Color(0xFF111827)),
              ),
              if (label2.isNotEmpty)
                Flexible(
                  flex: 1,
                  child: cell(
                    '$label2 :',
                    bold: true,
                    color: const Color(0xFF334155),
                  ),
                ),
              if (label2.isNotEmpty)
                Flexible(
                  flex: 2,
                  child: cell(value2, color: const Color(0xFF111827)),
                ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          'Order No.',
          widget.order.orderNo ?? widget.order.id.substring(0, 8).toUpperCase(),
          'Order Date',
          _formatDate(widget.order.orderDate ?? widget.order.createdAt),
        ),
        row('Party Name', widget.order.clientName, '', ''),
        row('Items', ornamentName, '', ''),
        row('Purity', purity, 'Unit', unit),
        row('Size', size, 'Weight', weight),
        row('Qty', quantity, 'Colorstone', colorstone),
        row('Rhodium', rhodium, '', ''),
        row('Dull', dull, '', ''),
        row('Remarks', remarks.isNotEmpty ? remarks : '-', '', ''),
      ],
    );
  }

  Widget _buildImagesGridForPage(List<String> images, {bool isMobile = false}) {
    if (images.isEmpty) {
      return Center(child: _buildNoImagesState());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount =
            isMobile
                ? (width < 400 ? 1 : (width < 600 ? 2 : 3))
                : (width < 800 ? 2 : (width < 1000 ? 3 : 4));
        return Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            itemCount: images.length,
            itemBuilder: (context, i) => _buildModernImageCard(images[i]),
          ),
        );
      },
    );
  }

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
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      width: active ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: active ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: const Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Order tracking and details',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(widget.order.statusText),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoGrid(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'DC':
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
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
            const SizedBox(width: 12),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Order Date',
                  _formatDate(widget.order.orderDate!),
                  Icons.event,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.diamond,
                  color: const Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ornament.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ornament Details',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOrnamentSpecs(ornament),
          if (ornament.remarks != null && ornament.remarks!.isNotEmpty) ...[
            const SizedBox(height: 16),
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
        const SizedBox(width: 10),
        Expanded(
          child: _buildSpecItem(
            'Weight',
            '${ornament.weight}g',
            Icons.scale_outlined,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 10),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
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
                size: 14,
                color: const Color(0xFFD97706),
              ),
              const SizedBox(width: 6),
              Text(
                'Special Notes',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            remarks,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF92400E),
              height: 1.3,
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: const Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${images.length} image${images.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder:
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildModernImageCard(images[index]),
                ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildModernImageCard(String imageUrl) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFF1F5F9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Loading image...',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => _buildImageError(),
          ),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.broken_image_outlined,
                size: 24,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Image not available',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Failed to load image',
              style: TextStyle(fontSize: 10, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImagesState() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF64748B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 36,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'No Images Available',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Images will appear here when uploaded',
              style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPageIndicators() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withOpacity(0.1),
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
              Text('Preparing order details for sharing...'),
            ],
          ),
          backgroundColor: const Color(0xFF3B82F6),
          duration: const Duration(seconds: 2),
        ),
      );

      final List<Uint8List> pagePngs = [];
      final sortedKeys = _ornamentPageKeys.keys.toList()..sort();
      for (final ornamentIndex in sortedKeys) {
        final keys = _ornamentPageKeys[ornamentIndex] ?? [];
        for (int i = 0; i < keys.length; i++) {
          final key = keys[i];
          final boundary =
              key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundary == null) continue;
          final pageImage = await boundary.toImage(pixelRatio: 3.0);
          final pageBytes = await pageImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (pageBytes == null) continue;
          pagePngs.add(pageBytes.buffer.asUint8List());
        }
      }

      if (kIsWeb) {
        final files = <XFile>[];
        for (int i = 0; i < pagePngs.length; i++) {
          files.add(
            XFile.fromData(
              pagePngs[i],
              mimeType: 'image/png',
              name: 'order_${widget.order.id}_$i.png',
            ),
          );
        }
        await Share.shareXFiles(
          files,
          text: 'Order Details - ${widget.order.id}',
        );
      } else {
        final directory = await getTemporaryDirectory();
        final files = <XFile>[];
        for (int i = 0; i < pagePngs.length; i++) {
          final file = File(
            '${directory.path}/generated_${widget.order.id}_$i.png',
          );
          await file.writeAsBytes(pagePngs[i]);
          files.add(XFile(file.path));
        }
        await Share.shareXFiles(
          files,
          text: 'Order Details - ${widget.order.id}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 12),
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
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 12),
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
