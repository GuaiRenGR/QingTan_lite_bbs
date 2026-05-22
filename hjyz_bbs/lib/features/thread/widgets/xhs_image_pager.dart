import 'package:flutter/material.dart';

import '../../../core/widgets/aspect_ratio_network_image.dart';
import '../../../core/widgets/image_viewer.dart';

class XhsImagePager extends StatefulWidget {
  final List<String> images;

  const XhsImagePager({
    super.key,
    required this.images,
  });

  @override
  State<XhsImagePager> createState() => _XhsImagePagerState();
}

class _XhsImagePagerState extends State<XhsImagePager> {
  final controller = PageController();
  int index = 0;

  /// 首张图的宽高比（用于确定 PageView 高度）
  double? _firstImageRatio;
  bool _failed = false;

  static const double _minRatio = 9 / 16;
  static const double _maxRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    _resolveFirstImage();
  }

  @override
  void didUpdateWidget(covariant XhsImagePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images) {
      _firstImageRatio = null;
      _failed = false;
      _resolveFirstImage();
    }
  }

  void _resolveFirstImage() {
    if (widget.images.isEmpty) return;

    final provider = NetworkImage(widget.images.first);
    final stream = provider.resolve(const ImageConfiguration());

    stream.addListener(
      ImageStreamListener(
        (info, _) {
          final w = info.image.width.toDouble();
          final h = info.image.height.toDouble();
          if (!mounted || w <= 0 || h <= 0) return;

          setState(() {
            _firstImageRatio = (w / h).clamp(_minRatio, _maxRatio).toDouble();
          });
        },
        onError: (_, _) {
          if (!mounted) return;
          setState(() {
            _failed = true;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    // 还在加载首张图，显示占位
    if (_firstImageRatio == null && !_failed) {
      return Container(
        width: double.infinity,
        height: 200,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // 图片加载失败
    if (_failed || _firstImageRatio == null) {
      return Container(
        width: double.infinity,
        height: 120,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade400,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final pageHeight = maxWidth / _firstImageRatio!;

        return SizedBox(
          width: maxWidth,
          height: pageHeight,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: widget.images.length,
                onPageChanged: (value) {
                  setState(() {
                    index = value;
                  });
                },
                itemBuilder: (context, i) {
                  return GestureDetector(
                    onTap: () => ImageViewer.open(
                      context,
                      widget.images,
                      initialIndex: i,
                    ),
                    child: AspectRatioNetworkImage(
                      url: widget.images[i],
                      width: maxWidth,
                      containMode: true,
                    ),
                  );
                },
              ),
              if (widget.images.length > 1)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${index + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (widget.images.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < widget.images.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: i == index ? 14 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == index
                                ? const Color(0xFFFB7299)
                                : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
