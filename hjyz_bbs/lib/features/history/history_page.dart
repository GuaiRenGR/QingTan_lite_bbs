import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/safe_network_image.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool loading = true;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final result = await ApiClient.instance.get(
      'history/list',
      query: {'page': 1, 'page_size': 100},
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final list = data['list'];
      if (list is List) {
        final uniqueItems = <int, Map<String, dynamic>>{};
        for (final rawItem in list.whereType<Map>()) {
          final item = Map<String, dynamic>.from(rawItem);
          final id = _toInt(item['thread_id'] ?? item['id']);
          if (id > 0) uniqueItems.putIfAbsent(id, () => item);
        }
        items = uniqueItems.values.toList();
      }
    }

    setState(() => loading = false);
  }

  Future<void> _delete(int threadId) async {
    final result = await ApiClient.instance.post(
      'history/delete',
      data: {'thread_id': threadId},
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        items.removeWhere((e) => _toInt(e['thread_id'] ?? e['id']) == threadId);
      });
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有浏览历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ApiClient.instance.post('history/clear');
    if (!mounted) return;

    if (result.success) {
      setState(() => items = []);
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览历史'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: '清空',
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: loading
          ? const LoadingView()
          : items.isEmpty
              ? const Center(child: Text('暂无浏览记录'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _HistoryItem(
                      item: item,
                      onTap: () {
                        final id = _toInt(item['thread_id'] ?? item['id']);
                        if (id > 0) context.push('/thread/$id');
                      },
                      onDelete: () {
                        final id = _toInt(item['thread_id'] ?? item['id']);
                        if (id > 0) _delete(id);
                      },
                    );
                  },
                ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryItem({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cover = item['cover']?.toString() ?? '';

    return Dismissible(
      key: ValueKey(item['thread_id'] ?? item['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade100,
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Card(
        elevation: 0,
        color: AppColors.card(context),
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          onTap: onTap,
          leading: cover.isNotEmpty
              ? SafeNetworkImage(
                  url: cover,
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.circular(8),
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.article_outlined, color: Colors.grey.shade400),
                ),
          title: Text(
            item['title']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '查看于 ${formatHistoryViewedAt(
              item['last_viewed_at']?.toString() ??
                  item['viewed_at']?.toString() ??
                  '',
            )}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
        ),
      ),
    );
  }
}

String formatHistoryViewedAt(String value) {
  var viewedAt = DateTime.tryParse(value.trim());
  if (viewedAt == null) return value;
  if (viewedAt.isUtc) viewedAt = viewedAt.toLocal();

  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${viewedAt.year}-${twoDigits(viewedAt.month)}-'
      '${twoDigits(viewedAt.day)} ${twoDigits(viewedAt.hour)}:'
      '${twoDigits(viewedAt.minute)}';
}
