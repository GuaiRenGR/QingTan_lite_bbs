import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../thread/widgets/thread_waterfall_grid.dart';

class HomeFeedPage extends StatefulWidget {
  final String type;
  final ValueChanged<VoidCallback>? onRefreshReady;

  const HomeFeedPage({
    super.key,
    required this.type,
    this.onRefreshReady,
  });

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage>
    with AutomaticKeepAliveClientMixin {
  bool loading = true;
  bool loadingMore = false;
  String? error;

  int page = 1;
  bool hasMore = true;

  final List<Map<String, dynamic>> threads = [];
  final Set<int> _loadedIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.onRefreshReady?.call(silentRefresh);
  }

  String get endpoint {
    if (widget.type == 'recommend') {
      return 'threads/recommend';
    }

    return 'threads/recommend';
  }

  Map<String, dynamic> queryForPage(int page) {
    return {
      'page': page,
      'page_size': 20,
      'channel': widget.type,
      if (_loadedIds.isNotEmpty) 'exclude_ids': _loadedIds.toList(),
    };
  }

  Future<void> _refresh() async {
    final result = await ApiClient.instance.get(
      endpoint,
      query: queryForPage(1),
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final raw = data['list'];

      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        page = 1;
        hasMore = data['has_more'] == true;
        threads
          ..clear()
          ..addAll(list);
        _loadedIds
          ..clear()
          ..addAll(list.map((e) => (e['id'] as num).toInt()));
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

  Future<void> silentRefresh() async {
    final result = await ApiClient.instance.get(
      endpoint,
      query: queryForPage(1),
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final raw = data['list'];

      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        page = 1;
        hasMore = data['has_more'] == true;
        threads
          ..clear()
          ..addAll(list);
        _loadedIds
          ..clear()
          ..addAll(list.map((e) => (e['id'] as num).toInt()));
        error = null;
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
      endpoint,
      query: queryForPage(nextPage),
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final raw = data['list'];

      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        page = nextPage;
        hasMore = data['has_more'] == true;
        final newItems = list
            .where((e) => !_loadedIds.contains((e['id'] as num).toInt()))
            .toList();
        threads.addAll(newItems);
        _loadedIds.addAll(newItems.map((e) => (e['id'] as num).toInt()));
        loadingMore = false;
      });
    } else {
      setState(() {
        loadingMore = false;
      });
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 500) {
      _loadMore();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (loading) {
      return const LoadingView();
    }

    if (error != null) {
      return ErrorView(
        message: error!,
        onRetry: _refresh,
      );
    }

    return RefreshIndicator.adaptive(
      displacement: 48,
      edgeOffset: 0,
      color: const Color(0xFFFB7299),
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
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
                      padding: EdgeInsets.only(bottom: 90, top: 12),
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
