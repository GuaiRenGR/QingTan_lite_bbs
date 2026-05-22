import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/safe_network_image.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  Map<String, int> unreadCounts = {
    'reply': 0,
    'mention': 0,
    'like': 0,
    'system': 0,
  };
  int messageUnread = 0;

  List<Map<String, dynamic>> conversations = [];
  bool loading = true;
  bool loadingMore = false;
  bool noMore = false;
  int page = 1;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      page = 1;
      noMore = false;
    });
    await Future.wait([
      _loadUnreadCounts(),
      _loadConversations(refresh: true),
    ]);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadUnreadCounts() async {
    final result = await ApiClient.instance.get('notifications/unread');
    if (result.success && result.data is Map) {
      final data = result.data as Map;
      setState(() {
        unreadCounts = {
          'reply': _toInt(data['reply']),
          'mention': _toInt(data['mention']),
          'like': _toInt(data['like']),
          'system': _toInt(data['system']),
        };
      });
    }

    final msgResult = await ApiClient.instance.get('messages/unread');
    if (msgResult.success && msgResult.data is Map) {
      setState(() {
        messageUnread = _toInt((msgResult.data as Map)['unread_count']);
      });
    }
  }

  Future<void> _loadConversations({required bool refresh}) async {
    if (refresh) {
      page = 1;
      noMore = false;
    }

    final result = await ApiClient.instance.get(
      'messages/conversations',
      query: {'page': page, 'page_size': 20},
    );

    if (!mounted) return;

    if (result.success && result.data is Map) {
      final data = result.data as Map;
      final list = (data['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        if (refresh) conversations.clear();
        conversations.addAll(list);
        loadingMore = false;
        noMore = list.isEmpty;
      });
    } else {
      setState(() {
        loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (loading || loadingMore || noMore) return;
    setState(() => loadingMore = true);
    page++;
    await _loadConversations(refresh: false);
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (dt.year == now.year) {
        return '${dt.month}/${dt.day}';
      }
      return '${dt.year}/${dt.month}/${dt.day}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/notification-settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          children: [
            // 通知入口区域
            Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _NotificationEntry(
                    icon: Icons.chat_bubble_outline,
                    label: '回复我的',
                    count: unreadCounts['reply'] ?? 0,
                    onTap: () => context.push('/notifications?type=reply'),
                  ),
                  _NotificationEntry(
                    icon: Icons.alternate_email,
                    label: '@我',
                    count: unreadCounts['mention'] ?? 0,
                    onTap: () => context.push('/notifications?type=mention'),
                  ),
                  _NotificationEntry(
                    icon: Icons.favorite_border,
                    label: '收到的赞',
                    count: unreadCounts['like'] ?? 0,
                    onTap: () => context.push('/notifications?type=like'),
                  ),
                  _NotificationEntry(
                    icon: Icons.notifications_none,
                    label: '系统通知',
                    count: unreadCounts['system'] ?? 0,
                    onTap: () => context.push('/notifications?type=system'),
                  ),
                ],
              ),
            ),

            // 私信标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Text(
                    '私信',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (messageUnread > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB7299),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$messageUnread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 会话列表
            if (loading && conversations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (conversations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    '暂无私信',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ...conversations.map((conv) => _ConversationItem(
                    conversation: conv,
                    formatTime: _formatTime,
                    onTap: () {
                      final otherUser = conv['other_user'] as Map? ?? {};
                      final convId = conv['id'] ?? 0;
                      final userId = otherUser['id'] ?? 0;
                      final nickname = otherUser['nickname'] ?? '用户';
                      context.push(
                        '/chat?conv_id=$convId&user_id=$userId&nickname=${Uri.encodeComponent(nickname.toString())}',
                      );
                    },
                  )),

            // 加载更多
            if (loadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (noMore && conversations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '没有更多了',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _NotificationEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _NotificationEntry({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Badge(
                isLabelVisible: count > 0,
                label: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
                backgroundColor: const Color(0xFFFB7299),
                child: Icon(icon, size: 28, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String Function(String?) formatTime;
  final VoidCallback onTap;

  const _ConversationItem({
    required this.conversation,
    required this.formatTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = conversation['other_user'] as Map? ?? {};
    final nickname = otherUser['nickname']?.toString() ?? '用户';
    final avatar = otherUser['avatar']?.toString() ?? '';
    final lastMessage = conversation['last_message']?.toString() ?? '';
    final lastTime = conversation['last_message_at']?.toString();
    final unread = conversation['unread_count'] ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: SafeNetworkImage(
          url: avatar,
          width: 48,
          height: 48,
          borderRadius: BorderRadius.circular(24),
          errorWidget: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            child: Icon(Icons.person, color: Colors.grey.shade500),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              formatTime(lastTime),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB7299),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
