import 'package:flutter/material.dart';

import 'safe_network_image.dart';

class BbcodeEditorController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final children = <InlineSpan>[];
    final imgReg = RegExp(r'\[img=(https?:\/\/[^\]\s]+)\]', caseSensitive: false);
    int last = 0;

    for (final m in imgReg.allMatches(text)) {
      if (m.start > last) {
        children.add(TextSpan(text: text.substring(last, m.start), style: style));
      }

      final url = m.group(1)!;
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120, minHeight: 60),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeNetworkImage(
              url: url,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );

      last = m.end;
    }

    if (last < text.length) {
      children.add(TextSpan(text: text.substring(last), style: style));
    }

    return TextSpan(style: style, children: children);
  }
}
