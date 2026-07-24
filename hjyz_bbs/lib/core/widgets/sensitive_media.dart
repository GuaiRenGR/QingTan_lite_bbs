import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/sensitive_content_service.dart';
import '../theme/app_colors.dart';

const sensitiveLabelNames = <String, String>{
  'sensitive': '敏感内容',
  'nudity': '裸体',
  'adult': '成人内容',
  'violence': '暴力血腥',
  'politics': '政治相关',
};

List<String> parseSensitiveLabels(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString())
      .where(sensitiveLabelNames.containsKey)
      .toSet()
      .toList();
}

class SensitiveMedia extends StatefulWidget {
  final List<String> labels;
  final Widget child;
  final double blockedHeight;

  const SensitiveMedia({
    super.key,
    required this.labels,
    required this.child,
    this.blockedHeight = 180,
  });

  @override
  State<SensitiveMedia> createState() => _SensitiveMediaState();
}

class _SensitiveMediaState extends State<SensitiveMedia> {
  bool revealed = false;

  String get _labelText => widget.labels
      .map((label) => sensitiveLabelNames[label])
      .whereType<String>()
      .join('、');

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty || revealed) return widget.child;

    return ValueListenableBuilder<SensitiveContentMode>(
      valueListenable: SensitiveContentService.mode,
      builder: (context, mode, _) {
        if (mode == SensitiveContentMode.block) {
          return Container(
            width: double.infinity,
            height: widget.blockedHeight,
            color: AppColors.inputFill(context),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.visibility_off_outlined, size: 28),
                const SizedBox(height: 8),
                const Text(
                  '此图片已根据你的设置屏蔽',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _labelText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          );
        }

        return Stack(
          fit: StackFit.passthrough,
          alignment: Alignment.center,
          children: [
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: widget.child,
              ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.32),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '内容警告',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _labelText,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  FilledButton.tonal(
                    onPressed: () => setState(() => revealed = true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('显示'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
