import 'package:flutter/material.dart';

import '../emoji/emoji_data.dart';

/// Renders forum PUA emoji as images while keeping normal text selectable by
/// the surrounding widget.
class EmojiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final double imageSize;

  const EmojiText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.imageSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();

    void flushText() {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString()));
        buffer.clear();
      }
    }

    for (var index = 0; index < text.length; index++) {
      final codeUnit = text.codeUnitAt(index);
      if (!EmojiData.isEmojiCodepoint(codeUnit)) {
        buffer.write(text[index]);
        continue;
      }

      final emoji = EmojiData.findByCodepoint(codeUnit);
      if (emoji == null) {
        buffer.write(text[index]);
        continue;
      }

      flushText();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Image.asset(
            emoji.assetPath,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    flushText();

    return RichText(
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
