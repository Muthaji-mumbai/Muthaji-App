import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soloshine/constants/app_constants.dart';
import 'package:soloshine/models/order.dart';
import 'package:soloshine/screens/client/pdfview.dart';
import 'package:soloshine/screens/client/order_image_generator.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isDownloadingAll = false;

  Future<void> _requestPermissions() async {
    if (await Permission.photos.request().isDenied) {
      await Permission.photos.request();
    }
    if (await Permission.storage.request().isDenied) {
      await Permission.storage.request();
    }
  }

  Future<void> _downloadImage(String url) async {
    await _requestPermissions();

    try {
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data),
        quality: 100,
        name: 'order_image_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (result['isSuccess']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery'))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save image'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading image: $e'))
      );
    }
  }

  Future<void> _downloadAllImages() async {
    setState(() => _isDownloadingAll = true);
    for (var url in widget.order.images) {
      await _downloadImage(url);
    }
    setState(() => _isDownloadingAll = false);
  }

  Future<void> _shareImage(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/temp_image.jpg';
      await Dio().download(url, filePath);
      await Share.shareXFiles([XFile(filePath)], text: 'Check out this image!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image: $e'))
      );
    }
  }

  void _showFullScreenImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          images: widget.order.images,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'View Images',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderImageGenerator(order: widget.order),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Generate PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewerScreen(order: widget.order),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          return Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppConstants.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.order.description,
                          style: AppConstants.headingMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _chip('Client', widget.order.clientName, Icons.person_outline),
                            _chip('Created', _formatDate(widget.order.createdAt), Icons.event_outlined),
                            if (widget.order.orderDate != null)
                              _chip('Order Date', _formatDate(widget.order.orderDate!), Icons.calendar_today_outlined),
                            if (widget.order.orderType != null)
                              _chip('Type', widget.order.orderType!, Icons.category_outlined),
                          ],
                        ),
                        if (widget.order.notes != null && widget.order.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Notes', style: AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(widget.order.notes!, style: AppConstants.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                  if (widget.order.ornamentDetails.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingM),
                    Text('Ornament Details', style: AppConstants.headingSmall),
                    const SizedBox(height: AppConstants.spacingS),
                    ...widget.order.ornamentDetails.map((detail) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${detail.material} • ${detail.weight}g • ${detail.purity} • Qty: ${detail.quantity}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (detail.unit != null || detail.size != null || 
                                        detail.colorstone != null || detail.rhodium != null || 
                                        detail.dull != null) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (detail.unit != null)
                                            _buildDetailChip('Unit', detail.unit!),
                                          if (detail.size != null)
                                            _buildDetailChip('Size', detail.size!),
                                          if (detail.colorstone != null)
                                            _buildDetailChip('Color Stone', detail.colorstone!),
                                          if (detail.rhodium != null)
                                            _buildDetailChip('Rhodium', detail.rhodium!),
                                          if (detail.dull != null)
                                            _buildDetailChip('Dull', detail.dull!),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (detail.images.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isWide ? 5 : 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: detail.images.length,
                              itemBuilder: (context, index) {
                                final imageUrl = detail.images[index];
                                return GestureDetector(
                                  onTap: () => _showFullScreenImage(index),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.grey.shade100,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    )),
                  ],
                  if (widget.order.images.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingM),
                    Text('Images:', style: AppConstants.headingSmall),
                    const SizedBox(height: AppConstants.spacingS),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 4 : 2,
                        crossAxisSpacing: AppConstants.spacingS,
                        mainAxisSpacing: AppConstants.spacingS,
                        childAspectRatio: 1,
                      ),
                      itemCount: widget.order.images.length,
                      itemBuilder: (context, index) {
                        final imageUrl = widget.order.images[index];
                        return GestureDetector(
                          onTap: () => _showFullScreenImage(index),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppConstants.radiusS),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.download, color: Colors.white),
                                      onPressed: () => _downloadImage(imageUrl),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.white),
                                      onPressed: () => _shareImage(imageUrl),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppConstants.spacingM),
                    ElevatedButton.icon(
                      onPressed: _isDownloadingAll ? null : _downloadAllImages,
                      icon: const Icon(Icons.download),
                      label: Text(_isDownloadingAll ? 'Downloading...' : 'Download All Images'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppConstants.primaryColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${initialIndex + 1} of ${images.length}'),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(images[index]),
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(tag: images[index]),
          );
        },
        itemCount: images.length,
        loadingBuilder: (context, event) => Center(
          child: SizedBox(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              value: event == null ? 0 : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
            ),
          ),
        ),
        pageController: PageController(initialPage: initialIndex),
      ),
    );
  }
}
