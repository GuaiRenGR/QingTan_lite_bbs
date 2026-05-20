import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
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
  final audioPlayer = AudioPlayer();

  bool musicPlaying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    commentController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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

  Future<void> _sendComment() async {
    final content = commentController.text.trim();

    if (content.isEmpty) {
      _toast('请输入评论内容');
      return;
    }

    final result = await ApiClient.instance.post(
      'posts/create',
      data: {
        'thread_id': widget.threadId,
        'content': content,
      },
    );

    if (!mounted) return;

    if (result.success) {
      commentController.clear();
      await _load();
    } else {
      _toast(result.message);
    }
  }

  Future<void> _toggleMusic() async {
    final data = thread;
    if (data == null) return;

    final url = data['music_url']?.toString() ?? '';

    if (url.isEmpty) return;

    if (musicPlaying) {
      await audioPlayer.pause();
      setState(() {
        musicPlaying = false;
      });
      return;
    }

    try {
      await audioPlayer.setUrl(url);
      await audioPlayer.play();

      setState(() {
        musicPlaying = true;
      });

      audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            musicPlaying = false;
          });
        }
      });
    } catch (e) {
      _toast('音乐播放失败');
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                children: [
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
                    onMusicTap: _toggleMusic,
                    musicPlaying: musicPlaying,
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
                    ),
                ],
              ),
            ),
          ),
          _BottomActionBar(
            controller: commentController,
            thread: data,
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
  final VoidCallback onMusicTap;
  final bool musicPlaying;
  final bool canViewHidden;

  const _ThreadMainCard({
    required this.thread,
    required this.onAuthorTap,
    required this.onMusicTap,
    required this.musicPlaying,
    this.canViewHidden = false,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
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

  @override
  Widget build(BuildContext context) {
    final author = thread['author'];
    final authorMap = author is Map ? author : {};

    final mode = thread['mode']?.toString() ?? 'article';
    final title = thread['title']?.toString() ?? '';
    final content = thread['content']?.toString() ?? '';
    final images = _images(thread['images']);
    final musicUrl = thread['music_url']?.toString() ?? '';
    final musicName = thread['music_name']?.toString() ?? '';

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
          if (mode == 'image' && images.isNotEmpty) ...[
            XhsImagePager(images: images),
            const SizedBox(height: 14),
          ],
          if (musicUrl.isNotEmpty) ...[
            _MusicCard(
              name: musicName.isEmpty ? '帖子音乐' : musicName,
              playing: musicPlaying,
              onTap: onMusicTap,
            ),
            const SizedBox(height: 14),
          ],
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


class _MusicCard extends StatelessWidget {
  final String name;
  final bool playing;
  final VoidCallback onTap;

  const _MusicCard({
    required this.name,
    required this.playing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: const Color(0xFFFB7299),
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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

  const _CommentItem({
    required this.post,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final author = post['author'];
    final authorMap = author is Map ? author : {};

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
                Text(
                  '${post['floor'] ?? 1}楼 · ${post['created_at'] ?? ''}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
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

class _BottomActionBar extends StatelessWidget {
  final TextEditingController controller;
  final Map<String, dynamic> thread;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onSend;

  const _BottomActionBar({
    required this.controller,
    required this.thread,
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

    return SafeArea(
      top: false,
      child: Container(
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
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '说点什么...',
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
