import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/safe_network_image.dart';
import '../../core/widgets/sensitive_media.dart';
import '../auth/auth_controller.dart';

class XFeedPage extends ConsumerStatefulWidget {
  const XFeedPage({super.key});

  @override
  ConsumerState<XFeedPage> createState() => _XFeedPageState();
}

class _XFeedPageState extends ConsumerState<XFeedPage> {
  final scrollController = ScrollController();
  final items = <Map<String, dynamic>>[];
  String channel = 'recommend';
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  int page = 1;
  String? error;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  bool get _isAdmin {
    final user = ref.read(authControllerProvider).user;
    return int.tryParse(user?['group_id']?.toString() ?? '') == 99;
  }

  void _onScroll() {
    if (scrollController.position.extentAfter < 500) _loadMore();
  }

  Future<List<Map<String, dynamic>>?> _fetch(int targetPage) async {
    final result = await ApiClient.instance.get(
      channel == 'following' ? 'threads/following' : 'threads/recommend',
      query: {
        'page': targetPage,
        'page_size': 20,
        if (channel != 'following') 'channel': 'recommend',
      },
    );
    if (!result.success || result.data is! Map<String, dynamic>) {
      error = result.message;
      return null;
    }
    final data = result.data as Map<String, dynamic>;
    hasMore = data['has_more'] == true;
    final raw = data['list'];
    return raw is List
        ? raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> _refresh() async {
    if (!_isAdmin) return;
    setState(() {
      loading = items.isEmpty;
      error = null;
    });
    final loaded = await _fetch(1);
    if (!mounted) return;
    setState(() {
      if (loaded != null) {
        items
          ..clear()
          ..addAll(loaded);
        page = 1;
      }
      loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_isAdmin || loading || loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    final nextPage = page + 1;
    final loaded = await _fetch(nextPage);
    if (!mounted) return;
    setState(() {
      if (loaded != null) {
        final known = items.map((item) => item['id']?.toString()).toSet();
        items.addAll(loaded.where((item) => known.add(item['id']?.toString())));
        page = nextPage;
      }
      loadingMore = false;
    });
  }

  void _switchChannel(String value) {
    if (channel == value) return;
    setState(() {
      channel = value;
      items.clear();
      loading = true;
      hasMore = true;
      page = 1;
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isAdmin =
        int.tryParse(auth.user?['group_id']?.toString() ?? '') == 99;
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('该页面仅对管理员开放')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.card(context),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'X',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _FeedTab(
                label: '为你推荐',
                selected: channel == 'recommend',
                onTap: () => _switchChannel('recommend'),
              ),
              _FeedTab(
                label: '正在关注',
                selected: channel == 'following',
                onTap: () => _switchChannel('following'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/thread/create'),
        tooltip: '发布帖子',
        child: const Icon(Icons.add_rounded),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null && items.isEmpty
              ? Center(
                  child: TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(error!),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length + (loadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.border(context),
                    ),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(18),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      return _XFeedItem(item: items[index]);
                    },
                  ),
                ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FeedTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.text(context)
                      : AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 56,
                height: 4,
                color: selected ? const Color(0xFF1D9BF0) : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XFeedItem extends StatelessWidget {
  final Map<String, dynamic> item;

  const _XFeedItem({required this.item});

  int _number(String key) => int.tryParse(item[key]?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final id = _number('id');
    final author = item['author_name']?.toString() ?? '用户';
    final avatar = item['author_avatar']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    final summary = item['summary']?.toString() ?? '';
    final cover = item['cover']?.toString() ?? '';
    final createdAt = item['created_at']?.toString() ?? '';

    return InkWell(
      onTap: id > 0 ? () => context.push('/thread/$id') : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeNetworkImage(
              url: avatar,
              width: 42,
              height: 42,
              borderRadius: BorderRadius.circular(21),
              errorWidget: const CircleAvatar(
                radius: 21,
                child: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '@u${item['user_id'] ?? ''} · $createdAt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(Icons.more_horiz_rounded, size: 19),
                    ],
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(summary, style: const TextStyle(height: 1.35)),
                  ],
                  if (cover.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SensitiveMedia(
                        labels: parseSensitiveLabels(item['sensitive_labels']),
                        blockedHeight: 190,
                        child: SafeNetworkImage(
                          url: cover,
                          width: double.infinity,
                          height: 190,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Metric(
                        Icons.chat_bubble_outline_rounded,
                        _number('reply_count'),
                      ),
                      const _Metric(Icons.repeat_rounded, 0),
                      _Metric(
                        Icons.favorite_border_rounded,
                        _number('like_count'),
                      ),
                      _Metric(Icons.bar_chart_rounded, _number('view_count')),
                      const _Metric(Icons.ios_share_rounded, 0),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final int value;

  const _Metric(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary(context)),
        if (value > 0) ...[
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }
}
