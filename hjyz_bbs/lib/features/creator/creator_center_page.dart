import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/loading_view.dart';

class CreatorCenterPage extends StatefulWidget {
  const CreatorCenterPage({super.key});

  @override
  State<CreatorCenterPage> createState() => _CreatorCenterPageState();
}

class _CreatorCenterPageState extends State<CreatorCenterPage> {
  bool loading = true;
  Map<String, dynamic>? summary;
  List<Map<String, dynamic>> threads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final summaryResult = await ApiClient.instance.get('creator/summary');
    final threadsResult = await ApiClient.instance.get(
      'creator/threads',
      query: {'page': 1, 'page_size': 50},
    );

    if (!mounted) return;

    if (summaryResult.success && summaryResult.data is Map<String, dynamic>) {
      summary = summaryResult.data as Map<String, dynamic>;
    }

    if (threadsResult.success && threadsResult.data is Map<String, dynamic>) {
      final data = threadsResult.data as Map<String, dynamic>;
      final list = data['list'];
      if (list is List) {
        threads = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创作中心')),
      body: loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _StatsGrid(summary: summary),
                  const SizedBox(height: 14),
                  const Text(
                    '我的帖子',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final t in threads) _ThreadStatItem(thread: t),
                ],
              ),
            ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic>? summary;

  const _StatsGrid({required this.summary});

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final s = summary ?? {};

    final totalViews = _toInt(s['total_views']);
    final totalLikes = _toInt(s['total_likes']);
    final totalFavorites = _toInt(s['total_favorites']);
    final totalReplies = _toInt(s['total_replies']);
    final totalShares = _toInt(s['total_shares']);
    final totalThreads = _toInt(s['total_threads']);

    final items = [
      ('帖子', totalThreads),
      ('浏览', totalViews),
      ('点赞', totalLikes),
      ('收藏', totalFavorites),
      ('评论', totalReplies),
      ('分享', totalShares),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 14,
        children: [
          for (final (label, value) in items)
            SizedBox(
              width: (MediaQuery.of(context).size.width - 68) / 3,
              child: Column(
                children: [
                  Text(
                    _formatCount(value),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFB7299),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return '$n';
  }
}

class _ThreadStatItem extends StatelessWidget {
  final Map<String, dynamic> thread;

  const _ThreadStatItem({required this.thread});

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            thread['title']?.toString() ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stat(Icons.remove_red_eye_outlined, _toInt(thread['view_count'])),
              const SizedBox(width: 16),
              _stat(Icons.favorite_border, _toInt(thread['like_count'])),
              const SizedBox(width: 16),
              _stat(Icons.star_border, _toInt(thread['favorite_count'])),
              const SizedBox(width: 16),
              _stat(Icons.chat_bubble_outline, _toInt(thread['reply_count'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
