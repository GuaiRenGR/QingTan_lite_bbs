import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../thread/widgets/thread_waterfall_grid.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  bool searching = false;
  bool loadingHot = true;
  List<Map<String, dynamic>> results = [];
  List<Map<String, dynamic>> hotKeywords = [];

  @override
  void initState() {
    super.initState();
    _loadHot();
  }

  Future<void> _loadHot() async {
    final result = await ApiClient.instance.get('search/hot');

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final raw = data['list'];
      hotKeywords = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    }

    setState(() => loadingHot = false);
  }

  Future<void> _doSearch() async {
    final keyword = controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() => searching = true);

    final result = await ApiClient.instance.get(
      'search/threads',
      query: {'keyword': keyword, 'page': 1, 'page_size': 50},
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final list = data['list'];
      if (list is List) {
        results = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        results = [];
      }
    } else {
      results = [];
    }

    setState(() => searching = false);
  }

  void _onTapHot(String keyword) {
    controller.text = keyword;
    _doSearch();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _doSearch(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索帖子、标签',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        controller.clear();
                        setState(() => results = []);
                      },
                    )
                  : null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _doSearch,
            child: const Text('搜索'),
          ),
        ],
      ),
      body: searching
          ? const Center(child: CircularProgressIndicator())
          : hasQuery && results.isNotEmpty
              ? ThreadWaterfallGrid(threads: results)
              : hasQuery
                  ? Center(
                      child: Text(
                        '未找到相关帖子',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : _buildHotSearch(),
    );
  }

  Widget _buildHotSearch() {
    if (loadingHot) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (hotKeywords.isEmpty) {
      return Center(
        child: Text(
          '输入关键词搜索',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '热搜榜',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < hotKeywords.length; i++)
          _HotItem(
            rank: i + 1,
            keyword: hotKeywords[i]['keyword']?.toString() ?? '',
            count: hotKeywords[i]['count'] ?? 0,
            onTap: () => _onTapHot(
              hotKeywords[i]['keyword']?.toString() ?? '',
            ),
          ),
      ],
    );
  }
}

class _HotItem extends StatelessWidget {
  final int rank;
  final String keyword;
  final dynamic count;
  final VoidCallback onTap;

  const _HotItem({
    required this.rank,
    required this.keyword,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isTop3 ? const Color(0xFFFB7299) : Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                keyword,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isTop3 ? FontWeight.w600 : FontWeight.w400,
                  color: isTop3 ? const Color(0xFF222222) : Colors.grey.shade700,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
