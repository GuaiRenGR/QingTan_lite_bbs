import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/emoji/emoji_data.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/music_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../../core/widgets/sensitive_media.dart';
import '../../music/music_player_controller.dart';
import '../chat_log_page.dart';
import 'forum_video_player.dart';
import '../chat_log_model.dart';

class ForumContentView extends StatelessWidget {
  final String content;
  final bool canViewHidden;
  final VoidCallback? onNeedReply;
  final List<String> sensitiveLabels;

  const ForumContentView({
    super.key,
    required this.content,
    this.canViewHidden = false,
    this.onNeedReply,
    this.sensitiveLabels = const [],
  });

  @override
  Widget build(BuildContext context) {
    final parts = _parse(content);
    final allImages = parts
        .where((p) => p.type == _ContentPartType.image)
        .map((p) => p.value)
        .toList();
    final children = _buildContentWidgets(context, parts, allImages);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<Widget> _buildContentWidgets(
    BuildContext context,
    List<_ContentPart> parts,
    List<String> allImages,
  ) {
    final widgets = <Widget>[];
    final inlineParts = <_ContentPart>[];

    void flushInlineParts() {
      if (inlineParts.isEmpty) return;
      widgets.add(_buildInlineParts(context, List.of(inlineParts)));
      inlineParts.clear();
    }

    for (final part in parts) {
      if (part.type == _ContentPartType.text ||
          part.type == _ContentPartType.link) {
        inlineParts.add(part);
        continue;
      }

      flushInlineParts();
      widgets.add(_buildPart(context, part, allImages));
    }

    flushInlineParts();
    return widgets;
  }

  Widget _buildPart(BuildContext context, _ContentPart part, List<String> allImages) {
    switch (part.type) {
      case _ContentPartType.text:
        return _buildInlineParts(context, [part]);

      case _ContentPartType.image:
        final imgIndex = allImages.indexOf(part.value);
        return SensitiveMedia(
          labels: sensitiveLabels,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 180),
            child: GestureDetector(
              onTap: () => ImageViewer.open(
                context,
                allImages,
                initialIndex: imgIndex >= 0 ? imgIndex : 0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SafeNetworkImage(
                  url: part.value,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );

      case _ContentPartType.video:
        return ForumVideoPlayer(url: part.value);

      case _ContentPartType.music:
        return _InlineMusicPlayer(
          url: part.value,
          lyricsUrl: part.extra,
          musicUuid: part.identifier,
        );

      case _ContentPartType.thread:
        return _InlineThreadCard(dvCode: part.value);

      case _ContentPartType.markdown:
        return MarkdownBody(
          data: part.value,
          selectable: true,
          onTapLink: (text, href, title) async {
            if (href == null || href.isEmpty) return;

            final uri = Uri.tryParse(href);
            if (uri == null) return;

            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          styleSheet: MarkdownStyleSheet(
            blockSpacing: 0,
            p: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: AppColors.text(context),
            ),
            code: TextStyle(
              backgroundColor: AppColors.inputFill(context),
              color: Colors.deepPurple,
              fontSize: 13,
            ),
            codeblockDecoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(10),
            ),
            blockquoteDecoration: BoxDecoration(
              color: AppColors.inputFill(context),
              border: Border(
                left: BorderSide(
                  color: Colors.grey.shade400,
                  width: 4,
                ),
              ),
            ),
          ),
        );

      case _ContentPartType.hidden:
        if (canViewHidden) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lock_open_rounded,
                      size: 16,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '隐藏内容（回复可见）',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ForumContentView(
                  content: part.value,
                  canViewHidden: true,
                  onNeedReply: onNeedReply,
                  sensitiveLabels: sensitiveLabels,
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: onNeedReply,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '回复后可见隐藏内容',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Text(
                  '去回复',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        );

      case _ContentPartType.link:
        return _buildInlineParts(context, [part]);

      case _ContentPartType.attachment:
        return _AttachmentCard(attachmentId: part.value);

      case _ContentPartType.chatlog:
        return _ChatLogCard(
          attachmentId: part.value,
          sensitiveLabels: sensitiveLabels,
        );
    }
  }

  Widget _buildInlineParts(
    BuildContext context,
    List<_ContentPart> parts,
  ) {
    final spans = <InlineSpan>[];

    for (final part in parts) {
      if (part.type == _ContentPartType.link) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(part.extra ?? '');
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                part.value,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  color: Color(0xFF1677FF),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
      } else {
        spans.addAll(_buildEmojiSpans(part.value));
      }
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 15,
          height: 1.65,
          color: AppColors.text(context),
        ),
        children: spans,
      ),
    );
  }

  List<InlineSpan> _buildEmojiSpans(String text) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();

    for (int index = 0; index < text.length; index++) {
      final codeUnit = text.codeUnitAt(index);
      if (!EmojiData.isEmojiCodepoint(codeUnit)) {
        buffer.write(text[index]);
        continue;
      }

      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString()));
        buffer.clear();
      }

      final emoji = EmojiData.findByCodepoint(codeUnit);
      if (emoji != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Image.asset(
              emoji.assetPath,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
        );
      }
    }

    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString()));
    }

    return spans;
  }

  List<_ContentPart> _parse(String input) {
    final List<_ContentPart> result = [];

    final reg = RegExp(
      r'(\[markdown\]([\s\S]*?)\[\/markdown\])'
      r'|(\[img=((?:https?:\/\/|\/)[^\]\s]+)\])'
      r'|(\[video=(https?:\/\/[^\]\s]+)\])'
      r'|(\[music=([^\]\s]+)\])'
      r'|(\[thread=([^\]\s]+)\])'
      r'|(\[hide\]([\s\S]*?)\[\/hide\])'
      r'|(\[url=(https?:\/\/[^\]\s]+)\]([\s\S]*?)\[\/url\])'
      r'|(\[attach=(\d+)\])'
      r'|(\[chatlog=(\d+)\])',
      caseSensitive: false,
    );

    int last = 0;

    final matches = reg.allMatches(input);

    for (final match in matches) {
      if (match.start > last) {
        final text = input.substring(last, match.start);
        if (text.isNotEmpty) {
          result.add(
            _ContentPart(
              type: _ContentPartType.text,
              value: text,
            ),
          );
        }
      }

      final markdown = match.group(2);
      final image = match.group(4);
      final video = match.group(6);
      final music = match.group(8);
      final thread = match.group(10);
      final hidden = match.group(12);
      final linkUrl = match.group(14);
      final linkText = match.group(15);
      final attachment = match.group(17);
      final chatlog = match.group(19);

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
            value: ApiClient.instance.resolveUrl(image.trim()),
          ),
        );
      } else if (video != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.video,
            value: video.trim(),
          ),
        );
      } else if (music != null) {
        final commaIndex = music.indexOf(',');
        final pipeIndex = music.indexOf('|');
        final separators = [commaIndex, pipeIndex].where((index) => index >= 0);
        final separatorIndex = separators.isEmpty
            ? -1
            : separators.reduce((left, right) => left < right ? left : right);
        final musicUrl = (separatorIndex < 0
                ? music
                : music.substring(0, separatorIndex))
            .trim();
        final lyricsUrl = separatorIndex < 0
            ? ''
            : music.substring(separatorIndex + 1).trim();
        final isUuid = RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          caseSensitive: false,
        ).hasMatch(musicUrl);
        result.add(
          _ContentPart(
            type: _ContentPartType.music,
            value: isUuid ? musicUrl.toLowerCase() : ApiClient.instance.resolveUrl(musicUrl),
            extra: lyricsUrl.isEmpty
                ? null
                : ApiClient.instance.resolveUrl(lyricsUrl),
            identifier: isUuid ? musicUrl.toLowerCase() : null,
          ),
        );
      } else if (thread != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.thread,
            value: thread.trim(),
          ),
        );
      } else if (hidden != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.hidden,
            value: hidden.trim(),
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
      } else if (attachment != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.attachment,
            value: attachment.trim(),
          ),
        );
      } else if (chatlog != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.chatlog,
            value: chatlog.trim(),
          ),
        );
      }

      last = match.end;
    }

    if (last < input.length) {
      final text = input.substring(last);
      if (text.isNotEmpty) {
        result.add(
          _ContentPart(
            type: _ContentPartType.text,
            value: text,
          ),
        );
      }
    }

    return result;
  }
}

enum _ContentPartType {
  text,
  image,
  video,
  music,
  thread,
  markdown,
  link,
  hidden,
  attachment,
  chatlog,
}

class _ContentPart {
  final _ContentPartType type;
  final String value;
  final String? extra;
  final String? identifier;

  const _ContentPart({
    required this.type,
    required this.value,
    this.extra,
    this.identifier,
  });
}

class _ChatLogCard extends StatefulWidget {
  final String attachmentId;
  final List<String> sensitiveLabels;

  const _ChatLogCard({
    required this.attachmentId,
    required this.sensitiveLabels,
  });

  @override
  State<_ChatLogCard> createState() => _ChatLogCardState();
}

class _ChatLogCardState extends State<_ChatLogCard> {
  late Future<ChatLogDocument> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ChatLogDocument> _load() async {
    final id = int.tryParse(widget.attachmentId) ?? 0;
    if (id <= 0) throw const FormatException('聊天记录附件无效');
    final apiBase = AppConfig.apiEntry.replaceAll('index.php', '');
    final url = '${apiBase}index.php?route=file/resolve&id=$id';
    final response = await ApiClient.instance.rawGet(url);
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw const FormatException('聊天记录文件读取失败');
    }
    final bytes = response.data ?? const <int>[];
    return ChatLogDocument.fromJsonString(utf8.decode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatLogDocument>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final document = snapshot.data;
        if (document == null) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('聊天记录加载失败'),
              subtitle: Text(snapshot.error?.toString() ?? '文件不可用'),
              trailing: IconButton(
                onPressed: () => setState(() => _future = _load()),
                icon: const Icon(Icons.refresh),
              ),
            ),
          );
        }
        return _CollapsedChatLogView(
          document: document,
          depth: 0,
          sensitiveLabels: widget.sensitiveLabels,
        );
      },
    );
  }
}

class _ChatLogView extends StatelessWidget {
  final ChatLogDocument document;
  final int depth;
  final List<String> sensitiveLabels;

  const _ChatLogView({
    required this.document,
    required this.depth,
    required this.sensitiveLabels,
  });

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1D2025)
        : const Color(0xFFF3F5F7);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  document.title.isEmpty ? '聊天记录' : document.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${document.messages.length} 条', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const Divider(height: 16),
          for (final message in document.messages)
            _ChatLogMessageView(
              message: message,
              depth: depth,
              sensitiveLabels: sensitiveLabels,
            ),
        ],
      ),
    );
  }
}

class _CollapsedChatLogView extends StatefulWidget {
  final ChatLogDocument document;
  final int depth;
  final List<String> sensitiveLabels;

  const _CollapsedChatLogView({
    required this.document,
    required this.depth,
    required this.sensitiveLabels,
  });

  @override
  State<_CollapsedChatLogView> createState() => _CollapsedChatLogViewState();
}

class _CollapsedChatLogViewState extends State<_CollapsedChatLogView> {
  bool _expanded = false;

  String _previewText(ChatLogMessage message) {
    switch (message.type) {
      case ChatLogMessageType.text:
        return message.content.trim();
      case ChatLogMessageType.image:
        return '[图片]';
      case ChatLogMessageType.quote:
        return '[引用]';
      case ChatLogMessageType.chatlog:
        return '[聊天记录]';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? const Color(0xFF61434F) : const Color(0xFFF2D8E2);
    final background = dark ? const Color(0xFF30252B) : const Color(0xFFFFF7FA);
    final secondary = dark ? const Color(0xFFD4BFC8) : const Color(0xFF987A86);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatLogPage(
            document: widget.document,
            sensitiveLabels: widget.sensitiveLabels,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: _expanded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChatLogView(
                    document: widget.document,
                    depth: widget.depth,
                    sensitiveLabels: widget.sensitiveLabels,
                  ),
                  Text('收起聊天记录', style: TextStyle(fontSize: 13, color: secondary)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(),
                  const SizedBox(height: 5),
                  for (final message in widget.document.messages.take(4))
                    Text(
                      '${message.nickname}: ${_previewText(message)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: secondary),
                    ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: border),
                  const SizedBox(height: 7),
                  Text(
                    '查看${widget.document.messages.length}条转发消息',
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _title() {
    return Text(
      widget.document.title.isEmpty ? '聊天记录' : widget.document.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _ChatLogMessageView extends StatelessWidget {
  final ChatLogMessage message;
  final int depth;
  final List<String> sensitiveLabels;

  const _ChatLogMessageView({
    required this.message,
    required this.depth,
    required this.sensitiveLabels,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isDark ? const Color(0xFF2A2F36) : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            child: Text(message.nickname.isEmpty ? '?' : message.nickname[0]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${message.nickname} · ${message.sender}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _messageBody(context),
                ),
                if (message.time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(message.time, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBody(BuildContext context) {
    switch (message.type) {
      case ChatLogMessageType.text:
        return Text(message.content);
      case ChatLogMessageType.image:
        return SensitiveMedia(
          labels: sensitiveLabels,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SafeNetworkImage(
              url: ApiClient.instance.resolveUrl(message.imageUrl),
              width: 220,
              fit: BoxFit.cover,
            ),
          ),
        );
      case ChatLogMessageType.quote:
        final quote = message.quote;
        return Container(
          padding: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.border(context), width: 3)),
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
        return _CollapsedChatLogView(
          document: nested,
          depth: depth + 1,
          sensitiveLabels: sensitiveLabels,
        );
    }
  }
}

class _InlineThreadCard extends StatefulWidget {
  final String dvCode;

  const _InlineThreadCard({required this.dvCode});

  @override
  State<_InlineThreadCard> createState() => _InlineThreadCardState();
}

class _InlineThreadCardState extends State<_InlineThreadCard> {
  late Future<Map<String, dynamic>?> _threadFuture;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _threadFuture = _loadThread();
  }

  @override
  void didUpdateWidget(covariant _InlineThreadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dvCode != widget.dvCode) {
      _errorMessage = '';
      _threadFuture = _loadThread();
    }
  }

  Future<Map<String, dynamic>?> _loadThread() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final result = await ApiClient.instance.get(
        'threads/embed',
        query: {'dv_code': widget.dvCode},
      );
      if (result.success && result.data is Map<String, dynamic>) {
        return result.data as Map<String, dynamic>;
      }

      _errorMessage = result.message;
      final retryable = result.code == null ||
          result.code == -1 ||
          (result.code != null && result.code! >= 500);
      if (!retryable || attempt == 2) break;
      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }

    return null;
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _errorMessage = '';
      _threadFuture = _loadThread();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _threadFuture,
      builder: (context, snapshot) {
        final thread = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final threadId = int.tryParse(thread?['id']?.toString() ?? '') ?? 0;
        final failed = !loading && thread == null;
        final title = thread?['title']?.toString() ??
            (failed && _errorMessage == '帖子不存在'
                ? '帖子不可用'
                : '加载失败，点击重试');
        final summary = thread?['summary']?.toString() ??
            (failed ? _errorMessage : '');
        final cover = thread?['cover']?.toString() ?? '';
        final author = thread?['author_name']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: threadId > 0
                ? () => context.push('/thread/$threadId')
                : failed
                    ? _retry
                    : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: loading
                  ? const SizedBox(
                      height: 48,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cover.isNotEmpty) ...[
                          SafeNetworkImage(
                            url: cover,
                            width: 82,
                            height: 62,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(width: 10),
                        ] else ...[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.inputFill(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.article_outlined),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (summary.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  summary,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 5),
                              Text(
                                author.isEmpty
                                    ? widget.dvCode
                                    : '$author · ${widget.dvCode}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (threadId > 0)
                          const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _InlineMusicPlayer extends ConsumerStatefulWidget {
  final String url;
  final String? lyricsUrl;
  final String? musicUuid;

  const _InlineMusicPlayer({required this.url, this.lyricsUrl, this.musicUuid});

  @override
  ConsumerState<_InlineMusicPlayer> createState() => _InlineMusicPlayerState();
}

class _InlineMusicPlayerState extends ConsumerState<_InlineMusicPlayer> {
  Uint8List? _coverArt;
  String _resolvedFilename = '';
  String _resolvedUrl = '';
  String? _resolvedLyricsUrl;
  String _artist = '';
  String? _coverUrl;

  MusicTrack get _track => MusicTrack(
        uuid: widget.musicUuid,
        url: _resolvedUrl,
        title: _filename,
        artist: _artist,
        coverArt: _coverArt,
        coverUrl: _coverUrl,
        lyricsUrl: _resolvedLyricsUrl,
      );

  String get _filename {
    if (_resolvedFilename.isNotEmpty) {
      final resolved = _resolvedFilename.trim();
      if (resolved.isNotEmpty && resolved.toLowerCase() != 'index') {
        return resolved;
      }
    }

    final uri = Uri.tryParse(widget.url);
    if (uri == null) return '音乐';
    final queryName = uri.queryParameters['filename'] ?? uri.queryParameters['name'];
    final name = queryName?.trim().isNotEmpty == true
        ? queryName!
        : uri.path.split('/').last;
    final filename = _withoutExtension(name);
    return filename.isNotEmpty && filename.toLowerCase() != 'index'
        ? filename
        : '音乐';
  }

  String _withoutExtension(String value) {
    String decoded;
    try {
      decoded = Uri.decodeComponent(value);
    } catch (_) {
      decoded = value;
    }

    final name = decoded.split('/').last.trim();
    if (name.isEmpty) return '';

    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  @override
  void initState() {
    super.initState();
    _resolveUrls();
    if (widget.musicUuid != null) {
      _loadLibraryMusic();
    } else {
      _syncTrack();
      _loadCachedMetadata();
    }
  }

  @override
  void didUpdateWidget(covariant _InlineMusicPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.lyricsUrl != widget.lyricsUrl || oldWidget.musicUuid != widget.musicUuid) {
      _coverArt = null;
      _resolvedFilename = '';
      _artist = '';
      _coverUrl = null;
      _resolveUrls();
      if (widget.musicUuid != null) {
        _loadLibraryMusic();
      } else {
        _syncTrack();
        _loadCachedMetadata();
      }
    }
  }

  void _resolveUrls() {
    _resolvedUrl = widget.musicUuid == null
        ? MusicCacheService.instance.resolveUrl(widget.url)
        : '';
    final lyricsUrl = widget.lyricsUrl?.trim() ?? '';
    _resolvedLyricsUrl = lyricsUrl.isEmpty
        ? null
        : MusicCacheService.instance.resolveUrl(lyricsUrl);
  }

  Future<void> _loadCachedMetadata() async {
    if (_resolvedUrl.isEmpty) return;
    final expectedUrl = _resolvedUrl;
    final metadata = await MusicCacheService.instance.loadMetadata(expectedUrl);
    if (!mounted || expectedUrl != _resolvedUrl) return;
    setState(() {
      _coverArt = metadata.coverArt;
      _resolvedFilename = metadata.title;
    });
    _syncTrack();
  }

  Future<void> _loadLibraryMusic() async {
    final uuid = widget.musicUuid;
    if (uuid == null) return;
    final result = await ApiClient.instance.get('music/detail', query: {'uuid': uuid});
    if (!mounted || uuid != widget.musicUuid || !result.success || result.data is! Map<String, dynamic>) return;
    final raw = (result.data as Map<String, dynamic>)['music'];
    if (raw is! Map) return;
    final item = Map<String, dynamic>.from(raw);
    final url = MusicCacheService.instance.resolveUrl(item['url']?.toString() ?? '');
    if (url.isEmpty) return;
    setState(() {
      _resolvedUrl = url;
      _resolvedLyricsUrl = item['lyrics_url']?.toString().trim().isEmpty == true
          ? null
          : MusicCacheService.instance.resolveUrl(item['lyrics_url']?.toString() ?? '');
      _resolvedFilename = item['title']?.toString().trim() ?? '';
      _artist = item['artist']?.toString().trim() ?? '';
      _coverUrl = item['cover_url']?.toString().trim().isEmpty == true
          ? null
          : ApiClient.instance.resolveUrl(item['cover_url']?.toString() ?? '');
    });
    _syncTrack();
    _loadCachedMetadata();
  }

  void _syncTrack() {
    if (_resolvedUrl.isEmpty) return;
    ref.read(musicPlayerProvider.notifier).upsertTrack(_track);
  }


  Future<void> _openPlayer() async {
    if (_resolvedUrl.isEmpty) return;
    await ref.read(musicPlayerProvider.notifier).selectTrack(_track);
    if (mounted) await context.push('/music-player');
  }

  Future<void> _togglePlayback() async {
    if (_resolvedUrl.isEmpty) return;
    await ref.read(musicPlayerProvider.notifier).toggleTrack(_track);
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = _coverArt != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final playerState = ref.watch(musicPlayerProvider);
    final isCurrent = playerState.currentTrack?.url == _resolvedUrl;
    final playing = isCurrent && playerState.playing;
    final loading = isCurrent && playerState.loading;
    final failed = isCurrent && playerState.error != null;
    final progress = isCurrent && playerState.duration.inMilliseconds > 0
        ? (playerState.position.inMilliseconds /
                playerState.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;
    final bufferedProgress = isCurrent && playerState.duration.inMilliseconds > 0
        ? (playerState.bufferedPosition.inMilliseconds /
                playerState.duration.inMilliseconds)
            .clamp(progress, 1.0)
        : 0.0;
    final accentColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            border: Border.all(
              color: isDark
                  ? theme.colorScheme.outlineVariant.withValues(alpha: 0.7)
                  : const Color(0xFFE2E2E2),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Row(
              children: [
                if (hasCover)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openPlayer,
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: Image.memory(
                        _coverArt!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                if (!hasCover && _coverUrl != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openPlayer,
                    child: SafeNetworkImage(
                      url: _coverUrl!,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      (hasCover || _coverUrl != null) ? 12 : 14,
                      8,
                      8,
                      7,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openPlayer,
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              _filename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Stack(
                                  children: [
                                    LinearProgressIndicator(
                                      value: bufferedProgress,
                                      minHeight: 4,
                                      color: accentColor.withValues(alpha: 0.35),
                                      backgroundColor: accentColor.withValues(
                                        alpha: isDark ? 0.25 : 0.12,
                                      ),
                                    ),
                                    LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      color: accentColor,
                                      backgroundColor: Colors.transparent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: loading
                                  ? Padding(
                                      padding: const EdgeInsets.all(7),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accentColor,
                                      ),
                                    )
                                  : IconButton(
                                      onPressed:
                                      failed || _resolvedUrl.isEmpty ? null : _togglePlayback,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      tooltip: playing ? '暂停' : '播放',
                                      icon: Icon(
                                        failed
                                            ? Icons.error_outline_rounded
                                            : playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                      ),
                                      color: failed
                                          ? theme.disabledColor
                                          : accentColor,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentCard extends StatefulWidget {
  final String attachmentId;

  const _AttachmentCard({required this.attachmentId});

  @override
  State<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<_AttachmentCard> {
  Map<String, dynamic>? _info;
  bool _loading = true;
  bool _failed = false;
  late final String _downloadUrl;

  @override
  void initState() {
    super.initState();
    final id = int.tryParse(widget.attachmentId) ?? 0;
    final apiBase = AppConfig.apiEntry.replaceAll('index.php', '');
    _downloadUrl = '${apiBase}index.php?route=file/resolve&id=$id';
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final id = int.tryParse(widget.attachmentId) ?? 0;
    if (id <= 0) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }

    try {
      final result = await ApiClient.instance.get(
        'upload/info',
        query: {'id': id},
      );

      if (!mounted) return;

      if (result.success && result.data is Map<String, dynamic>) {
        setState(() {
          _info = result.data as Map<String, dynamic>;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file_outlined;

    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('video/')) return Icons.video_file_outlined;
    if (mimeType.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('zip') ||
        mimeType.contains('rar') ||
        mimeType.contains('7z')) {
      return Icons.folder_zip_outlined;
    }
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description_outlined;
    }
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart_outlined;
    }
    if (mimeType.contains('powerpoint') ||
        mimeType.contains('presentation')) {
      return Icons.slideshow_outlined;
    }
    if (mimeType.contains('text')) return Icons.text_snippet_outlined;

    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.inputFill(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              '加载附件信息...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_failed || _info == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.inputFill(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              '附件加载失败',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final name = _info!['name']?.toString() ?? '未知文件';
    final size = _info!['size'] is int ? _info!['size'] as int : 0;
    final mimeType = _info!['type']?.toString();
    final url = _info!['url']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                if (!mounted) return;
                final useBuiltin = prefs.getBool('use_builtin_downloader') ?? true;
                if (useBuiltin) {
                  final name = _info?['name']?.toString() ?? 'file_${widget.attachmentId}';
                  final service = DownloadService.instance;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('开始下载: $name'),
                      action: SnackBarAction(
                        label: '查看下载',
                        onPressed: () => context.push('/downloads'),
                      ),
                    ),
                  );
                  service.download(
                    url: _downloadUrl,
                    fileName: name,
                    taskId: 'att_${widget.attachmentId}',
                  );
                } else {
                  final uri = Uri.tryParse(_downloadUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB7299).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getFileIcon(mimeType),
                    color: const Color(0xFFFB7299),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(size),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB7299),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '下载',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
