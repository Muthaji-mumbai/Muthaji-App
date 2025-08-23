
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soloshine/constants/app_constants.dart';
import 'package:soloshine/models/order.dart';
import 'package:soloshine/screens/employee/manage_orders_screen.dart';
import 'package:soloshine/widgets/custom_button.dart';

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
          const SnackBar(content: Text('Image saved to gallery')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save image')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading image: $e')),
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
        SnackBar(content: Text('Error sharing image: $e')),
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.order.description,
                style: AppConstants.headingMedium,
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildDetailRow('Client', widget.order.clientName),
              _buildDetailRow('Amount', '\$${widget.order.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Created At', _formatDate(widget.order.createdAt)),
              if (widget.order.orderDate != null)
                _buildDetailRow('Order Date', _formatDate(widget.order.orderDate!)),
              if (widget.order.orderType != null)
                _buildDetailRow('Type', widget.order.orderType!),
              if (widget.order.notes != null && widget.order.notes!.isNotEmpty)
                _buildDetailRow('Notes', widget.order.notes!),
              if (widget.order.ornamentDetails.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingM),
                Text(
                  'Ornament Details:',
                  style: AppConstants.headingSmall,
                ),
                const SizedBox(height: AppConstants.spacingS),
                ...widget.order.ornamentDetails.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
                    child: Text(
                      '• ${detail.name} - ${detail.material} (${detail.weight}g, ${detail.purity}) x${detail.quantity}',
                      style: AppConstants.bodyMedium,
                    ),
                  ),
                ),
              ],
              if (widget.order.images.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingM),
                Text(
                  'Images:',
                  style: AppConstants.headingSmall,
                ),
                const SizedBox(height: AppConstants.spacingS),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
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
                CustomButton(
                  text: _isDownloadingAll ? 'Downloading...' : 'Download All Images',
                  onPressed: _isDownloadingAll ? null : _downloadAllImages,
                  backgroundColor: AppConstants.primaryColor,
                  isFullWidth: true,
                  isLoading: _isDownloadingAll,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AppConstants.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value, style: AppConstants.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}  