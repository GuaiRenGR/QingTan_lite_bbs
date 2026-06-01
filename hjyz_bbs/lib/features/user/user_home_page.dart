import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar_with_verify.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/safe_network_image.dart';
import '../../core/widgets/user_badge.dart';
import '../auth/auth_controller.dart';

class UserHomePage extends ConsumerStatefulWidget {
  final int userId;

  const UserHomePage({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends ConsumerState<UserHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;

  bool loading = true;
  String? error;
  Map<String, dynamic>? profile;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _loadProfile() async {
    if (widget.userId <= 0) {
      setState(() {
        loading = false;
        error = '用户不存在';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    final result = await ApiClient.instance.get(
      'user/profile',
      query: {
        'id': widget.userId,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      setState(() {
        profile = result.data as Map<String, dynamic>;
        loading = false;
      });
    } else {
      setState(() {
        error = result.message;
        loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final data = profile;
    if (data == null) return;

    final auth = ref.read(authControllerProvider);

    if (!auth.loggedIn) {
      context.push('/login');
      return;
    }

    final isSelf = data['is_self'] == true;

    if (isSelf) {
      final updated = await context.push<bool>('/profile/edit');
      if (updated == true) {
        await _loadProfile();
        if (mounted) {
          ref.read(authControllerProvider.notifier).init();
        }
      }
      return;
    }

    final isFollowing = data['is_following'] == true;

    final result = await ApiClient.instance.post(
      isFollowing ? 'user/unfollow' : 'user/follow',
      data: {
        'user_id': widget.userId,
      },
    );

    if (!mounted) return;

    if (result.success) {
      await _loadProfile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
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
          onRetry: _loadProfile,
        ),
      );
    }

    final data = profile ?? {};

    final nickname = data['nickname']?.toString() ?? '用户';
    final username = data['username']?.toString() ?? '';
    final avatar = data['avatar']?.toString() ?? '';
    final bio = data['bio']?.toString() ?? '这个人还没有填写简介';
    final cover = data['space_cover']?.toString() ?? '';
    final badgeName = data['badge_name']?.toString() ?? '';
    final badgeColor = data['badge_color']?.toString() ?? '';
    final verifyLevel = _toInt(data['verify_level']);

    final followers = _toInt(data['followers_count']);
    final following = _toInt(data['following_count']);
    final threadCount = _toInt(data['thread_count']);
    final postCount = _toInt(data['post_count']);
    final favoriteCount = _toInt(data['favorite_count']);

    final isSelf = data['is_self'] == true;
    final isFollowing = data['is_following'] == true;
    final status = _toInt(data['status']);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _UserHeader(
                nickname: nickname,
                username: username,
                avatar: avatar,
                cover: cover,
                bio: bio,
                followers: followers,
                following: following,
                threadCount: threadCount,
                isSelf: isSelf,
                isFollowing: isFollowing,
                onBack: () => Navigator.of(context).pop(),
                onFollowTap: _toggleFollow,
                onMessageTap: isSelf
                    ? null
                    : () {
                        context.push(
                          '/chat?conv_id=0&user_id=${widget.userId}&nickname=${Uri.encodeComponent(nickname)}',
                        );
                      },
                badgeName: badgeName,
                badgeColor: badgeColor,
                verifyLevel: verifyLevel,
              ),
            ),
            if (status == 0)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '该用户已被封禁',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabHeaderDelegate(
                TabBar(
                  controller: tabController,
                  labelColor: const Color(0xFFFB7299),
                  unselectedLabelColor: Colors.grey.shade700,
                  indicatorColor: const Color(0xFFFB7299),
                  indicatorWeight: 3,
                  tabs: [
                    const Tab(text: '主页'),
                    Tab(text: '帖子 $threadCount'),
                    Tab(text: '回复 $postCount'),
                    Tab(text: '收藏 $favoriteCount'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: tabController,
          children: [
            _UserHomeTab(
              bio: bio,
              profile: data,
            ),
            _UserThreadListTab(
              userId: widget.userId,
              type: _UserListType.threads,
            ),
            _UserThreadListTab(
              userId: widget.userId,
              type: _UserListType.posts,
            ),
            _UserThreadListTab(
              userId: widget.userId,
              type: _UserListType.favorites,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final String nickname;
  final String username;
  final String avatar;
  final String cover;
  final String bio;
  final int followers;
  final int following;
  final int threadCount;
  final bool isSelf;
  final bool isFollowing;
  final VoidCallback onBack;
  final VoidCallback onFollowTap;
  final VoidCallback? onMessageTap;
  final String badgeName;
  final String badgeColor;
  final int verifyLevel;

  const _UserHeader({
    required this.nickname,
    required this.username,
    required this.avatar,
    required this.cover,
    required this.bio,
    required this.followers,
    required this.following,
    required this.threadCount,
    required this.isSelf,
    required this.isFollowing,
    required this.onBack,
    required this.onFollowTap,
    this.onMessageTap,
    this.badgeName = '',
    this.badgeColor = '',
    this.verifyLevel = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 21 / 9,
              child: cover.isNotEmpty
                  ? SafeNetworkImage(
                      url: cover,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFFB6C9),
                            Color(0xFFBFD7FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              left: 10,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.black.withValues(alpha: 0.28),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: onBack,
                ),
              ),
            ),
          ],
        ),
        Container(
          color: AppColors.card(context),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            children: [
              Transform.translate(
                offset: const Offset(0, -30),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: AvatarWithVerify(
                        avatarUrl: avatar,
                        size: 82,
                        verifyLevel: verifyLevel,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _CountItem(
                              label: '粉丝',
                              count: followers,
                            ),
                            _CountItem(
                              label: '关注',
                              count: following,
                            ),
                            _CountItem(
                              label: '帖子',
                              count: threadCount,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (badgeName.isNotEmpty)
                          UserBadge(name: badgeName, color: badgeColor),
                        if (!isSelf)
                          IconButton(
                            onPressed: onMessageTap,
                            icon: Icon(
                              Icons.chat_outlined,
                              color: Colors.grey.shade600,
                              size: 22,
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(34, 34),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        if (!isSelf) const SizedBox(width: 4),
                        SizedBox(
                          height: 34,
                          child: FilledButton(
                            onPressed: onFollowTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: isSelf
                                  ? Colors.grey.shade200
                                  : const Color(0xFFFB7299),
                              foregroundColor:
                                  isSelf ? Colors.black87 : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            ),
                            child: Text(
                              isSelf
                                  ? '编辑资料'
                                  : isFollowing
                                      ? '已关注'
                                      : '+ 关注',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      username.isNotEmpty ? '账号：$username' : '社区用户',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountItem extends StatelessWidget {
  final String label;
  final int count;

  const _CountItem({
    required this.label,
    required this.count,
  });

  String _format(int value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _format(count),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabHeaderDelegate(this.tabBar);

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 46,
      color: AppColors.card(context),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}

class _UserHomeTab extends StatelessWidget {
  final String bio;
  final Map<String, dynamic> profile;

  const _UserHomeTab({
    required this.bio,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = profile['created_at']?.toString() ?? '';
    final score = profile['score']?.toString() ?? '0';
    final level = profile['level']?.toString() ?? '1';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '个人简介',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bio,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _InfoRow(label: '等级', value: 'Lv.$level'),
              _InfoRow(label: '积分', value: score),
              if (createdAt.isNotEmpty)
                _InfoRow(label: '加入时间', value: createdAt),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _UserListType {
  threads,
  posts,
  favorites,
}

class _UserThreadListTab extends StatefulWidget {
  final int userId;
  final _UserListType type;

  const _UserThreadListTab({
    required this.userId,
    required this.type,
  });

  @override
  State<_UserThreadListTab> createState() => _UserThreadListTabState();
}

class _UserThreadListTabState extends State<_UserThreadListTab> {
  bool loading = true;
  bool loadingMore = false;
  bool noMore = false;
  String? error;
  int page = 1;
  final List<Map<String, dynamic>> items = [];

  final ScrollController scrollController = ScrollController();

  String get route {
    switch (widget.type) {
      case _UserListType.threads:
        return 'user/threads';
      case _UserListType.posts:
        return 'user/posts';
      case _UserListType.favorites:
        return 'user/favorites';
    }
  }

  @override
  void initState() {
    super.initState();
    _load(refresh: true);

    scrollController.addListener(() {
      if (!scrollController.hasClients) return;
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({
    required bool refresh,
  }) async {
    if (refresh) {
      setState(() {
        loading = items.isEmpty;
        error = null;
        noMore = false;
        page = 1;
      });
    }

    final result = await ApiClient.instance.get(
      route,
      query: {
        'user_id': widget.userId,
        'page': page,
        'page_size': 20,
      },
    );

    if (!mounted) return;

    if (result.success) {
      final data = result.data;
      List rawList = [];

      if (data is Map<String, dynamic>) {
        if (data['list'] is List) {
          rawList = data['list'] as List;
        }
      } else if (data is List) {
        rawList = data;
      }

      final list = rawList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        if (refresh) {
          items.clear();
        }

        items.addAll(list);
        loading = false;
        loadingMore = false;
        noMore = list.isEmpty;
        error = null;
      });
    } else {
      setState(() {
        loading = false;
        loadingMore = false;
        error = result.message;
      });
    }
  }

  Future<void> _refresh() async {
    page = 1;
    await _load(refresh: true);
  }

  Future<void> _loadMore() async {
    if (loading || loadingMore || noMore) return;

    setState(() {
      loadingMore = true;
    });

    page += 1;
    await _load(refresh: false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const LoadingView();
    }

    if (error != null && items.isEmpty) {
      return ErrorView(
        message: error!,
        onRetry: _refresh,
      );
    }

    if (items.isEmpty) {
      return ErrorView(
        message: '暂无内容',
        onRetry: _refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == items.length) {
            if (loadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (noMore) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '没有更多了',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }

            return const SizedBox(height: 20);
          }

          final item = items[index];

          return _UserThreadItem(
            item: item,
            type: widget.type,
          );
        },
      ),
    );
  }
}

class _UserThreadItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final _UserListType type;

  const _UserThreadItem({
    required this.item,
    required this.type,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final threadId = _toInt(item['thread_id'] ?? item['id']);
    final title = item['title']?.toString() ?? '无标题';
    final summary = item['summary']?.toString() ??
        item['content']?.toString() ??
        '';
    final cover = item['cover']?.toString() ?? '';
    final createdAt = item['created_at']?.toString() ?? '';
    final replyCount = _toInt(item['reply_count']);
    final likeCount = _toInt(item['like_count']);

    return GestureDetector(
      onTap: threadId > 0 ? () => context.push('/thread/$threadId') : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover.isNotEmpty)
              SafeNetworkImage(
                url: cover,
                width: 90,
                height: 68,
                borderRadius: BorderRadius.circular(8),
              ),
            if (cover.isNotEmpty) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == _UserListType.posts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '回复了帖子',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (type == _UserListType.favorites)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '收藏的帖子',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        createdAt,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$replyCount',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$likeCount',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
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
