import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/services/music_cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/bbcode_editor_controller.dart';
import '../../core/widgets/safe_network_image.dart';
import '../../core/widgets/sensitive_media.dart';
import '../auth/auth_controller.dart';
import 'widgets/forum_content_view.dart';

class CreateThreadPage extends ConsumerStatefulWidget {
  final int forumId;
  final int? editThreadId;

  const CreateThreadPage({
    super.key,
    this.forumId = 0,
    this.editThreadId,
  });

  bool get isEdit => editThreadId != null && editThreadId! > 0;

  @override
  ConsumerState<CreateThreadPage> createState() => _CreateThreadPageState();
}

class _CreateThreadPageState extends ConsumerState<CreateThreadPage> {
  final titleController = TextEditingController();
  final contentController = BbcodeEditorController();

  final imagePicker = ImagePicker();

  String mode = 'article';

  bool publishing = false;
  bool uploadingImage = false;
  bool uploadingMusic = false;
  bool uploadingVideo = false;
  bool uploadingAttachment = false;

  final List<String> imageUrls = [];
  final List<int> attachmentIds = [];
  final List<String> sensitiveLabels = [];

  int selectedForumId = 0;

  final List<Map<String, dynamic>> forums = [];
  final List<String> tags = [];

  final tagController = TextEditingController();

  Timer? draftTimer;

  String get _draftKey => 'create_thread_draft_forum_${widget.forumId}';

  bool get _isAdmin {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return false;
    return _toInt(user['group_id']) == 99;
  }

  @override
  void initState() {
    super.initState();

    selectedForumId = widget.forumId;

    _loadForums();

    if (widget.isEdit) {
      _loadEditThread();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkDraft();
      });
    }

    titleController.addListener(_scheduleAutoSaveDraft);
    contentController.addListener(_scheduleAutoSaveDraft);
  }

  @override
  void dispose() {
    draftTimer?.cancel();
    titleController.dispose();
    contentController.dispose();
    tagController.dispose();
    super.dispose();
  }

  // Draft methods

  void _scheduleAutoSaveDraft() {
    draftTimer?.cancel();

    draftTimer = Timer(const Duration(seconds: 2), () {
      _saveDraft(showToast: false);
    });
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);

    if (raw == null || raw.isEmpty) return;
    if (!mounted) return;

    final restore = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('发现本地草稿'),
          content: const Text('是否恢复上次未发布的内容？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('不要'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('恢复'),
            ),
          ],
        );
      },
    );

    if (restore == true) {
      await _loadDraft();
    }
  }

  Future<void> _saveDraft({
    bool showToast = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'title': titleController.text,
      'content': contentController.text,
      'mode': mode,
      'image_urls': imageUrls,
      'attachment_ids': attachmentIds,
      'sensitive_labels': sensitiveLabels,
      'saved_at': DateTime.now().toIso8601String(),
    };

    await prefs.setString(
      _draftKey,
      jsonEncode(data),
    );

    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('草稿已保存')),
      );
    }
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);

    if (raw == null || raw.isEmpty) return;

    final decoded = jsonDecode(raw);

    if (decoded is! Map) return;

    setState(() {
      titleController.text = decoded['title']?.toString() ?? '';
      contentController.text = decoded['content']?.toString() ?? '';
      mode = decoded['mode']?.toString() == 'image' ? 'image' : 'article';

      imageUrls
        ..clear()
        ..addAll(
          decoded['image_urls'] is List
              ? (decoded['image_urls'] as List).map((e) => e.toString())
              : [],
        );

      attachmentIds
        ..clear()
        ..addAll(
          decoded['attachment_ids'] is List
              ? (decoded['attachment_ids'] as List)
                  .map((e) => int.tryParse(e.toString()) ?? 0)
                  .where((e) => e > 0)
              : [],
        );

      sensitiveLabels
        ..clear()
        ..addAll(parseSensitiveLabels(decoded['sensitive_labels']));

    });
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  // Forums

  Future<void> _loadForums() async {
    final result = await ApiClient.instance.get('forums/list');

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final raw = data['list'];

      final loaded = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      setState(() {
        forums
          ..clear()
          ..addAll(loaded);

        if (selectedForumId <= 0 && forums.isNotEmpty) {
          final defaultForum = forums.cast<Map<String, dynamic>?>().firstWhere(
                (e) => e?['is_default'] == true,
                orElse: () => forums.first,
              );

          selectedForumId =
              int.tryParse(defaultForum?['id']?.toString() ?? '') ?? 1;
        }
      });
    }
  }

  // Edit mode

  Future<void> _loadEditThread() async {
    final result = await ApiClient.instance.get(
      'threads/detail',
      query: {
        'id': widget.editThreadId,
      },
    );

    if (!mounted) return;

    if (!result.success || result.data is! Map<String, dynamic>) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    final data = result.data as Map<String, dynamic>;
    final thread = data['thread'] is Map<String, dynamic>
        ? data['thread'] as Map<String, dynamic>
        : data;

    setState(() {
      titleController.text = thread['title']?.toString() ?? '';
      contentController.text = thread['content']?.toString() ?? '';
      mode = thread['mode']?.toString() == 'image' ? 'image' : 'article';
      selectedForumId = int.tryParse(thread['forum_id']?.toString() ?? '') ?? 0;

      final allImages = thread['images'] is List
          ? (thread['images'] as List).map((e) => e.toString()).toList()
          : <String>[];

      imageUrls
        ..clear()
        ..addAll(allImages.where((url) => _isLocalUpload(url)));

      tags
        ..clear()
        ..addAll(
          thread['tags'] is List
              ? (thread['tags'] as List)
                  .whereType<Map>()
                  .map((e) => e['name']?.toString() ?? '')
                  .where((e) => e.isNotEmpty)
              : [],
        );

      sensitiveLabels
        ..clear()
        ..addAll(parseSensitiveLabels(thread['sensitive_labels']));
    });
  }

  // Tags

  void _addTag() {
    final value = tagController.text.trim().replaceAll(RegExp(r'\s+'), '');

    if (value.isEmpty) return;

    if (tags.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多添加 5 个标签')),
      );
      return;
    }

    if (tags.contains(value)) {
      tagController.clear();
      return;
    }

    setState(() {
      tags.add(value);
      tagController.clear();
    });
  }

  // Remote images

  List<String> _extractRemoteImagesFromContent(String content) {
    final reg = RegExp(
      r'\[img=(https?:\/\/[^\]\s]+)\]',
      caseSensitive: false,
    );

    return reg
        .allMatches(content)
        .map((e) => e.group(1)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  // Upload methods

  Future<void> _pickAndUploadImages() async {
    if (uploadingImage) return;

    final files = await imagePicker.pickMultiImage(
      imageQuality: 90,
    );

    if (files.isEmpty) return;

    setState(() {
      uploadingImage = true;
    });

    try {
      for (final xfile in files) {
        final result = await ApiClient.instance.uploadFile(
          'upload/media',
          file: File(xfile.path),
          fields: {
            'type': 'image',
          },
        );

        if (!mounted) return;

        if (!result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)),
          );
          continue;
        }

        final data = result.data;

        if (data is Map<String, dynamic>) {
          final url = ApiClient.instance.resolveUrl(
            data['url']?.toString() ?? '',
          );
          final id = _toInt(data['id']);

          if (url.isNotEmpty) {
            imageUrls.add(url);

            if (id > 0) {
              attachmentIds.add(id);
            }

            if (mode == 'article') {
              final old = contentController.text;
              final insert = '\n[img=$url]\n';

              contentController.text = old + insert;
              contentController.selection = TextSelection.fromPosition(
                TextPosition(offset: contentController.text.length),
              );
            }
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          uploadingImage = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadMusic() async {
    if (uploadingMusic) return;

    File? musicFile;
    File? lyricsFile;
    String musicName = '';
    String lyricsName = '';
    MusicMetadata? musicMetadata;
    final songTitleController = TextEditingController();
    final artistController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickMusic() async {
              final picked = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: [
                  'mp3',
                  'm4a',
                  'aac',
                  'wav',
                  'ogg',
                  'flac',
                ],
                allowMultiple: false,
              );
              final file = picked == null || picked.files.isEmpty
                  ? null
                  : picked.files.single;
              if (file?.path == null || !dialogContext.mounted) return;
              final metadata = await MusicCacheService.instance.readLocalMetadata(
                File(file!.path!),
                fallbackTitle: file.name,
              );
              if (!dialogContext.mounted) return;
              setDialogState(() {
                musicFile = File(file!.path!);
                musicName = file.name;
                musicMetadata = metadata;
                songTitleController.text = metadata.title;
                artistController.text = metadata.artist;
              });
            }

            Future<void> pickLyrics() async {
              final picked = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['lrc'],
                allowMultiple: false,
              );
              final file = picked == null || picked.files.isEmpty
                  ? null
                  : picked.files.single;
              if (file?.path == null || !dialogContext.mounted) return;
              setDialogState(() {
                lyricsFile = File(file!.path!);
                lyricsName = file.name;
              });
            }

            return AlertDialog(
              title: const Text('上传音乐'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.audio_file_rounded),
                      title: const Text('音乐文件'),
                      subtitle: Text(musicName.isEmpty ? '请选择音乐文件' : musicName),
                      trailing: OutlinedButton(
                        onPressed: pickMusic,
                        child: const Text('选择'),
                      ),
                    ),
                    TextField(
                      controller: songTitleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: '歌曲名'),
                    ),
                    TextField(
                      controller: artistController,
                      decoration: const InputDecoration(labelText: '歌手名（可选）'),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lyrics_outlined),
                      title: const Text('歌词文件（可选）'),
                      subtitle: Text(lyricsName.isEmpty ? '支持任意名称的 LRC 文件' : lyricsName),
                      trailing: OutlinedButton(
                        onPressed: pickLyrics,
                        child: const Text('选择'),
                      ),
                    ),
                    if (lyricsFile != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setDialogState(() {
                            lyricsFile = null;
                            lyricsName = '';
                          }),
                          child: const Text('移除歌词'),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: musicFile == null
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('开始上传'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || musicFile == null) {
      songTitleController.dispose();
      artistController.dispose();
      return;
    }

    setState(() {
      uploadingMusic = true;
    });

    try {
      String lyricsUrl = '';
      String coverUrl = '';
      if (lyricsFile != null) {
        final lyricsResult = await ApiClient.instance.uploadFile(
          'upload/media',
          file: lyricsFile!,
          fields: {'type': 'lyrics'},
        );
        if (!mounted) return;
        if (!lyricsResult.success || lyricsResult.data is! Map<String, dynamic>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lyricsResult.message)),
          );
          return;
        }
        final lyricsData = lyricsResult.data as Map<String, dynamic>;
        lyricsUrl = ApiClient.instance.resolveUrl(
          lyricsData['url']?.toString() ?? '',
        );
      }

      final cover = musicMetadata?.coverArt;
      if (cover != null && cover.isNotEmpty) {
        final coverFile = File(
          '${Directory.systemTemp.path}/hjyz_music_cover_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        try {
          await coverFile.writeAsBytes(cover, flush: true);
          final coverResult = await ApiClient.instance.uploadFile(
            'upload/media',
            file: coverFile,
            fields: {'type': 'image'},
          );
          if (coverResult.success && coverResult.data is Map<String, dynamic>) {
            coverUrl = ApiClient.instance.resolveUrl(
              (coverResult.data as Map<String, dynamic>)['url']?.toString() ?? '',
            );
          }
        } finally {
          if (await coverFile.exists()) await coverFile.delete();
        }
      }

      final result = await ApiClient.instance.uploadFile(
        'upload/media',
        file: musicFile!,
        fields: {
          'type': 'music',
          'lyrics_url': lyricsUrl,
          'cover_url': coverUrl,
          'title': songTitleController.text.trim(),
          'artist': artistController.text.trim(),
        },
      );

      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        return;
      }

      final data = result.data;

      if (data is Map<String, dynamic>) {
        final uuid = data['music_uuid']?.toString().trim() ?? '';
        if (uuid.isNotEmpty) {
          final old = contentController.text;
          final insert = '\n[music=$uuid]\n';

          contentController.text = old + insert;
          contentController.selection = TextSelection.fromPosition(
            TextPosition(offset: contentController.text.length),
          );
        }
      }
    } finally {
      songTitleController.dispose();
      artistController.dispose();
      if (mounted) {
        setState(() {
          uploadingMusic = false;
        });
      }
    }
  }

  Future<void> _pickExistingMusic() async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _MusicPickerDialog(),
    );
    final uuid = selected?['uuid']?.toString().trim() ?? '';
    if (uuid.isEmpty || !mounted) return;
    contentController.text = '${contentController.text}\n[music=$uuid]\n';
    contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: contentController.text.length),
    );
  }

  // Insert methods

  Future<void> _pickAndUploadAttachment() async {
    if (uploadingAttachment) return;

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
    );

    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final path = file.path;

    if (path == null || path.isEmpty) return;

    setState(() {
      uploadingAttachment = true;
    });

    try {
      final result = await ApiClient.instance.uploadFile(
        'upload/media',
        file: File(path),
        fields: {
          'type': 'attachment',
        },
      );

      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        return;
      }

      final data = result.data;

      if (data is Map<String, dynamic>) {
        final id = _toInt(data['id']);

        if (id > 0) {
          final old = contentController.text;
          final insert = '\n[attach=$id]\n';

          contentController.text = old + insert;
          contentController.selection = TextSelection.fromPosition(
            TextPosition(offset: contentController.text.length),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('附件上传成功，ID: $id')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('附件上传返回ID异常: id=$id, data=$data')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('附件响应格式异常: ${result.data?.runtimeType}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          uploadingAttachment = false;
        });
      }
    }
  }

  void _insertMarkdownBlock() {
    final selection = contentController.selection;
    final text = contentController.text;

    const template =
        '[markdown]\n# 标题\n\n这里写 Markdown 内容\n\n```dart\nprint("hello");\n```\n[/markdown]';

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    final newText = text.replaceRange(start, end, template);

    contentController.text = newText;
    contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: start + template.length),
    );
  }

  void _insertHideBlock() {
    final selection = contentController.selection;
    final text = contentController.text;

    const template = '[hide]\n回复后可见的内容\n[/hide]';

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    final newText = text.replaceRange(start, end, template);

    contentController.text = newText;
    contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: start + template.length),
    );
  }

  Future<void> _insertThreadLink() async {
    final dvController = TextEditingController();
    var selectedTitle = '';

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('插入帖子链接'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: dvController,
                    decoration: const InputDecoration(
                      labelText: 'DV 号',
                      hintText: '例如 DV3k7M2x9P',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showModalBottomSheet<_ThreadSelection>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (_) => const _ThreadPickerSheet(),
                      );
                      if (selected == null) return;
                      dvController.text = selected.dvCode;
                      setDialogState(() => selectedTitle = selected.title);
                    },
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('选择帖子'),
                  ),
                  if (selectedTitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '已选择：$selectedTitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(dvController.text.trim());
              },
              child: const Text('插入'),
            ),
          ],
        );
      },
    );

    dvController.dispose();
    if (result == null || result.isEmpty) return;

    final tag = '[thread=$result]';

    final selection = contentController.selection;
    final oldText = contentController.text;
    final start = selection.start < 0 ? oldText.length : selection.start;
    final end = selection.end < 0 ? oldText.length : selection.end;

    final newText = oldText.replaceRange(start, end, tag);
    contentController.text = newText;
    contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: start + tag.length),
    );
  }

  Future<void> _insertUrlTag() async {
    final urlController = TextEditingController();
    final textController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('插入链接'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: '链接',
                  hintText: 'https://example.com',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: '显示文字',
                  hintText: '点击查看',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'url': urlController.text.trim(),
                  'text': textController.text.trim(),
                });
              },
              child: const Text('插入'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final url = result['url'] ?? '';
    final text = result['text']?.isNotEmpty == true ? result['text']! : url;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('链接必须以 http:// 或 https:// 开头')),
      );
      return;
    }

    final tag = '[url=$url]$text[/url]';

    final selection = contentController.selection;
    final oldText = contentController.text;

    final start = selection.start < 0 ? oldText.length : selection.start;
    final end = selection.end < 0 ? oldText.length : selection.end;

    final newText = oldText.replaceRange(start, end, tag);

    contentController.text = newText;
    contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: start + tag.length),
    );
  }

  Future<void> _pickAndUploadVideo() async {
    if (uploadingVideo) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (picked == null || picked.files.isEmpty) return;

    final path = picked.files.single.path;

    if (path == null || path.isEmpty) return;

    setState(() {
      uploadingVideo = true;
    });

    try {
      final result = await ApiClient.instance.uploadFile(
        'upload/media',
        file: File(path),
        fields: {
          'type': 'video',
        },
      );

      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        return;
      }

      final data = result.data;

      if (data is Map<String, dynamic>) {
        final url = ApiClient.instance.resolveUrl(
          data['url']?.toString() ?? '',
        );

        if (url.isNotEmpty) {
          final old = contentController.text;
          final insert = '\n[video=$url]\n';

          contentController.text = old + insert;
          contentController.selection = TextSelection.fromPosition(
            TextPosition(offset: contentController.text.length),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          uploadingVideo = false;
        });
      }
    }
  }

  // Preview

  void _previewThread() {
    final title = titleController.text.trim();
    final content = contentController.text.trim();
    final previewImages = <dynamic>{
      ...imageUrls,
      ..._extractRemoteImagesFromContent(content),
    }.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title.isEmpty ? '未填写标题' : title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                if (mode == 'image' && previewImages.isNotEmpty) ...[
                  AspectRatio(
                    aspectRatio: 1,
                    child: PageView.builder(
                      itemCount: previewImages.length,
                      itemBuilder: (context, index) {
                        return SafeNetworkImage(
                          url: previewImages[index],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(14),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                ForumContentView(
                  content: content.isEmpty ? '暂无正文内容' : content,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Publish

  Future<void> _publish() async {
    if (publishing) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入至少 2 个字的标题')),
      );
      return;
    }

    if (content.isEmpty && imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入内容或上传图片')),
      );
      return;
    }

    final remoteImages = _extractRemoteImagesFromContent(content);

    if (mode == 'image' && imageUrls.isEmpty && remoteImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片模式至少需要上传图片或插入远程图片')),
      );
      return;
    }

    setState(() {
      publishing = true;
    });

    try {
      final endpoint = widget.isEdit ? 'threads/update' : 'threads/create';

      final body = {
        if (widget.isEdit) 'thread_id': widget.editThreadId,
        'forum_id': selectedForumId,
        'title': title,
        'content': content,
        'mode': mode,
        'image_urls': imageUrls,
        'attachment_ids': attachmentIds,
        'tags': tags,
        'sensitive_labels': sensitiveLabels,
      };

      final result = await ApiClient.instance.post(endpoint, data: body);

      if (!mounted) return;

      if (!result.success) {
        _showDebugDialog(
          title: '发布失败',
          message: result.message,
          code: result.code,
          endpoint: endpoint,
          body: body,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEdit ? '保存成功' : '发布成功')),
      );

      if (widget.isEdit) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      final data = result.data;

      int threadId = 0;

      if (data is Map<String, dynamic>) {
        threadId = _toInt(data['thread_id']);
        if (threadId <= 0) {
          threadId = _toInt(data['id']);
        }
      }

      await _clearDraftSafely();

      if (!mounted) return;

      if (threadId > 0) {
        context.go('/thread/$threadId');
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          publishing = false;
        });
      }
    }
  }

  void _showDebugDialog({
    required String title,
    required String message,
    int? code,
    String? endpoint,
    Map<String, dynamic>? body,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('错误信息: $message');
    if (code != null) buffer.writeln('错误码: $code');
    if (endpoint != null) buffer.writeln('接口: $endpoint');
    if (body != null) {
      buffer.writeln('请求体:');
      body.forEach((key, value) {
        final v = value.toString();
        buffer.writeln('  $key: ${v.length > 200 ? '${v.substring(0, 200)}...' : v}');
      });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            buffer.toString(),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearDraftSafely() async {
    try {
      await _clearDraft();
    } catch (_) {
      // 草稿清理失败不影响发布结果
    }
  }

  Future<void> _deleteImage(int index) async {
    if (index < 0 || index >= imageUrls.length) return;

    final url = imageUrls[index];
    final attachmentId = index < attachmentIds.length ? attachmentIds[index] : 0;

    setState(() {
      imageUrls.removeAt(index);
      if (index < attachmentIds.length) {
        attachmentIds.removeAt(index);
      }
    });

    final imgTag = '[img=$url]';
    final content = contentController.text;
    if (content.contains(imgTag)) {
      contentController.text = content.replaceAll(imgTag, '');
    }

    if (attachmentId > 0) {
      await ApiClient.instance.post(
        'upload/delete',
        data: {'id': attachmentId},
      );
    } else {
      await ApiClient.instance.post(
        'upload/delete',
        data: {'url': url},
      );
    }
  }

  bool _isLocalUpload(String url) {
    return url.contains('route=file/resolve') ||
        url.contains('route=upload/') ||
        url.contains('index.php?id=');
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isImageMode = mode == 'image';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editorFill = isDark ? const Color(0xFF201B1E) : Colors.white;
    final editorText = isDark ? AppColors.text(context) : Colors.black87;
    final editorHint = isDark
        ? AppColors.textSecondary(context)
        : Colors.black45;
    final editorBorder = isDark
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFB7299), width: 1),
          )
        : InputBorder.none;
    final editorFocusedBorder = isDark
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFB7299), width: 1.5),
          )
        : InputBorder.none;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? '编辑帖子' : '发布帖子'),
        actions: [
          IconButton(
            tooltip: '预览',
            onPressed: _previewThread,
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: '保存草稿',
            onPressed: () {
              _saveDraft(showToast: true);
            },
            icon: const Icon(Icons.save_outlined),
          ),
          TextButton(
            onPressed: publishing ? null : _publish,
            child: publishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发布'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: [
          _ModeSwitch(
            mode: mode,
            onChanged: (value) {
              setState(() {
                mode = value;
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleController,
            maxLength: 80,
            style: TextStyle(color: editorText),
            decoration: InputDecoration(
              hintText: isImageMode ? '给图片笔记起个标题' : '请输入标题',
              hintStyle: TextStyle(color: editorHint),
              filled: true,
              fillColor: editorFill,
              counterText: '',
              border: editorBorder,
              enabledBorder: editorBorder,
              focusedBorder: editorFocusedBorder,
            ),
          ),
          const SizedBox(height: 10),
          if (isImageMode)
            _ImageModePanel(
              imageUrls: imageUrls,
              onDelete: (index) => _deleteImage(index),
            ),
          if (isImageMode) const SizedBox(height: 10),
          TextField(
            controller: contentController,
            minLines: isImageMode ? 5 : 12,
            maxLines: null,
            style: TextStyle(color: editorText),
            decoration: InputDecoration(
              hintText: isImageMode
                  ? '分享这组图片背后的故事...'
                  : '请输入正文，支持 [markdown][/markdown] 和 [img=链接]',
              hintStyle: TextStyle(color: editorHint),
              filled: true,
              fillColor: editorFill,
              border: editorBorder,
              enabledBorder: editorBorder,
              focusedBorder: editorFocusedBorder,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '标签，最多 5 个',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tagController,
                  style: TextStyle(color: editorText),
                  decoration: InputDecoration(
                    hintText: '输入标签，例如 校园',
                    hintStyle: TextStyle(color: editorHint),
                    filled: true,
                    fillColor: editorFill,
                    border: editorBorder,
                    enabledBorder: editorBorder,
                    focusedBorder: editorFocusedBorder,
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addTag,
                child: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                InputChip(
                  label: Text('#$tag'),
                  onDeleted: () {
                    setState(() {
                      tags.remove(tag);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ToolButton(
                icon: Icons.image_outlined,
                text: uploadingImage ? '上传中...' : '上传图片',
                onTap: uploadingImage ? null : _pickAndUploadImages,
              ),
              _ToolButton(
                icon: Icons.notes_rounded,
                text: '插入 Markdown',
                onTap: _insertMarkdownBlock,
              ),
              _ToolButton(
                icon: Icons.lock_outline_rounded,
                text: '插入隐藏',
                onTap: _insertHideBlock,
              ),
              _ToolButton(
                icon: Icons.link_rounded,
                text: '插入链接',
                onTap: _insertUrlTag,
              ),
              _ToolButton(
                icon: Icons.forum_outlined,
                text: '插入帖子',
                onTap: _insertThreadLink,
              ),
              _ToolButton(
                icon: Icons.play_circle_outline_rounded,
                text: uploadingVideo ? '上传中...' : '上传视频',
                onTap: uploadingVideo ? null : _pickAndUploadVideo,
              ),
              _ToolButton(
                icon: Icons.music_note_rounded,
                text: uploadingMusic ? '上传中...' : '上传音乐',
                onTap: uploadingMusic ? null : _pickAndUploadMusic,
              ),
              _ToolButton(
                icon: Icons.library_music_outlined,
                text: '插入音乐',
                onTap: _pickExistingMusic,
              ),
              if (_isAdmin)
                _ToolButton(
                  icon: Icons.attach_file_rounded,
                  text: uploadingAttachment ? '上传中...' : '插入附件',
                  onTap: uploadingAttachment ? null : _pickAndUploadAttachment,
                ),
            ],
          ),
          if (imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ImageManagerPanel(
              imageUrls: imageUrls,
              onInsert: (url) {
                final old = contentController.text;
                final insert = '\n[img=$url]\n';
                contentController.text = old + insert;
                contentController.selection = TextSelection.fromPosition(
                  TextPosition(offset: contentController.text.length),
                );
              },
              onDelete: (index) => _deleteImage(index),
            ),
          ],
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: contentController,
            builder: (context, value, _) {
              final hasImages = imageUrls.isNotEmpty ||
                  _extractRemoteImagesFromContent(value.text).isNotEmpty;
              if (!hasImages) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 19),
                        SizedBox(width: 7),
                        Text(
                          '标记敏感内容',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in sensitiveLabelNames.entries)
                          FilterChip(
                            label: Text(entry.value),
                            selected: sensitiveLabels.contains(entry.key),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  sensitiveLabels.add(entry.key);
                                } else {
                                  sensitiveLabels.remove(entry.key);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: AppColors.scaffoldBg(context),
    );
  }
}

class _ThreadSelection {
  final String dvCode;
  final String title;

  const _ThreadSelection({required this.dvCode, required this.title});
}

class _ThreadPickerSheet extends StatefulWidget {
  const _ThreadPickerSheet();

  @override
  State<_ThreadPickerSheet> createState() => _ThreadPickerSheetState();
}

class _ThreadPickerSheetState extends State<_ThreadPickerSheet> {
  final _searchController = TextEditingController();
  final List<Map<String, dynamic>> _threads = [];

  Timer? _searchTimer;
  bool _loading = true;
  String? _error;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiClient.instance.get(
      'threads/selection',
      query: {
        'keyword': _searchController.text.trim(),
        'page_size': 30,
      },
    );
    if (!mounted || serial != _requestSerial) return;

    if (!result.success || result.data is! Map<String, dynamic>) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    final raw = (result.data as Map<String, dynamic>)['list'];
    setState(() {
      _threads
        ..clear()
        ..addAll(
          raw is List
              ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
              : const Iterable<Map<String, dynamic>>.empty(),
        );
      _loading = false;
    });
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '搜索帖子标题、作者或 DV 号',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.inputFill(context),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : _threads.isEmpty
                        ? const Center(child: Text('没有找到可插入的帖子'))
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: _threads.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final thread = _threads[index];
                              final title =
                                  thread['title']?.toString() ?? '无标题';
                              final dvCode =
                                  thread['dv_code']?.toString() ?? '';
                              final author =
                                  thread['author_name']?.toString() ?? '用户';
                              final summary =
                                  thread['summary']?.toString() ?? '';

                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.article_outlined),
                                ),
                                title: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  summary.isEmpty
                                      ? '$author · $dvCode'
                                      : '$summary\n$author · $dvCode',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                isThreeLine: summary.isNotEmpty,
                                onTap: dvCode.isEmpty
                                    ? null
                                    : () => Navigator.of(context).pop(
                                          _ThreadSelection(
                                            dvCode: dvCode,
                                            title: title,
                                          ),
                                        ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;

  const _ModeSwitch({
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'article',
          label: Text('图文模式'),
          icon: Icon(Icons.article_outlined),
        ),
        ButtonSegment(
          value: 'image',
          label: Text('图片模式'),
          icon: Icon(Icons.photo_library_outlined),
        ),
      ],
      selected: {
        mode,
      },
      onSelectionChanged: (set) {
        onChanged(set.first);
      },
    );
  }
}

class _ImageModePanel extends StatelessWidget {
  final List<String> imageUrls;
  final ValueChanged<int> onDelete;

  const _ImageModePanel({
    required this.imageUrls,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Text(
          '图片模式：请先上传图片',
          style: TextStyle(
            color: Colors.grey.shade500,
          ),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return Stack(
            children: [
              SafeNetworkImage(
                url: imageUrls[index],
                width: 120,
                height: 150,
                borderRadius: BorderRadius.circular(14),
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => onDelete(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.card(context),
        foregroundColor: AppColors.text(context),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
    );
  }
}

class _ImageManagerPanel extends StatelessWidget {
  final List<String> imageUrls;
  final ValueChanged<String> onInsert;
  final ValueChanged<int> onDelete;

  const _ImageManagerPanel({
    required this.imageUrls,
    required this.onInsert,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '已上传图片',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < imageUrls.length; i++)
                _ImageItem(
                  url: imageUrls[i],
                  onInsert: () => onInsert(imageUrls[i]),
                  onDelete: () => onDelete(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageItem extends StatelessWidget {
  final String url;
  final VoidCallback onInsert;
  final VoidCallback onDelete;

  const _ImageItem({
    required this.url,
    required this.onInsert,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            SafeNetworkImage(
              url: url,
              width: 80,
              height: 80,
              borderRadius: BorderRadius.circular(8),
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onInsert,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFB7299),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '插入',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MusicPickerDialog extends StatefulWidget {
  const _MusicPickerDialog();

  @override
  State<_MusicPickerDialog> createState() => _MusicPickerDialogState();
}

class _MusicPickerDialogState extends State<_MusicPickerDialog> {
  final _controller = TextEditingController();
  var _loading = false;
  List<Map<String, dynamic>> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    setState(() => _loading = true);
    final result = await ApiClient.instance.get(
      'music/search',
      query: {'keyword': keyword, 'page_size': 30},
    );
    if (!mounted) return;
    final raw = result.success && result.data is Map<String, dynamic>
        ? (result.data as Map<String, dynamic>)['list']
        : null;
    setState(() {
      _loading = false;
      _results = raw is List
          ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('插入音乐'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '搜索歌名或歌手',
                suffixIcon: IconButton(
                  tooltip: '搜索',
                  onPressed: _search,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('搜索已上传的音乐'))
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            final cover = item['cover_url']?.toString() ?? '';
                            final title = item['title']?.toString() ?? '未知歌曲';
                            final artist = item['artist']?.toString() ?? '';
                            return ListTile(
                              leading: cover.isEmpty
                                  ? const CircleAvatar(child: Icon(Icons.music_note_rounded))
                                  : SafeNetworkImage(
                                      url: cover,
                                      width: 44,
                                      height: 44,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: artist.isEmpty ? null : Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消'))],
    );
  }
}
