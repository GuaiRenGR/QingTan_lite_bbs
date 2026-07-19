import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/image_cache_service.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final imageCache = ImageCacheService.instance;
    final imageUrl = imageCache.resolveUrl(url ?? '');
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = _cacheDimension(width, devicePixelRatio);
    final cacheHeight = cacheWidth == null
        ? _cacheDimension(height, devicePixelRatio)
        : null;

    final child = imageUrl.isEmpty
        ? _buildError()
        : CachedNetworkImage(
            imageUrl: imageUrl,
            cacheManager: imageCache.cacheManager,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            fadeInDuration: const Duration(milliseconds: 120),
            useOldImageOnUrlChange: true,
            placeholder: (_, _) =>
                placeholder ??
                Container(
                  width: width,
                  height: height,
                  color: Colors.grey.shade200,
                ),
            errorWidget: (_, _, _) => _buildError(),
          );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }

    return child;
  }

  int? _cacheDimension(double? logicalSize, double devicePixelRatio) {
    if (logicalSize == null || !logicalSize.isFinite || logicalSize <= 0) {
      return null;
    }

    return (logicalSize * devicePixelRatio).round().clamp(1, 2048).toInt();
  }

  Widget _buildError() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade500,
          ),
        );
  }
}
