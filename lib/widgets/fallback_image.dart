import 'package:flutter/material.dart';

class FallbackNetworkImage extends StatelessWidget {
  final String primaryUrl;
  final String? backupUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  final Widget? errorWidget;

  const FallbackNetworkImage({
    super.key,
    required this.primaryUrl,
    this.backupUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (primaryUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      primaryUrl,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        if (backupUrl != null && backupUrl!.isNotEmpty) {
          return Image.network(
            backupUrl!,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, error2, stackTrace2) {
              return _buildPlaceholder();
            },
          );
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    if (errorWidget != null) {
      return errorWidget!;
    }
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.grey.shade400,
      ),
    );
  }
}
