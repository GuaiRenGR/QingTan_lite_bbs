import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
        shape: const CircleBorder(),
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
                      final item = items[index];
                      return _XFeedItem(
                        key: ValueKey(item['id']),
                        item: item,
                      );
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

class _XFeedItem extends StatefulWidget {
  final Map<String, dynamic> item;

  const _XFeedItem({super.key, required this.item});

  @override
  State<_XFeedItem> createState() => _XFeedItemState();
}

class _XFeedItemState extends State<_XFeedItem> {
  late bool _liked;
  late int _likeCount;
  late int _shareCount;
  bool _actionLoading = false;

  Map<String, dynamic> get item => widget.item;

  @override
  void initState() {
    super.initState();
    _readItemState();
  }

  @override
  void didUpdateWidget(covariant _XFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) _readItemState();
  }

  void _readItemState() {
    _liked = item['is_liked'] == true;
    _likeCount = _number('like_count');
    _shareCount = _number('share_count');
  }

  int _number(String key) => int.tryParse(item[key]?.toString() ?? '') ?? 0;

  Future<void> _toggleLike() async {
    final id = _number('id');
    if (id <= 0 || _actionLoading) return;
    setState(() => _actionLoading = true);
    final result = await ApiClient.instance.post(
      _liked ? 'threads/unlike' : 'threads/like',
      data: {'thread_id': id},
    );
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (result.success && result.data is Map) {
      final data = result.data as Map;
      setState(() {
        _liked = data['is_liked'] == true;
        _likeCount = int.tryParse(data['like_count']?.toString() ?? '') ?? 0;
        item['is_liked'] = _liked;
        item['like_count'] = _likeCount;
      });
      return;
    }
    _showMessage(result.message);
  }

  Future<void> _shareThread({required bool openShareSheet}) async {
    final id = _number('id');
    if (id <= 0 || _actionLoading) return;
    setState(() => _actionLoading = true);
    final result = await ApiClient.instance.post(
      'threads/share',
      data: {'thread_id': id},
    );
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (!result.success || result.data is! Map) {
      _showMessage(result.message);
      return;
    }
    final data = result.data as Map;
    final url = data['share_url']?.toString() ?? '';
    setState(() {
      _shareCount++;
      item['share_count'] = _shareCount;
    });
    if (openShareSheet && url.isNotEmpty) {
      await Share.share(url);
    } else {
      _showMessage('已转发');
    }
  }

  void _showMessage(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = _number('id');
    final author = item['author_name']?.toString() ?? '用户';
    final avatar = item['author_avatar']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    final summary = item['summary']?.toString() ?? '';
    final cover = item['cover']?.toString() ?? '';
    final username = item['author_username']?.toString().trim() ?? '';
    final createdAt = formatXFeedTime(item['created_at']?.toString() ?? '');

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
              borderRadius: BorderRadius.circular(6),
              errorWidget: Container(
                width: 42,
                height: 42,
                color: AppColors.inputFill(context),
                alignment: Alignment.center,
                child: const Icon(Icons.person_outline_rounded),
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
                          '${username.isEmpty ? '@用户' : '@$username'} · $createdAt',
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
                    _ExpandableFeedText(
                      title,
                      maxLines: 2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _ExpandableFeedText(
                      summary,
                      maxLines: 4,
                      style: const TextStyle(height: 1.35),
                    ),
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
                        tooltip: '回复',
                        onTap: id > 0
                            ? () => context.push('/thread/$id?reply=1')
                            : null,
                      ),
                      _Metric(
                        Icons.repeat_rounded,
                        _shareCount,
                        tooltip: '转发',
                        onTap: _actionLoading
                            ? null
                            : () => _shareThread(openShareSheet: false),
                      ),
                      _Metric(
                        _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        _likeCount,
                        tooltip: _liked ? '取消点赞' : '点赞',
                        active: _liked,
                        onTap: _actionLoading ? null : _toggleLike,
                      ),
                      _Metric(
                        Icons.bar_chart_rounded,
                        _number('view_count'),
                        tooltip: '浏览量',
                      ),
                      _Metric(
                        Icons.ios_share_rounded,
                        0,
                        tooltip: '分享',
                        onTap: _actionLoading
                            ? null
                            : () => _shareThread(openShareSheet: true),
                      ),
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
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  const _Metric(
    this.icon,
    this.value, {
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : AppColors.textSecondary(context);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              if (value > 0) ...[
                const SizedBox(width: 4),
                Text('$value', style: TextStyle(fontSize: 12, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandableFeedText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;

  const _ExpandableFeedText(
    this.text, {
    required this.maxLines,
    this.style,
  });

  @override
  State<_ExpandableFeedText> createState() => _ExpandableFeedTextState();
}

class _ExpandableFeedTextState extends State<_ExpandableFeedText> {
  late final TapGestureRecognizer _moreRecognizer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _moreRecognizer = TapGestureRecognizer()
      ..onTap = () => setState(() => _expanded = true);
  }

  @override
  void didUpdateWidget(covariant _ExpandableFeedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  void dispose() {
    _moreRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    if (_expanded) return Text(widget.text, style: style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullPainter = _painter(context, widget.text, style);
        fullPainter.layout(maxWidth: constraints.maxWidth);
        if (!fullPainter.didExceedMaxLines) {
          return Text(widget.text, style: style);
        }

        const suffix = '… 显示更多';
        var low = 0;
        var high = widget.text.length;
        while (low < high) {
          final middle = (low + high + 1) ~/ 2;
          final candidate = '${widget.text.substring(0, middle).trimRight()}$suffix';
          final painter = _painter(context, candidate, style)
            ..layout(maxWidth: constraints.maxWidth);
          if (painter.didExceedMaxLines) {
            high = middle - 1;
          } else {
            low = middle;
          }
        }

        if (low > 0 &&
            low < widget.text.length &&
            widget.text.codeUnitAt(low) >= 0xDC00 &&
            widget.text.codeUnitAt(low) <= 0xDFFF) {
          low--;
        }
        final visible = widget.text.substring(0, low).trimRight();
        return Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: '$visible… '),
              TextSpan(
                text: '显示更多',
                style: const TextStyle(color: Color(0xFF1D9BF0)),
                recognizer: _moreRecognizer,
              ),
            ],
          ),
          maxLines: widget.maxLines,
          overflow: TextOverflow.clip,
        );
      },
    );
  }

  TextPainter _painter(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }
}

String formatXFeedTime(String value, {DateTime? now}) {
  var createdAt = DateTime.tryParse(value.trim());
  if (createdAt == null) return value;
  if (createdAt.isUtc) createdAt = createdAt.toLocal();

  final current = now ?? DateTime.now();
  var difference = current.difference(createdAt);
  if (difference.isNegative) difference = Duration.zero;
  final isToday = current.year == createdAt.year &&
      current.month == createdAt.month &&
      current.day == createdAt.day;

  if (isToday) {
    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inHours < 1) return '${difference.inMinutes}分钟';
    return '${difference.inHours}小时';
  }
  if (difference < const Duration(days: 3)) {
    return '${difference.inDays < 1 ? 1 : difference.inDays}天';
  }

  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${createdAt.year}-${twoDigits(createdAt.month)}-'
      '${twoDigits(createdAt.day)} ${twoDigits(createdAt.hour)}:'
      '${twoDigits(createdAt.minute)}';
}
