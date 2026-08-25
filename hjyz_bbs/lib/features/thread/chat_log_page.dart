import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/safe_network_image.dart';
import '../../core/widgets/sensitive_media.dart';
import 'chat_log_model.dart';

class ChatLogPage extends StatelessWidget {
  final ChatLogDocument document;
  final List<String> sensitiveLabels;

  const ChatLogPage({
    super.key,
    required this.document,
    this.sensitiveLabels = const [],
  });

  @override
  Widget build(BuildContext context) {
    final firstSender = document.messages
        .map((message) => message.sender)
        .firstWhere((sender) => sender.isNotEmpty, orElse: () => '');
    return Scaffold(
      backgroundColor: _background(context),
      appBar: AppBar(
        title: Text(document.title.isEmpty ? '聊天记录' : document.title),
        centerTitle: true,
        backgroundColor: _background(context),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        itemCount: document.messages.length,
        itemBuilder: (context, index) {
          final message = document.messages[index];
          return _ChatLogBubble(
            message: message,
            isRight: firstSender.isNotEmpty && message.sender != firstSender,
            depth: 0,
            sensitiveLabels: sensitiveLabels,
          );
        },
      ),
    );
  }

  Color _background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF17191C)
        : const Color(0xFFEFF1F4);
  }
}

class _ChatLogBubble extends StatelessWidget {
  final ChatLogMessage message;
  final bool isRight;
  final int depth;
  final List<String> sensitiveLabels;

  const _ChatLogBubble({
    required this.message,
    required this.isRight,
    required this.depth,
    required this.sensitiveLabels,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isRight
        ? (dark ? const Color(0xFF315E46) : const Color(0xFFB7E9C7))
        : (dark ? const Color(0xFF2A2D32) : Colors.white);
    final alignment = isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (message.time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message.time,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 11,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isRight) _avatar(context),
              if (!isRight) const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: alignment,
                  children: [
                    Text(
                      message.nickname.isEmpty
                          ? message.sender
                          : message.nickname,
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 310),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _body(context),
                    ),
                  ],
                ),
              ),
              if (isRight) const SizedBox(width: 8),
              if (isRight) _avatar(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final label = message.nickname.trim().isEmpty
        ? '?'
        : message.nickname.trim().characters.first;
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(label),
    );
  }

  Widget _body(BuildContext context) {
    switch (message.type) {
      case ChatLogMessageType.text:
        return Text(message.content);
      case ChatLogMessageType.image:
        return SensitiveMedia(
          labels: sensitiveLabels,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SafeNetworkImage(
              url: ApiClient.instance.resolveUrl(message.imageUrl),
              width: 230,
              fit: BoxFit.cover,
            ),
          ),
        );
      case ChatLogMessageType.quote:
        final quote = message.quote;
        return Container(
          padding: const EdgeInsets.only(left: 9),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppColors.textSecondary(context),
                width: 3,
              ),
            ),
          ),
          child: Text(
            quote == null
                ? message.content
                : '${quote.nickname} · ${quote.sender}\n${quote.content}',
          ),
        );
      case ChatLogMessageType.chatlog:
        final nested = message.chatlog;
        if (nested == null || depth >= chatLogMaxDepth) {
          return const Text('嵌套聊天记录不可用');
        }
        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatLogPage(
                document: nested,
                sensitiveLabels: sensitiveLabels,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.forum_outlined, size: 20),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    nested.title.isEmpty ? '聊天记录' : nested.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                Text('${nested.messages.length}条'),
              ],
            ),
          ),
        );
    }
  }
}
