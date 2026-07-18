import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  final int conversationId;
  final int targetUserId;
  final String targetNickname;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.targetUserId,
    required this.targetNickname,
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

  int? _currentUserId;
  late int _conversationId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _toInt(ref.read(authControllerProvider).user?['id']);
    _conversationId = widget.conversationId;
    _loadMessages(refresh: true);
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
      'messages/list',
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

      // 标记已读
      if (refresh && convId > 0) {
        ApiClient.instance.post(
          'messages/read',
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

  Future<void> _send() async {
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

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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

                          return _MessageBubble(
                            content: msg['content']?.toString() ?? '',
                            isMine: isMine,
                            time: msg['created_at']?.toString(),
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
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(fontSize: 15),
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
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isMine;
  final String? time;

  const _MessageBubble({
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
