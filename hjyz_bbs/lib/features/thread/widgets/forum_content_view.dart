import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/safe_network_image.dart';

class ForumContentView extends StatelessWidget {
  final String content;

  const ForumContentView({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final parts = _parse(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in parts) _buildPart(context, part),
      ],
    );
  }

  Widget _buildPart(BuildContext context, _ContentPart part) {
    switch (part.type) {
      case _ContentPartType.text:
        if (part.value.trim().isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            part.value,
            style: const TextStyle(
              fontSize: 15,
              height: 1.65,
              color: Color(0xFF222222),
            ),
          ),
        );

      case _ContentPartType.image:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SafeNetworkImage(
              url: part.value,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        );

      case _ContentPartType.markdown:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MarkdownBody(
            data: part.value,
            selectable: true,
            onTapLink: (text, href, title) async {
              if (href == null || href.isEmpty) return;

              final uri = Uri.tryParse(href);
              if (uri == null) return;

              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 15,
                height: 1.65,
                color: Color(0xFF222222),
              ),
              code: TextStyle(
                backgroundColor: Colors.grey.shade100,
                color: Colors.deepPurple,
                fontSize: 13,
              ),
              codeblockDecoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              blockquoteDecoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  left: BorderSide(
                    color: Colors.grey.shade400,
                    width: 4,
                  ),
                ),
              ),
            ),
          ),
        );

      case _ContentPartType.link:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () async {
              final url = part.extra ?? '';
              final uri = Uri.tryParse(url);

              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              part.value,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF1677FF),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        );
    }
  }

  List<_ContentPart> _parse(String input) {
    final List<_ContentPart> result = [];

    final reg = RegExp(
      r'(\[markdown\]([\s\S]*?)\[\/markdown\])|(\[img=(https?:\/\/[^\]\s]+)\])|(\[url=(https?:\/\/[^\]\s]+)\]([\s\S]*?)\[\/url\])',
      caseSensitive: false,
    );

    int last = 0;

    final matches = reg.allMatches(input);

    for (final match in matches) {
      if (match.start > last) {
        result.add(
          _ContentPart(
            type: _ContentPartType.text,
            value: input.substring(last, match.start),
          ),
        );
      }

      final markdown = match.group(2);
      final image = match.group(4);
      final linkUrl = match.group(6);
      final linkText = match.group(7);

      if (markdown != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.markdown,
            value: markdown.trim(),
          ),
        );
      } else if (image != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.image,
            value: image.trim(),
          ),
        );
      } else if (linkUrl != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.link,
            value: linkText?.trim().isNotEmpty == true
                ? linkText!.trim()
                : linkUrl.trim(),
            extra: linkUrl.trim(),
          ),
        );
      }

      last = match.end;
    }

    if (last < input.length) {
      result.add(
        _ContentPart(
          type: _ContentPartType.text,
          value: input.substring(last),
        ),
      );
    }

    return result;
  }
}

enum _ContentPartType {
  text,
  image,
  markdown,
  link,
}

class _ContentPart {
  final _ContentPartType type;
  final String value;
  final String? extra;

  const _ContentPart({
    required this.type,
    required this.value,
    this.extra,
  });
}
