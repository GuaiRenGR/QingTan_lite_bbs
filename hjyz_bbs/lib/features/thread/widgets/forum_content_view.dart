import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/safe_network_image.dart';
import 'forum_video_player.dart';

class ForumContentView extends StatelessWidget {
  final String content;
  final bool canViewHidden;
  final VoidCallback? onNeedReply;

  const ForumContentView({
    super.key,
    required this.content,
    this.canViewHidden = false,
    this.onNeedReply,
  });

  @override
  Widget build(BuildContext context) {
    final parts = _parse(content);
    final allImages = parts
        .where((p) => p.type == _ContentPartType.image)
        .map((p) => p.value)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in parts) _buildPart(context, part, allImages),
      ],
    );
  }

  Widget _buildPart(BuildContext context, _ContentPart part, List<String> allImages) {
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
        final imgIndex = allImages.indexOf(part.value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
        );

      case _ContentPartType.video:
        return ForumVideoPlayer(url: part.value);

      case _ContentPartType.music:
        return _InlineMusicPlayer(url: part.value);

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

      case _ContentPartType.hidden:
        if (canViewHidden) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
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
                      Icon(Icons.lock_open_rounded, size: 16, color: Colors.amber.shade700),
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
                  Text(
                    part.value,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.65,
                      color: Color(0xFF222222),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: onNeedReply,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey.shade600),
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

      case _ContentPartType.attachment:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AttachmentCard(attachmentId: part.value),
        );
    }
  }

  List<_ContentPart> _parse(String input) {
    final List<_ContentPart> result = [];

    final reg = RegExp(
      r'(\[markdown\]([\s\S]*?)\[\/markdown\])'
      r'|(\[img=(https?:\/\/[^\]\s]+)\])'
      r'|(\[video=(https?:\/\/[^\]\s]+)\])'
      r'|(\[music=(https?:\/\/[^\]\s]+)\])'
      r'|(\[hide\]([\s\S]*?)\[\/hide\])'
      r'|(\[url=(https?:\/\/[^\]\s]+)\]([\s\S]*?)\[\/url\])'
      r'|(\[attach=(\d+)\])',
      caseSensitive: false,
    );

    int last = 0;

    final matches = reg.allMatches(input);

    for (final match in matches) {
      if (match.start > last) {
        final text = input.substring(last, match.start);
        if (text.trim().isNotEmpty) {
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
      final hidden = match.group(10);
      final linkUrl = match.group(12);
      final linkText = match.group(13);
      final attachment = match.group(15);

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
      } else if (video != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.video,
            value: video.trim(),
          ),
        );
      } else if (music != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.music,
            value: music.trim(),
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
      }

      last = match.end;
    }

    if (last < input.length) {
      final text = input.substring(last);
      if (text.trim().isNotEmpty) {
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
  markdown,
  link,
  hidden,
  attachment,
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

class _InlineMusicPlayer extends StatefulWidget {
  final String url;

  const _InlineMusicPlayer({required this.url});

  @override
  State<_InlineMusicPlayer> createState() => _InlineMusicPlayerState();
}

class _InlineMusicPlayerState extends State<_InlineMusicPlayer> {
  late final AudioPlayer _player;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.url);
      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _playing = state.playing;
        });
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _failed
            ? null
            : () async {
                if (_playing) {
                  await _player.pause();
                } else {
                  await _player.play();
                }
              },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                _failed
                    ? Icons.error_outline_rounded
                    : _playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                color: _failed
                    ? Colors.grey
                    : const Color(0xFFFB7299),
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _failed ? '音乐加载失败' : '背景音乐',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
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
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
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
                final uri = Uri.tryParse(_downloadUrl);
                if (uri != null) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
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
