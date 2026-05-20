import 'package:flutter/material.dart';

import '../../../core/widgets/aspect_ratio_network_image.dart';

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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
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
            return AspectRatioNetworkImage(
              url: widget.images[i],
              width: double.infinity,
              borderRadius: BorderRadius.circular(14),
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
    );
  }
}
