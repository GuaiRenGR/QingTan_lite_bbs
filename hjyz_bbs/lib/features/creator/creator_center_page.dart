import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_view.dart';

class CreatorCenterPage extends StatefulWidget {
  const CreatorCenterPage({super.key});

  @override
  State<CreatorCenterPage> createState() => _CreatorCenterPageState();
}

class _CreatorCenterPageState extends State<CreatorCenterPage> {
  bool loading = true;

  Map<String, dynamic> totalStats = {};
  Map<String, dynamic> yesterdayStats = {};
  List<Map<String, dynamic>> last7Days = [];
  List<Map<String, dynamic>> threads = [];

  int _rangeIndex = 0; // 0=全部, 1=近7天, 2=昨日

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

    if (summaryResult.success && summaryResult.data is Map) {
      final data = summaryResult.data as Map;
      final total = data['total'];
      if (total is Map) {
        totalStats = Map<String, dynamic>.from(total);
      }
      final yesterday = data['yesterday'];
      if (yesterday is Map) {
        yesterdayStats = Map<String, dynamic>.from(yesterday);
      }
      final l7 = data['last_7_days'];
      if (l7 is List) {
        last7Days = l7
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    if (threadsResult.success && threadsResult.data is Map) {
      final data = threadsResult.data as Map;
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

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, int> get _currentStats {
    if (_rangeIndex == 2) {
      // 昨日
      return {
        'threads': 0,
        'views': _toInt(yesterdayStats['view_count']),
        'likes': _toInt(yesterdayStats['like_count']),
        'favorites': _toInt(yesterdayStats['favorite_count']),
        'replies': _toInt(yesterdayStats['reply_count']),
        'shares': _toInt(yesterdayStats['share_count']),
      };
    }

    if (_rangeIndex == 1) {
      // 近7天
      int views = 0, likes = 0, favs = 0, replies = 0, shares = 0;
      for (final d in last7Days) {
        views += _toInt(d['view_count']);
        likes += _toInt(d['like_count']);
        favs += _toInt(d['favorite_count']);
        replies += _toInt(d['reply_count']);
        shares += _toInt(d['share_count']);
      }
      return {
        'threads': 0,
        'views': views,
        'likes': likes,
        'favorites': favs,
        'replies': replies,
        'shares': shares,
      };
    }

    // 全部
    return {
      'threads': _toInt(totalStats['thread_count']),
      'views': _toInt(totalStats['view_count']),
      'likes': _toInt(totalStats['like_count']),
      'favorites': _toInt(totalStats['favorite_count']),
      'replies': _toInt(totalStats['reply_count']),
      'shares': _toInt(totalStats['share_count']),
    };
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
                  // 时间范围选择
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        _RangeTab(
                          label: '全部',
                          selected: _rangeIndex == 0,
                          onTap: () => setState(() => _rangeIndex = 0),
                        ),
                        _RangeTab(
                          label: '近7天',
                          selected: _rangeIndex == 1,
                          onTap: () => setState(() => _rangeIndex = 1),
                        ),
                        _RangeTab(
                          label: '昨日',
                          selected: _rangeIndex == 2,
                          onTap: () => setState(() => _rangeIndex = 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StatsGrid(stats: _currentStats),
                  const SizedBox(height: 14),
                  // 近7天趋势图（仅近7天模式显示）
                  if (_rangeIndex == 1 && last7Days.isNotEmpty) ...[
                    _TrendChart(data: last7Days),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '我的帖子',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${threads.length} 篇',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (threads.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          '暂无帖子',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  else
                    for (final t in threads) _ThreadStatItem(thread: t),
                ],
              ),
            ),
    );
  }
}

class _RangeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFB7299) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, int> stats;

  const _StatsGrid({required this.stats});

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ('帖子', stats['threads'] ?? 0),
      ('浏览', stats['views'] ?? 0),
      ('点赞', stats['likes'] ?? 0),
      ('收藏', stats['favorites'] ?? 0),
      ('评论', stats['replies'] ?? 0),
      ('分享', stats['shares'] ?? 0),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
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
}

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _TrendChart({required this.data});

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final views = data.map((d) => _toInt(d['view_count'])).toList();
    final maxView = views.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '近7天浏览趋势',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < data.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${views[i]}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: maxView > 0
                            ? (views[i] / maxView) * 60 + 4
                            : 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB7299).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (data[i]['date']?.toString() ?? '').substring(5),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < data.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
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
    final threadId = _toInt(thread['id']);

    return GestureDetector(
      onTap: threadId > 0 ? () => context.push('/thread/$threadId') : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card(context),
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
                _stat(Icons.remove_red_eye_outlined,
                    _toInt(thread['view_count'])),
                const SizedBox(width: 16),
                _stat(Icons.favorite_border, _toInt(thread['like_count'])),
                const SizedBox(width: 16),
                _stat(Icons.star_border, _toInt(thread['favorite_count'])),
                const SizedBox(width: 16),
                _stat(Icons.chat_bubble_outline,
                    _toInt(thread['reply_count'])),
              ],
            ),
          ],
        ),
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
