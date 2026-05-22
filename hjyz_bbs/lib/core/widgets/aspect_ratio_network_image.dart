import 'package:flutter/material.dart';

class AspectRatioNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AspectRatioNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<AspectRatioNetworkImage> createState() =>
      _AspectRatioNetworkImageState();
}

class _AspectRatioNetworkImageState extends State<AspectRatioNetworkImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  double? _rawRatio;
  bool _failed = false;

  static const double _minRatio = 9 / 16;
  static const double _maxRatio = 16 / 9;

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
      _rawRatio = null;
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

    final provider = NetworkImage(widget.url);
    final stream = provider.resolve(const ImageConfiguration());

    _listener = ImageStreamListener(
      (info, _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();

        if (!mounted || width <= 0 || height <= 0) return;

        setState(() {
          _rawRatio = width / height;
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

  Widget _buildError() {
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

  Widget _buildPlaceholder() {
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

  @override
  Widget build(BuildContext context) {
    if (_failed) return _buildError();
    if (_rawRatio == null) return _buildPlaceholder();

    final rawRatio = _rawRatio!;
    final ratio = rawRatio.clamp(_minRatio, _maxRatio).toDouble();
    final isTall = rawRatio < _minRatio;

    Widget image = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (widget.width ?? MediaQuery.of(context).size.width);
        final maxHeight = maxWidth / ratio;

        return SizedBox(
          width: maxWidth,
          height: maxHeight,
          child: Image.network(
            widget.url,
            width: maxWidth,
            height: maxHeight,
            fit: isTall ? BoxFit.contain : widget.fit,
            alignment: isTall ? Alignment.center : Alignment.topCenter,
            errorBuilder: (_, _, _) => _buildError(),
          ),
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
