import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/emoji/emoji_data.dart';
import '../../../core/services/download_service.dart';
import '../../../core/theme/app_colors.dart';
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
          child: _buildTextWithEmoji(context, part.value),
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
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.65,
                      color: AppColors.text(context),
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
                color: AppColors.inputFill(context),
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

      case _ContentPartType.thread:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ThreadLinkCard(dvCode: part.value),
        );
    }
  }

  Widget _buildTextWithEmoji(BuildContext context, String text) {
    // Check if text contains any PUA emoji characters
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
          height: 1.65,
          color: AppColors.text(context),
        ),
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
              width: 22,
              height: 22,
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

  List<_ContentPart> _parse(String input) {
    final List<_ContentPart> result = [];

    final reg = RegExp(
      r'(\[markdown\]([\s\S]*?)\[\/markdown\])'
      r'|(\[img=(https?:\/\/[^\]\s]+)\])'
      r'|(\[video=(https?:\/\/[^\]\s]+)\])'
      r'|(\[music=(https?:\/\/[^\]\s]+)\])'
      r'|(\[hide\]([\s\S]*?)\[\/hide\])'
      r'|(\[url=(https?:\/\/[^\]\s]+)\]([\s\S]*?)\[\/url\])'
      r'|(\[attach=(\d+)\])'
      r'|(\[thread=([A-Za-z0-9]+)\])',
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
      final threadDv = match.group(18);

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
      } else if (threadDv != null) {
        result.add(
          _ContentPart(
            type: _ContentPartType.thread,
            value: threadDv.trim(),
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
  thread,
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
            color: AppColors.inputFill(context),
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
  double _downloadProgress = -1;
  DownloadTask? _task;

  @override
  void initState() {
    super.initState();
    final id = int.tryParse(widget.attachmentId) ?? 0;
    final apiBase = AppConfig.apiEntry.replaceAll('index.php', '');
    _downloadUrl = '${apiBase}index.php?route=file/resolve&id=$id';
    _loadInfo();
  }

  @override
  void dispose() {
    _task?.progressStream.listen(null).cancel();
    super.dispose();
  }

  Future<bool> _isBuiltinDownloaderEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('use_builtin_downloader') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _handleTap() async {
    final useBuiltin = await _isBuiltinDownloaderEnabled();
    if (!useBuiltin) {
      final uri = Uri.tryParse(_downloadUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    await _startDownload();
  }

  Future<void> _startDownload() async {
    final name = _info?['name']?.toString() ?? 'file_${widget.attachmentId}';
    final service = DownloadService.instance;

    final hasPermission = await service.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要存储权限才能下载文件')),
        );
      }
      return;
    }

    setState(() => _downloadProgress = 0);

    final task = await service.download(
      url: _downloadUrl,
      fileName: name,
      taskId: 'att_${widget.attachmentId}',
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );

    _task = task;

    if (mounted) {
      if (task.status == DownloadStatus.completed) {
        setState(() => _downloadProgress = 1.0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载完成: $name'),
            action: SnackBarAction(
              label: '打开',
              onPressed: () => service.openFile(task.id),
            ),
          ),
        );
      } else if (task.status == DownloadStatus.failed) {
        setState(() => _downloadProgress = -1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: ${task.error ?? "未知错误"}')),
        );
      }
    }
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
          mainAxisSize: MainAxisSize.min,
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
          onTap: _downloadProgress >= 0 && _downloadProgress < 1
              ? null
              : _downloadProgress >= 1
                  ? () => DownloadService.instance
                      .openFile('att_${widget.attachmentId}')
                  : _handleTap,
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
                      if (_downloadProgress >= 0 && _downloadProgress < 1)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _downloadProgress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            color: const Color(0xFFFB7299),
                          ),
                        )
                      else
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
                    color: _downloadProgress >= 1
                        ? Colors.green
                        : const Color(0xFFFB7299),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _downloadProgress >= 1
                            ? Icons.open_in_new_rounded
                            : _downloadProgress >= 0
                                ? Icons.downloading_rounded
                                : Icons.download_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _downloadProgress >= 1
                            ? '打开'
                            : _downloadProgress >= 0
                                ? '${(_downloadProgress * 100).toInt()}%'
                                : '下载',
                        style: const TextStyle(
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

/// 帖子链接卡片 — 通过 DV 号获取帖子信息并渲染为横向卡片
class _ThreadLinkCard extends StatefulWidget {
  final String dvCode;

  const _ThreadLinkCard({required this.dvCode});

  @override
  State<_ThreadLinkCard> createState() => _ThreadLinkCardState();
}

class _ThreadLinkCardState extends State<_ThreadLinkCard> {
  Map<String, dynamic>? _thread;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  Future<void> _loadThread() async {
    try {
      final result = await ApiClient.instance.get(
        'threads/detail-by-dv',
        query: {'dv_code': widget.dvCode},
      );

      if (!mounted) return;

      if (result.success && result.data is Map<String, dynamic>) {
        final data = result.data as Map<String, dynamic>;
        final thread = data['thread'];
        if (thread is Map<String, dynamic>) {
          setState(() {
            _thread = thread;
            _loading = false;
          });
          return;
        }
      }
      setState(() {
        _loading = false;
        _failed = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.inputFill(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              '加载帖子 ${widget.dvCode}...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (_failed || _thread == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.inputFill(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Text(
              '帖子 ${widget.dvCode}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    final title = _thread!['title']?.toString() ?? '无标题';
    final cover = _thread!['cover']?.toString() ?? '';
    final summary = _thread!['summary']?.toString() ?? '';
    final threadId = (_thread!['id'] as int?) ?? 0;

    return GestureDetector(
      onTap: threadId > 0
          ? () => context.push('/thread/$threadId')
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inputFill(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cover.isNotEmpty)
              SafeNetworkImage(
                url: cover,
                width: 100,
                height: 80,
                fit: BoxFit.cover,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.dvCode,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
