import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/safe_network_image.dart';
import 'widgets/forum_content_view.dart';
import 'widgets/xhs_image_pager.dart';

class ThreadDetailPage extends StatefulWidget {
  final int threadId;

  const ThreadDetailPage({
    super.key,
    required this.threadId,
  });

  @override
  State<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<ThreadDetailPage> {
  bool loading = true;
  bool actionLoading = false;
  String? error;

  Map<String, dynamic>? thread;
  List<Map<String, dynamic>> posts = [];

  final commentController = TextEditingController();
  final commentFocus = FocusNode();

  Map<String, dynamic>? _replyTo; // 正在回复的评论

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    commentController.dispose();
    commentFocus.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  List<String> _images(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<void> _load() async {
    setState(() {
      loading = thread == null;
      error = null;
    });

    final result = await ApiClient.instance.get(
      'threads/detail',
      query: {
        'id': widget.threadId,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;

      final rawPosts = data['posts'];

      setState(() {
        thread = Map<String, dynamic>.from(data['thread'] as Map);
        posts = rawPosts is List
            ? rawPosts
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
        loading = false;
      });
    } else {
      setState(() {
        error = result.message;
        loading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final data = thread;
    if (data == null || actionLoading) return;

    final isLiked = data['is_liked'] == true;

    setState(() {
      actionLoading = true;
    });

    final result = await ApiClient.instance.post(
      isLiked ? 'threads/unlike' : 'threads/like',
      data: {
        'thread_id': widget.threadId,
      },
    );

    if (!mounted) return;

    setState(() {
      actionLoading = false;
    });

    if (result.success && result.data is Map<String, dynamic>) {
      final res = result.data as Map<String, dynamic>;
      setState(() {
        thread!['is_liked'] = res['is_liked'] == true;
        thread!['like_count'] = _toInt(res['like_count']);
      });
    } else {
      _toast(result.message);
    }
  }

  Future<void> _toggleFavorite() async {
    final data = thread;
    if (data == null || actionLoading) return;

    final isFavorited = data['is_favorited'] == true;

    setState(() {
      actionLoading = true;
    });

    final result = await ApiClient.instance.post(
      isFavorited ? 'threads/unfavorite' : 'threads/favorite',
      data: {
        'thread_id': widget.threadId,
      },
    );

    if (!mounted) return;

    setState(() {
      actionLoading = false;
    });

    if (result.success && result.data is Map<String, dynamic>) {
      final res = result.data as Map<String, dynamic>;
      setState(() {
        thread!['is_favorited'] = res['is_favorited'] == true;
        thread!['favorite_count'] = _toInt(res['favorite_count']);
      });
    } else {
      _toast(result.message);
    }
  }

  Future<void> _shareThread() async {
    final result = await ApiClient.instance.post(
      'threads/share',
      data: {
        'thread_id': widget.threadId,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      final url = data['share_url']?.toString() ?? '';

      if (url.isNotEmpty) {
        Share.share(url);
      }

      setState(() {
        thread!['share_count'] = _toInt(thread!['share_count']) + 1;
      });
    } else {
      _toast(result.message);
    }
  }

  Future<void> _togglePostLike(Map<String, dynamic> post) async {
    final postId = _toInt(post['id']);
    if (postId <= 0) return;

    final isLiked = post['is_liked'] == true;

    final result = await ApiClient.instance.post(
      isLiked ? 'posts/unlike' : 'posts/like',
      data: {
        'post_id': postId,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map) {
      final res = result.data as Map<String, dynamic>;
      setState(() {
        final idx = posts.indexWhere((p) => _toInt(p['id']) == postId);
        if (idx >= 0) {
          posts[idx]['is_liked'] = res['is_liked'] == true;
          posts[idx]['like_count'] = _toInt(res['like_count']);
        }
      });
    } else {
      _toast(result.message);
    }
  }

  void _startReply(Map<String, dynamic> post) {
    final author = post['author'];
    final nickname =
        (author is Map ? author['nickname']?.toString() : null) ?? '用户';

    setState(() {
      _replyTo = post;
    });

    commentController.text = '回复@$nickname：';
    commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: commentController.text.length),
    );
    commentFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyTo = null;
    });
    commentController.clear();
  }

  Future<void> _sendComment() async {
    final content = commentController.text.trim();

    if (content.isEmpty) {
      _toast('请输入评论内容');
      return;
    }

    final parentId = _replyTo != null ? _toInt(_replyTo!['id']) : 0;

    final result = await ApiClient.instance.post(
      'posts/create',
      data: {
        'thread_id': widget.threadId,
        'content': content,
        if (parentId > 0) 'parent_id': parentId,
      },
    );

    if (!mounted) return;

    if (result.success) {
      commentController.clear();
      setState(() {
        _replyTo = null;
      });
      await _load();
    } else {
      _toast(result.message);
    }
  }

  void _toast(String message) {
    if (message.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteThread() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除帖子'),
          content: const Text('确定要删除这个帖子吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final result = await ApiClient.instance.post(
      'threads/delete',
      data: {
        'thread_id': widget.threadId,
      },
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (result.success) {
      context.go('/');
    }
  }

  Future<void> _reportThread() async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('举报'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '请输入举报原因',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('提交'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    final result = await ApiClient.instance.post(
      'threads/report',
      data: {
        'thread_id': widget.threadId,
        'reason': reason,
      },
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
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
        appBar: AppBar(),
        body: ErrorView(
          message: error!,
          onRetry: _load,
        ),
      );
    }

    final data = thread ?? {};

    return Scaffold(
      appBar: AppBar(
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.go('/');
                },
              ),
        title: Text(
          data['title']?.toString() ?? '帖子详情',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                final changed = await context.push<bool>(
                  '/thread/${widget.threadId}/edit',
                );

                if (changed == true) {
                  _load();
                }
              } else if (value == 'delete') {
                _deleteThread();
              } else if (value == 'report') {
                _reportThread();
              }
            },
            itemBuilder: (context) {
              final isOwner = data['is_owner'] == true;

              return [
                if (isOwner)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('编辑'),
                  ),
                if (isOwner)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除'),
                  ),
                const PopupMenuItem(
                  value: 'report',
                  child: Text('举报'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  14,
                  data['mode']?.toString() == 'image' &&
                          _images(data['images']).isNotEmpty
                      ? 0
                      : 12,
                  14,
                  100,
                ),
                children: [
                  if (data['mode']?.toString() == 'image' &&
                      _images(data['images']).isNotEmpty)
                    XhsImagePager(images: _images(data['images'])),
                  _ThreadMainCard(
                    thread: data,
                    canViewHidden: data['can_view_hidden'] == true,
                    onAuthorTap: () {
                      final author = data['author'];

                      if (author is Map) {
                        final uid = _toInt(author['id']);
                        if (uid > 0) {
                          context.push('/user/$uid');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _CommentHeader(count: posts.length),
                  const SizedBox(height: 8),
                  for (final post in posts)
                    _CommentItem(
                      post: post,
                      onUserTap: () {
                        final author = post['author'];

                        if (author is Map) {
                          final uid = _toInt(author['id']);
                          if (uid > 0) {
                            context.push('/user/$uid');
                          }
                        }
                      },
                      onLike: () => _togglePostLike(post),
                      onReply: () => _startReply(post),
                    ),
                ],
              ),
            ),
          ),
          _BottomActionBar(
            controller: commentController,
            focusNode: commentFocus,
            thread: data,
            replyTo: _replyTo,
            onCancelReply: _cancelReply,
            onLike: _toggleLike,
            onFavorite: _toggleFavorite,
            onShare: _shareThread,
            onSend: _sendComment,
          ),
        ],
      ),
    );
  }
}

class _ThreadMainCard extends StatelessWidget {
  final Map<String, dynamic> thread;
  final VoidCallback onAuthorTap;
  final bool canViewHidden;

  const _ThreadMainCard({
    required this.thread,
    required this.onAuthorTap,
    this.canViewHidden = false,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final author = thread['author'];
    final authorMap = author is Map ? author : {};

    final title = thread['title']?.toString() ?? '';
    final content = thread['content']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAuthorTap,
            child: Row(
              children: [
                SafeNetworkImage(
                  url: authorMap['avatar']?.toString() ?? '',
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(20),
                  errorWidget: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    child: Icon(
                      Icons.person,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    authorMap['nickname']?.toString() ?? '用户',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_toInt(thread['view_count'])} 浏览',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ForumContentView(
            content: content,
            canViewHidden: canViewHidden,
          ),
          const SizedBox(height: 8),
          Text(
            thread['created_at']?.toString() ?? '',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}


class _CommentHeader extends StatelessWidget {
  final int count;

  const _CommentHeader({
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '评论 $count',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onUserTap;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CommentItem({
    required this.post,
    required this.onUserTap,
    required this.onLike,
    required this.onReply,
  });

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final author = post['author'];
    final authorMap = author is Map ? author : {};
    final isLiked = post['is_liked'] == true;
    final likeCount = _toInt(post['like_count']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onUserTap,
            child: SafeNetworkImage(
              url: authorMap['avatar']?.toString() ?? '',
              width: 34,
              height: 34,
              borderRadius: BorderRadius.circular(17),
              errorWidget: CircleAvatar(
                radius: 17,
                backgroundColor: Colors.grey.shade200,
                child: Icon(
                  Icons.person,
                  color: Colors.grey.shade500,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onUserTap,
                  child: Text(
                    authorMap['nickname']?.toString() ?? '用户',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ForumContentView(
                  content: post['content']?.toString() ?? '',
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${post['floor'] ?? 1}楼 · ${post['created_at'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    // 回复按钮
                    GestureDetector(
                      onTap: onReply,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '回复',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 点赞按钮
                    GestureDetector(
                      onTap: onLike,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 14,
                              color: isLiked
                                  ? const Color(0xFFFB7299)
                                  : Colors.grey.shade500,
                            ),
                            if (likeCount > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '$likeCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isLiked
                                      ? const Color(0xFFFB7299)
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Map<String, dynamic> thread;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onCancelReply;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onSend;

  const _BottomActionBar({
    required this.controller,
    required this.focusNode,
    required this.thread,
    this.replyTo,
    this.onCancelReply,
    required this.onLike,
    required this.onFavorite,
    required this.onShare,
    required this.onSend,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final liked = thread['is_liked'] == true;
    final favorited = thread['is_favorited'] == true;
    final hasReply = replyTo != null;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 回复指示条
          if (hasReply)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '回复 @${replyTo!['author']?['nickname'] ?? '用户'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: hasReply ? '回复评论...' : '说点什么...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                  color: const Color(0xFFFB7299),
                ),
                _ActionIcon(
                  icon: liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: liked ? const Color(0xFFFB7299) : Colors.grey.shade700,
                  text: '${_toInt(thread['like_count'])}',
                  onTap: onLike,
                ),
                _ActionIcon(
                  icon: favorited
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: favorited ? Colors.orange : Colors.grey.shade700,
                  text: '${_toInt(thread['favorite_count'])}',
                  onTap: onFavorite,
                ),
                _ActionIcon(
                  icon: Icons.ios_share_rounded,
                  color: Colors.grey.shade700,
                  text: '${_toInt(thread['share_count'])}',
                  onTap: onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 21,
            ),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
