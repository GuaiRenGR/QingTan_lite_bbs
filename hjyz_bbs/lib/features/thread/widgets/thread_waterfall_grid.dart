import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/aspect_ratio_network_image.dart';
import '../../../core/widgets/safe_network_image.dart';

class ThreadWaterfallGrid extends StatelessWidget {
  final List<Map<String, dynamic>> threads;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  const ThreadWaterfallGrid({
    super.key,
    required this.threads,
    this.physics,
    this.padding = const EdgeInsets.fromLTRB(10, 10, 10, 90),
  });

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: padding,
      physics: physics,
      crossAxisCount: _getColumnCount(context),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      itemCount: threads.length,
      itemBuilder: (context, index) {
        return ThreadWaterfallCard(item: threads[index]);
      },
    );
  }
}

class ThreadWaterfallSliver extends StatelessWidget {
  final List<Map<String, dynamic>> threads;

  const ThreadWaterfallSliver({
    super.key,
    required this.threads,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: _getColumnCount(context),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childCount: threads.length,
        itemBuilder: (context, index) {
          return ThreadWaterfallCard(item: threads[index]);
        },
      ),
    );
  }
}

int _getColumnCount(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final ratio = size.width / size.height;

  if (ratio < 2 / 3) return 2;
  if (ratio < 1) return 3;
  if (ratio < 3 / 2) return 4;
  if (ratio < 16 / 9) return 5;
  return 6;
}

class ThreadWaterfallCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const ThreadWaterfallCard({
    super.key,
    required this.item,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final id = _toInt(item['id'] ?? item['thread_id']);
    final title = item['title']?.toString() ?? '';
    final cover = item['cover']?.toString() ?? '';
    final summary = item['summary']?.toString() ?? '';
    final likeCount = _toInt(item['like_count']);
    final replyCount = _toInt(item['reply_count']);
    final isTop = _toBool(item['is_top']);
    final isDigest = _toBool(item['is_digest']);

    final authorName = item['author_name']?.toString() ??
        item['nickname']?.toString() ??
        item['user_name']?.toString() ??
        '用户';

    final avatar = item['author_avatar']?.toString() ??
        item['avatar']?.toString() ??
        '';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (id > 0) {
          context.push('/thread/$id');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover.isNotEmpty)
              _CoverWithBadges(
                cover: cover,
                isTop: isTop,
                isDigest: isDigest,
                replyCount: replyCount,
              )
            else
              _PlaceholderWithBadges(
                height: 120 + (id.abs() % 5) * 15.0,
                isTop: isTop,
                isDigest: isDigest,
                replyCount: replyCount,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? summary : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SafeNetworkImage(
                        url: avatar,
                        width: 20,
                        height: 20,
                        borderRadius: BorderRadius.circular(10),
                        errorWidget: CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(
                            Icons.person,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.favorite_border_rounded,
                        size: 15,
                        color: Color(0xFF888888),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$likeCount',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
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

class _CoverWithBadges extends StatelessWidget {
  final String cover;
  final bool isTop;
  final bool isDigest;
  final int replyCount;

  const _CoverWithBadges({
    required this.cover,
    required this.isTop,
    required this.isDigest,
    required this.replyCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatioNetworkImage(
          url: cover,
          width: double.infinity,
        ),
        Positioned(
          left: 6,
          top: 6,
          child: Row(
            children: [
              if (isTop) _badge('置顶', Colors.red),
              if (isDigest) _badge('精华', Colors.orange),
            ],
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 11,
                ),
                const SizedBox(width: 2),
                Text(
                  '$replyCount',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderWithBadges extends StatelessWidget {
  final double height;
  final bool isTop;
  final bool isDigest;
  final int replyCount;

  const _PlaceholderWithBadges({
    required this.height,
    required this.isTop,
    required this.isDigest,
    required this.replyCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.pink.shade50,
                Colors.blue.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.article_outlined,
              size: 38,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Positioned(
          left: 6,
          top: 6,
          child: Row(
            children: [
              if (isTop) _badge('置顶', Colors.red),
              if (isDigest) _badge('精华', Colors.orange),
            ],
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 11,
                ),
                const SizedBox(width: 2),
                Text(
                  '$replyCount',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _badge(String text, Color color) {
  return Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
