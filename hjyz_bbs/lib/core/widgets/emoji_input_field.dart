import 'package:flutter/material.dart';

import '../emoji/emoji_data.dart';

/// 支持 PUA 表情渲染的输入框
class EmojiInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int minLines;
  final int maxLines;
  final String? hintText;
  final VoidCallback? onTap;
  final InputDecoration? decoration;

  const EmojiInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.minLines = 1,
    this.maxLines = 3,
    this.hintText,
    this.onTap,
    this.decoration,
  });

  @override
  State<EmojiInputField> createState() => _EmojiInputFieldState();
}

class _EmojiInputFieldState extends State<EmojiInputField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;

    return Stack(
      children: [
        // 底层：TextField，文字设为透明（保留光标和选择功能）
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          onTap: widget.onTap,
          style: const TextStyle(color: Colors.transparent),
          cursorColor: Theme.of(context).colorScheme.primary,
          decoration: widget.decoration ??
              InputDecoration(
                hintText: widget.hintText,
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
        ),
        // 上层：RichText 渲染表情（不接收触摸事件）
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 9,
              ),
              child: _buildRichText(context, text),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRichText(BuildContext context, String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    bool hasEmoji = false;
    for (int i = 0; i < text.length; i++) {
      if (EmojiData.isEmojiCodepoint(text.codeUnitAt(i))) {
        hasEmoji = true;
        break;
      }
    }

    if (!hasEmoji) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <InlineSpan>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if (EmojiData.isEmojiCodepoint(codeUnit)) {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(text: buffer.toString()));
          buffer.clear();
        }
        final emoji = EmojiData.findByCodepoint(codeUnit);
        if (emoji != null) {
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Image.asset(
              emoji.assetPath,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
          ));
        }
      } else {
        buffer.write(text[i]);
      }
    }

    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString()));
    }

    return RichText(
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: spans,
      ),
    );
  }
}
