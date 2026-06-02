import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/safe_network_image.dart';

class AdminThreadsPage extends StatefulWidget {
  const AdminThreadsPage({super.key});

  @override
  State<AdminThreadsPage> createState() => _AdminThreadsPageState();
}

class _AdminThreadsPageState extends State<AdminThreadsPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  bool loadingMore = false;
  bool noMore = false;
  int page = 1;
  int total = 0;
  String keyword = '';
  String visibility = '';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      page = 1;
      noMore = false;
    }

    final result = await ApiClient.instance.get(
      'admin/threads',
      query: {
        'page': page,
        'page_size': 20,
        if (keyword.isNotEmpty) 'keyword': keyword,
        if (visibility.isNotEmpty) 'visibility': visibility,
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
        total = _toInt(data['total']);
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

  void _onSearch() {
    keyword = _searchController.text.trim();
    _load(refresh: true);
  }

  void _setFilter(String? v) {
    visibility = v ?? '';
    _load(refresh: true);
  }

  Future<void> _toggleSticky(int threadId) async {
    final result = await ApiClient.instance.post(
      'admin/thread/sticky',
      data: {'thread_id': threadId},
    );

    if (!mounted) return;

    if (result.success) {
      final isSticky = result.data is Map ? result.data['is_sticky'] : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSticky == 1 ? '已置顶' : '已取消置顶')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _toggleLock(int threadId) async {
    final result = await ApiClient.instance.post(
      'admin/thread/lock',
      data: {'thread_id': threadId},
    );

    if (!mounted) return;

    if (result.success) {
      final isLocked = result.data is Map ? result.data['is_locked'] : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isLocked == 1 ? '已锁定' : '已取消锁定')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _deleteThread(int threadId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除帖子「$title」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await ApiClient.instance.post(
      'admin/thread/delete',
      data: {'thread_id': threadId},
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('帖子已删除')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  void _showThreadActions(Map<String, dynamic> thread) {
    final threadId = _toInt(thread['id']);
    final title = thread['title']?.toString() ?? '';
    final isSticky = _toInt(thread['is_sticky']) == 1;
    final isLocked = _toInt(thread['is_locked']) == 1;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_outlined,
                    color: Color(0xFF2196F3)),
                title: const Text('查看帖子'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/thread/$threadId');
                },
              ),
              ListTile(
                leading: Icon(
                  isSticky ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isSticky ? const Color(0xFFFB7299) : Colors.grey,
                ),
                title: Text(isSticky ? '取消置顶' : '置顶'),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleSticky(threadId);
                },
              ),
              ListTile(
                leading: Icon(
                  isLocked ? Icons.lock : Icons.lock_open,
                  color: isLocked ? Colors.orange : Colors.grey,
                ),
                title: Text(isLocked ? '取消锁定' : '锁定'),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleLock(threadId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除帖子',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteThread(threadId, title);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: Text('帖子管理 ($total)')),
      body: Column(
        children: [
          // 搜索栏 + 筛选
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索标题或作者',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (keyword.isNotEmpty) {
                            keyword = '';
                            _load(refresh: true);
                          }
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      filled: true,
                      fillColor: AppColors.inputFill(context),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _onSearch(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: _setFilter,
                  icon: Icon(
                    Icons.filter_list,
                    color: visibility.isNotEmpty
                        ? const Color(0xFFFB7299)
                        : Colors.grey,
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: '', child: Text('全部')),
                    const PopupMenuItem(
                        value: 'public', child: Text('公开')),
                    const PopupMenuItem(
                        value: 'pending', child: Text('待审核')),
                    const PopupMenuItem(
                        value: 'private', child: Text('私密')),
                    const PopupMenuItem(
                        value: 'locked', child: Text('已锁定')),
                  ],
                ),
              ],
            ),
          ),
          // 列表
          Expanded(
            child: loading && items.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : items.isEmpty
                    ? Center(
                        child: Text(
                          '暂无帖子',
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
                          separatorBuilder: (_, _) =>
                              const Divider(height: 0.5),
                          itemBuilder: (context, index) {
                            if (index == items.length) {
                              if (loadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
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

                            final thread = items[index];
                            return _ThreadRow(
                              thread: thread,
                              toInt: _toInt,
                              formatTime: _formatTime,
                              onTap: () => _showThreadActions(thread),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final Map<String, dynamic> thread;
  final int Function(dynamic) toInt;
  final String Function(String?) formatTime;
  final VoidCallback onTap;

  const _ThreadRow({
    required this.thread,
    required this.toInt,
    required this.formatTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = thread['title']?.toString() ?? '';
    final cover = thread['cover']?.toString() ?? '';
    final author = thread['author'] as Map? ?? {};
    final authorName = author['nickname']?.toString() ?? '用户';
    final isSticky = toInt(thread['is_sticky']) == 1;
    final isLocked = toInt(thread['is_locked']) == 1;
    final viewCount = toInt(thread['view_count']);
    final likeCount = toInt(thread['like_count']);
    final postCount = toInt(thread['post_count']);
    final createdAt = thread['created_at']?.toString() ?? '';
    final vis = thread['visibility']?.toString() ?? 'public';

    return ListTile(
      onTap: onTap,
      leading: cover.isNotEmpty
          ? SafeNetworkImage(
              url: cover,
              width: 52,
              height: 52,
              borderRadius: BorderRadius.circular(8),
              errorWidget: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.article, color: Colors.grey.shade400),
              ),
            )
          : Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.article, color: Colors.grey.shade400),
            ),
      title: Row(
        children: [
          if (isSticky) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFB7299).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '置顶',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFFB7299),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (isLocked) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '锁定',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (vis != 'public') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                vis == 'pending' ? '待审' : vis == 'private' ? '私密' : vis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '$authorName · $viewCount 浏览 · $likeCount 赞 · $postCount 评论 · ${formatTime(createdAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}
