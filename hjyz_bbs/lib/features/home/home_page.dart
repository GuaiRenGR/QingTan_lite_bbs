import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../thread/widgets/thread_waterfall_grid.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;
  bool loadingMore = false;
  String? error;

  int page = 1;
  bool hasMore = true;

  String channel = 'recommend';

  final List<Map<String, dynamic>> threads = [];

  static const _channels = [
    {'key': 'recommend', 'label': '推荐'},
    {'key': 'latest', 'label': '最新'},
    {'key': 'hot', 'label': '热门'},
    {'key': 'digest', 'label': '精华'},
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    page = 1;
    hasMore = true;

    final result = await ApiClient.instance.get(
      'threads/recommend',
      query: {
        'page': 1,
        'page_size': 20,
        'channel': channel,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final raw = data['list'];

      setState(() {
        threads
          ..clear()
          ..addAll(
            raw is List
                ? raw
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
                : [],
          );
        hasMore = data['has_more'] == true;
        loading = false;
        error = null;
      });
    } else {
      setState(() {
        loading = false;
        error = result.message;
      });
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore) return;

    setState(() {
      loadingMore = true;
    });

    final nextPage = page + 1;

    final result = await ApiClient.instance.get(
      'threads/recommend',
      query: {
        'page': nextPage,
        'page_size': 20,
        'channel': channel,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final raw = data['list'];

      setState(() {
        page = nextPage;
        hasMore = data['has_more'] == true;
        threads.addAll(
          raw is List
              ? raw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : [],
        );
        loadingMore = false;
      });
    } else {
      setState(() {
        loadingMore = false;
      });
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 500) {
      _loadMore();
    }

    return false;
  }

  void _switchChannel(String newChannel) {
    if (channel == newChannel) return;
    setState(() {
      channel = newChannel;
      loading = true;
      threads.clear();
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: LoadingView(),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('获嘉一中论坛'),
        ),
        body: ErrorView(
          message: error!,
          onRetry: _refresh,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            context.push('/search');
          },
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 19,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  '搜索帖子、标签',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 44,
                color: Colors.white,
                child: Row(
                  children: [
                    for (final ch in _channels)
                      _ChannelTab(
                        label: ch['label']!,
                        selected: channel == ch['key'],
                        onTap: () => _switchChannel(ch['key']!),
                      ),
                  ],
                ),
              ),
            ),
            CupertinoSliverRefreshControl(
              refreshTriggerPullDistance: 90,
              refreshIndicatorExtent: 62,
              onRefresh: _refresh,
              builder: (
                context,
                refreshState,
                pulledExtent,
                refreshTriggerPullDistance,
                refreshIndicatorExtent,
              ) {
                final progress =
                    (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);

                return Center(
                  child: refreshState == RefreshIndicatorMode.refresh ||
                          refreshState == RefreshIndicatorMode.armed
                      ? const CupertinoActivityIndicator(radius: 12)
                      : Opacity(
                          opacity: progress,
                          child: const Text(
                            '下拉刷新',
                            style: TextStyle(
                              color: Color(0xFFFB7299),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                );
              },
            ),
            if (threads.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('暂无内容'),
                ),
              )
            else
              ThreadWaterfallSliver(threads: threads),
            SliverToBoxAdapter(
              child: loadingMore
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 90),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const SizedBox(height: 90),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? const Color(0xFF222222) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFB7299) : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
