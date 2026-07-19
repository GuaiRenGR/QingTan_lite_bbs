import 'package:flutter/material.dart';

import '../services/image_cache_service.dart';

class AspectRatioNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// true = 展示整张图不裁剪（图片模式），false = 裁剪填充（推荐页卡片）
  final bool containMode;

  const AspectRatioNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.containMode = false,
  });

  @override
  State<AspectRatioNetworkImage> createState() =>
      _AspectRatioNetworkImageState();
}

class _AspectRatioNetworkImageState extends State<AspectRatioNetworkImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageProvider<Object>? _provider;

  double? _aspectRatio;
  bool _failed = false;

  static const double minRatio = 9 / 16;
  static const double maxRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AspectRatioNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _removeListener();
      _provider = null;
      _aspectRatio = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    if (widget.url.isEmpty) {
      setState(() {
        _failed = true;
      });
      return;
    }

    final imageCache = ImageCacheService.instance;
    final imageUrl = imageCache.resolveUrl(widget.url);
    if (imageUrl.isEmpty) {
      setState(() {
        _failed = true;
      });
      return;
    }

    final provider = imageCache.provider(imageUrl);
    final stream = provider.resolve(const ImageConfiguration());

    _provider = provider;

    _listener = ImageStreamListener(
      (info, _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();

        if (!mounted || width <= 0 || height <= 0) return;

        final rawRatio = width / height;
        final displayRatio = widget.containMode
            ? rawRatio
            : rawRatio.clamp(minRatio, maxRatio).toDouble();

        setState(() {
          _aspectRatio = displayRatio;
        });
      },
      onError: (_, _) {
        if (!mounted) return;
        setState(() {
          _failed = true;
        });
      },
    );

    _stream = stream;
    stream.addListener(_listener!);
  }

  void _removeListener() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.errorWidget ??
          Container(
            width: widget.width ?? double.infinity,
            height: 120,
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.grey.shade400,
            ),
          );
    }

    if (_aspectRatio == null) {
      return widget.placeholder ??
          Container(
            width: widget.width ?? double.infinity,
            height: 160,
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }

    Widget image = LayoutBuilder(
      builder: (context, constraints) {
        final ratio = _aspectRatio!;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (widget.width ?? MediaQuery.of(context).size.width);
        final imageHeight = maxWidth / ratio;

        final img = Image(
          image: _provider!,
          width: maxWidth,
          height: imageHeight,
          fit: widget.containMode ? BoxFit.contain : widget.fit,
          alignment:
              widget.containMode ? Alignment.center : Alignment.topCenter,
          errorBuilder: (_, _, _) {
            return widget.errorWidget ??
                Container(
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.grey.shade400,
                  ),
                );
          },
        );

        return SizedBox(
          width: maxWidth,
          height: imageHeight,
          child:
              widget.containMode ? img : ClipRect(child: img),
        );
      },
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
