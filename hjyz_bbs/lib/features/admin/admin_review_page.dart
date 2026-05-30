import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/safe_network_image.dart';

class AdminReviewPage extends StatefulWidget {
  const AdminReviewPage({super.key});

  @override
  State<AdminReviewPage> createState() => _AdminReviewPageState();
}

class _AdminReviewPageState extends State<AdminReviewPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  bool loadingMore = false;
  bool noMore = false;
  int page = 1;
  int total = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
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
      'admin/review/list',
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

  Future<void> _approve(int threadId) async {
    final result = await ApiClient.instance.post(
      'admin/review/approve',
      data: {'thread_id': threadId},
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已通过')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _reject(int threadId) async {
    final result = await ApiClient.instance.post(
      'admin/review/reject',
      data: {'thread_id': threadId},
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已拒绝')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: Text('内容审核 ($total)')),
      body: loading && items.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        '暂无待审核内容',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      if (loadingMore) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      if (noMore) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text('没有更多了',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 12)),
                          ),
                        );
                      }
                      return const SizedBox(height: 20);
                    }

                    final item = items[index];
                    final threadId = _toInt(item['id']);
                    final title = item['title']?.toString() ?? '';
                    final author = item['author'] as Map? ?? {};
                    final authorName =
                        author['nickname']?.toString() ?? '用户';
                    final authorAvatar = author['avatar']?.toString() ?? '';

                    return Card(
                      elevation: 0,
                      color: AppColors.card(context),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 标题行 - 可点击跳转
                            GestureDetector(
                              onTap: () => context.push('/thread/$threadId'),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                children: [
                                  SafeNetworkImage(
                                    url: authorAvatar,
                                    width: 32,
                                    height: 32,
                                    borderRadius: BorderRadius.circular(16),
                                    errorWidget: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey.shade200,
                                      child: Icon(Icons.person,
                                          size: 18,
                                          color: Colors.grey.shade500),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$authorName · 点击查看详情',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '待审核',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // 操作按钮
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _reject(threadId),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('拒绝'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: BorderSide(
                                          color: Colors.red.shade200),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _approve(threadId),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('通过'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
