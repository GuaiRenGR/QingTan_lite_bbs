import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../thread/widgets/thread_waterfall_grid.dart';

class DynamicPage extends StatefulWidget {
  const DynamicPage({super.key});

  @override
  State<DynamicPage> createState() => _DynamicPageState();
}

class _DynamicPageState extends State<DynamicPage> {
  bool loading = true;
  bool loadingMore = false;
  String? error;

  int page = 1;
  bool hasMore = true;

  final List<Map<String, dynamic>> threads = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      error = null;
      page = 1;
      hasMore = true;
    });

    final result = await ApiClient.instance.get(
      'threads/following',
      query: {
        'page': 1,
        'page_size': 20,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final rawList = data['list'];

      setState(() {
        threads
          ..clear()
          ..addAll(
            rawList is List
                ? rawList
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
                : [],
          );

        hasMore = data['has_more'] == true;
        loading = false;
      });
    } else {
      setState(() {
        error = result.message;
        loading = false;
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
      'threads/following',
      query: {
        'page': nextPage,
        'page_size': 20,
      },
    );

    if (!mounted) return;

    setState(() {
      loadingMore = false;
    });

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final rawList = data['list'];

      setState(() {
        page = nextPage;
        hasMore = data['has_more'] == true;

        threads.addAll(
          rawList is List
              ? rawList
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : [],
        );
      });
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 500) {
      _loadMore();
    }

    return false;
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
          title: const Text('动态'),
        ),
        body: ErrorView(
          message: error!,
          onRetry: _refresh,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('动态'),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFB7299),
        displacement: 46,
        onRefresh: _refresh,
        child: threads.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(
                    child: Text(
                      '你关注的人还没有发布帖子',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              )
            : NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: ThreadWaterfallGrid(
                  threads: threads,
                  physics: const AlwaysScrollableScrollPhysics(),
                ),
              ),
      ),
    );
  }
}
