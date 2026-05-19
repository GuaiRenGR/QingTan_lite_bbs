import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

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

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: padding,
      physics: physics,
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      itemCount: threads.length,
      itemBuilder: (context, index) {
        final item = threads[index];

        return _ThreadWaterfallCard(
          item: item,
          likeCount: _toInt(item['like_count']),
        );
      },
    );
  }
}

class _ThreadWaterfallCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int likeCount;

  const _ThreadWaterfallCard({
    required this.item,
    required this.likeCount,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final id = _toInt(item['id'] ?? item['thread_id']);
    final title = item['title']?.toString() ?? '';
    final cover = item['cover']?.toString() ?? '';
    final summary = item['summary']?.toString() ?? '';

    final authorName = item['author_name']?.toString() ??
        item['nickname']?.toString() ??
        item['user_name']?.toString() ??
        '用户';

    final avatar =
        item['author_avatar']?.toString() ?? item['avatar']?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (id > 0) {
          context.push('/thread/$id');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
              SafeNetworkImage(
                url: cover,
                width: double.infinity,
                fit: BoxFit.cover,
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
