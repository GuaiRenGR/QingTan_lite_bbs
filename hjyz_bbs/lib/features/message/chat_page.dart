// ignore_for_file: unused_element, unused_element_parameter
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/emoji_input_field.dart';
import '../../core/widgets/emoji_picker.dart';
import '../../core/widgets/emoji_text.dart';
import '../../core/widgets/safe_network_image.dart';
import '../auth/auth_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  final int conversationId;
  final int targetUserId;
  final String targetNickname;
  final int? groupId;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.targetUserId,
    required this.targetNickname,
    this.groupId,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  bool loadingMore = false;
  bool noMore = false;
  int page = 1;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  int? _currentUserId;
  late int _conversationId;
  bool _showEmojiPicker = false;
  bool _uploadingImage = false;
  Map<String, dynamic>? _quotedMessage;

  @override
  void initState() {
    super.initState();
    _currentUserId = _toInt(ref.read(authControllerProvider).user?['id']);
    _conversationId = widget.conversationId;
    _loadMessages(refresh: true);
    if (widget.groupId != null) _loadCachedGroupMessages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // 反转列表，向上滚动加载更多
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMessages({required bool refresh}) async {
    if (refresh) {
      page = 1;
      noMore = false;
    }

    final convId = _conversationId;
    if (convId <= 0) {
      setState(() {
        loading = false;
        noMore = true;
      });
      return;
    }

    final result = await ApiClient.instance.get(
      widget.groupId != null ? 'groups/messages' : 'messages/list',
      query: {
        'conversation_id': convId,
        'page': page,
        'page_size': 30,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map) {
      final data = result.data as Map;
      final list = (data['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        if (refresh) messages.clear();
        messages.addAll(list);
        loading = false;
        loadingMore = false;
        noMore = list.isEmpty;
      });
      if (widget.groupId != null) _saveCachedGroupMessages();

      // 标记已读
      if (refresh && convId > 0) {
        ApiClient.instance.post(
          widget.groupId != null ? 'groups/read' : 'messages/read',
          data: {'conversation_id': convId},
        );
      }
    } else {
      setState(() {
        loading = false;
        loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (loading || loadingMore || noMore) return;
    setState(() => loadingMore = true);
    page++;
    await _loadMessages(refresh: false);
  }

  Future<void> _sendLegacy() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    _inputFocus.unfocus();

    final result = await ApiClient.instance.post(
      'messages/send',
      data: {
        'to_user_id': widget.targetUserId,
        'content': text,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map) {
      final data = result.data as Map;

      // 更新会话 ID（新会话时）
      if (_conversationId <= 0 && data['conversation_id'] != null) {
        _conversationId = _toInt(data['conversation_id']);
      }

      // 添加到本地列表
      setState(() {
        messages.insert(0, {
          'id': data['id'] ?? 0,
          'sender_id': _currentUserId,
          'content': text,
          'is_read': 0,
          'created_at': data['created_at'] ?? '',
          'is_mine': true,
        });
      });

      // 滚动到底部
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<bool> _sendMessage({
    String content = '',
    String messageType = 'text',
    String imageUrl = '',
  }) async {
    final text = content.trim();
    if (messageType == 'text' && text.isEmpty) return false;
    if (messageType == 'image' && imageUrl.isEmpty) return false;

    final quote = _quotedMessage;
    final result = await ApiClient.instance.post(
      widget.groupId != null ? 'groups/send' : 'messages/send',
      data: {
        if (widget.groupId != null) 'conversation_id': _conversationId,
        if (widget.groupId == null) 'to_user_id': widget.targetUserId,
        'content': text,
        'message_type': messageType,
        if (imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (quote != null && _toInt(quote['id']) > 0)
          'reply_to_id': _toInt(quote['id']),
      },
    );

    if (!mounted) return false;
    if (result.success && result.data is Map) {
      final data = result.data as Map;
      if (_conversationId <= 0 && data['conversation_id'] != null) {
        _conversationId = _toInt(data['conversation_id']);
      }
      setState(() {
        messages.insert(0, {
          'id': data['id'] ?? 0,
          'sender_id': _currentUserId,
          'message_type': data['message_type'] ?? messageType,
          'content': text,
          'image_url': data['image_url'] ?? imageUrl,
          'reply_to_id': data['reply_to_id'],
          'reply_to': data['reply_to'],
          'is_read': 0,
          'created_at': data['created_at'] ?? '',
          'is_mine': true,
        });
        _quotedMessage = null;
      });
      if (widget.groupId != null) _saveCachedGroupMessages();
      if (messageType == 'text') {
        _inputController.clear();
      }
      _inputFocus.unfocus();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    return false;
  }

  String get _groupCacheKey => 'group_messages_${widget.groupId}';

  Future<void> _loadCachedGroupMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_groupCacheKey);
    if (!mounted || raw == null) return;
    try {
      final cached = (jsonDecode(raw) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (cached.isNotEmpty && messages.isEmpty) setState(() { messages = cached; loading = false; });
    } catch (_) {}
  }

  Future<void> _saveCachedGroupMessages() async {
    if (widget.groupId == null || messages.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groupCacheKey, jsonEncode(messages.take(300).toList()));
  }

  Future<void> _send() async {
    await _sendMessage(content: _inputController.text);
  }

  Future<void> _pickAndSendImage() async {
    if (_uploadingImage) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingImage = true);
    try {
      var result = await ApiClient.instance.uploadFile(
        'upload/media',
        file: File(picked.path),
        fields: const {'type': 'chat_image'},
        taskName: '私信图片 ${picked.name}',
      );
      // Older servers do not know the chat_image type yet. Fall back to the
      // original image route so existing installations can still send media.
      if (!result.success) {
        result = await ApiClient.instance.uploadFile(
          'upload/media',
          file: File(picked.path),
          fields: const {'type': 'image'},
          taskName: '私信图片 ${picked.name}',
        );
      }
      if (!mounted) return;
      if (result.success && result.data is Map) {
        final url = (result.data as Map)['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          await _sendMessage(messageType: 'image', imageUrl: url);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片上传结果无效')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _toggleEmojiPicker() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
    if (_showEmojiPicker) {
      _inputFocus.unfocus();
    } else {
      _inputFocus.requestFocus();
    }
  }

  void _insertEmoji(String char) {
    final selection = _inputController.selection;
    final text = _inputController.text;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= start ? selection.end : start;
    _inputController.value = TextEditingValue(
      text: text.replaceRange(start, end, char),
      selection: TextSelection.collapsed(offset: start + char.length),
    );
  }

  Future<void> _quoteMessage(Map<String, dynamic> message) async {
    final shouldQuote = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.format_quote_rounded),
          title: const Text('引用消息'),
          onTap: () => Navigator.pop(sheetContext, true),
        ),
      ),
    );
    if (shouldQuote == true && mounted) {
      setState(() {
        _quotedMessage = message;
        _showEmojiPicker = false;
      });
      _inputFocus.requestFocus();
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: Text(widget.targetNickname),
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: loading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : messages.isEmpty
                    ? Center(
                        child: Text(
                          '暂无消息，发条消息吧',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        itemCount: messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            if (loadingMore) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            if (noMore && messages.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(12),
                                child: Center(
                                  child: Text(
                                    '没有更多了',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }

                          final msg = messages[index];
                          final isMine = msg['is_mine'] == true ||
                              _toInt(msg['sender_id']) == _currentUserId;

                          return GestureDetector(
                            onLongPress: () => _quoteMessage(msg),
                            child: _MessageBubble(
                              content: msg['content']?.toString() ?? '',
                              messageType:
                                  msg['message_type']?.toString() ?? 'text',
                              imageUrl: msg['image_url']?.toString() ?? '',
                              quote: msg['reply_to'] is Map
                                  ? Map<String, dynamic>.from(msg['reply_to'] as Map)
                                  : null,
                              isMine: isMine,
                              time: msg['created_at']?.toString(),
                            ),
                          );
                        },
                      ),
          ),
          // 输入区域
          Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              border: Border(
                top: BorderSide(color: AppColors.border(context), width: 0.5),
              ),
            ),
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_quotedMessage != null)
                  _QuoteComposerPreview(
                    message: _quotedMessage!,
                    onClose: () => setState(() => _quotedMessage = null),
                  ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _uploadingImage ? null : _pickAndSendImage,
                      tooltip: '发送图片',
                      icon: _uploadingImage
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_outlined),
                    ),
                    IconButton(
                      onPressed: _toggleEmojiPicker,
                      tooltip: '表情',
                      icon: Icon(
                        _showEmojiPicker
                            ? Icons.keyboard_rounded
                            : Icons.emoji_emotions_outlined,
                      ),
                    ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: EmojiInputField(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFB7299),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                  ],
                ),
                if (_showEmojiPicker)
                  EmojiPicker(onEmojiSelected: _insertEmoji),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final String messageType;
  final String imageUrl;
  final Map<String, dynamic>? quote;
  final bool isMine;
  final String? time;

  const _MessageBubble({
    required this.content,
    required this.messageType,
    required this.imageUrl,
    required this.quote,
    required this.isMine,
    this.time,
  });

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final sameDay = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final timeText =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (sameDay) return timeText;
    return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $timeText';
  }

  String _quotePreview(Map<String, dynamic> value) {
    if (value['message_type']?.toString() == 'image') return '[图片]';
    final text = value['content']?.toString() ?? '';
    return text.isEmpty ? '[消息]' : text;
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? const Color(0xFFFB7299)
        : AppColors.card(context);
    final textColor = isMine ? Colors.white : AppColors.text(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade300,
              child: Icon(Icons.person, size: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.76,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (quote != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: EmojiText(
                            _quotePreview(quote!),
                            imageSize: 15,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      if (messageType == 'image' && imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SafeNetworkImage(
                            url: imageUrl,
                            width: 190,
                            height: 190,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        EmojiText(
                          content,
                          imageSize: 20,
                          style: TextStyle(
                            fontSize: 15,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                if (time != null && time!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      _formatTime(time),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _QuoteComposerPreview extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onClose;

  const _QuoteComposerPreview({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final sender = message['sender'] is Map
        ? (message['sender'] as Map)['nickname']?.toString() ?? '用户'
        : '用户';
    final isImage = message['message_type']?.toString() == 'image';
    final preview = isImage
        ? '[图片]'
        : (message['content']?.toString() ?? '').trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '回复 $sender：${preview.isEmpty ? '[消息]' : preview}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: '取消引用',
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _LegacyMessageBubble extends StatelessWidget {
  final String content;
  final bool isMine;
  final String? time;

  const _LegacyMessageBubble({
    required this.content,
    required this.isMine,
    this.time,
  });

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade300,
              child: Icon(Icons.person, size: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xFFFB7299)
                        : AppColors.card(context),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMine ? Colors.white : AppColors.text(context),
                      height: 1.4,
                    ),
                  ),
                ),
                if (time != null && time!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      _formatTime(time),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
