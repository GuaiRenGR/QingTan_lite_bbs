import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/safe_network_image.dart';

class NotificationListPage extends StatefulWidget {
  final String type;

  const NotificationListPage({super.key, required this.type});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  bool loadingMore = false;
  bool noMore = false;
  int page = 1;

  final ScrollController _scrollController = ScrollController();

  static const _typeTitles = {
    'reply': '回复我的',
    'mention': '@我',
    'like': '收到的赞',
    'system': '系统通知',
  };

  @override
  void initState() {
    super.initState();
    _initialize();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initialize() async {
    await _markTypeRead();
    await _load(refresh: true);
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

  Future<void> _markTypeRead() async {
    final result = await ApiClient.instance.post(
      'notifications/read',
      data: {'type': widget.type},
    );
    if (!mounted || !result.success) return;

    setState(() {
      for (final item in items) {
        item['is_read'] = 1;
      }
    });
  }

  Future<void> _markAllRead() async {
    await ApiClient.instance.post(
      'notifications/read',
      data: {'type': widget.type},
    );
    setState(() {
      for (final item in items) {
        item['is_read'] = 1;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已全部标记已读')),
      );
    }
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      page = 1;
      noMore = false;
    }

    final result = await ApiClient.instance.get(
      'notifications/list',
      query: {
        'type': widget.type,
        'page': page,
        'page_size': 20,
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
        if (refresh) items.clear();
        items.addAll(list);
        loading = false;
        loadingMore = false;
        noMore = list.isEmpty;
      });
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
    await _load(refresh: false);
  }

  Future<void> _refresh() async {
    await _load(refresh: true);
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 30) return '${diff.inDays}天前';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return raw;
    }
  }

  void _onTapItem(Map<String, dynamic> item) {
    final data = item['data'];
    Map<String, dynamic> extra = {};
    if (data is Map) {
      extra = Map<String, dynamic>.from(data);
    }

    final threadId = _toInt(extra['thread_id']);
    if (threadId > 0) {
      context.push('/thread/$threadId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _typeTitles[widget.type] ?? '通知';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('全部已读'),
          ),
        ],
      ),
      body: loading && items.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : items.isEmpty
              ? Center(
                  child: Text(
                    '暂无通知',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 0.5),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        if (loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (noMore) {
                          return Padding(
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
                          );
                        }
                        return const SizedBox(height: 20);
                      }

                      final item = items[index];
                      return _NotificationItem(
                        item: item,
                        type: widget.type,
                        formatTime: _formatTime,
                        onTap: () => _onTapItem(item),
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final String type;
  final String Function(String?) formatTime;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.item,
    required this.type,
    required this.formatTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? '';
    final content = item['content']?.toString() ?? '';
    final createdAt = item['created_at']?.toString() ?? '';
    final isRead = item['is_read']?.toString() == '1';

    final fromUser = item['from_user'] as Map?;
    final fromNickname = fromUser?['nickname']?.toString() ?? '';
    final fromAvatar = fromUser?['avatar']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: isRead
            ? AppColors.card(context)
            : Theme.of(context).colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fromAvatar.isNotEmpty)
              SafeNetworkImage(
                url: fromAvatar,
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(20),
                errorWidget: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(_typeIcon, size: 20, color: Colors.grey.shade500),
                ),
              )
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: Icon(_typeIcon, size: 20, color: Colors.grey.shade500),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (fromNickname.isNotEmpty) ...[
                        Text(
                          fromNickname,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatTime(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _typeIcon {
    switch (type) {
      case 'reply':
        return Icons.chat_bubble_outline;
      case 'mention':
        return Icons.alternate_email;
      case 'like':
        return Icons.favorite_border;
      case 'system':
        return Icons.notifications_none;
      default:
        return Icons.notifications_none;
    }
  }
}
