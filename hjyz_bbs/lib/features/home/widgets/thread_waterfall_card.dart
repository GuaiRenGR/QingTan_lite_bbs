import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/safe_network_image.dart';
import '../../thread/thread_model.dart';

class ThreadWaterfallCard extends StatelessWidget {
  final ThreadModel thread;

  const ThreadWaterfallCard({
    super.key,
    required this.thread,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: thread.id > 0 ? () => context.push('/thread/${thread.id}') : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade100,
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(thread: thread),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                thread.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  height: 1.25,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
            ),
            if (thread.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Text(
                  thread.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.25,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
              child: Row(
                children: [
                  SafeNetworkImage(
                    url: thread.authorAvatar,
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
                      thread.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 15,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(thread.likeCount),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }
}

class _Cover extends StatelessWidget {
  final ThreadModel thread;

  const _Cover({
    required this.thread,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = thread.cover.isNotEmpty;

    return Stack(
      children: [
        if (hasCover)
          SafeNetworkImage(
            url: thread.cover,
            width: double.infinity,
            height: _mockHeight(thread.id),
            fit: BoxFit.cover,
          )
        else
          Container(
            width: double.infinity,
            height: _mockHeight(thread.id),
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
              if (thread.isTop) _badge('置顶', Colors.red),
              if (thread.isDigest) _badge('精华', Colors.orange),
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
                  '${thread.replyCount}',
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

  double _mockHeight(int id) {
    final heights = [120.0, 145.0, 170.0, 135.0, 190.0];
    return heights[id.abs() % heights.length];
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
}
