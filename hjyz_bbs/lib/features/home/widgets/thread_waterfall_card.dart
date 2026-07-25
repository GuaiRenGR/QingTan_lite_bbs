import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../../core/widgets/sensitive_media.dart';
import '../../../core/services/feed_display_service.dart';
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
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.border(context),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(thread: thread),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 3),
              child: Text(
                thread.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  height: 1.25,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (thread.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 5),
                child: Text(
                  thread.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.25,
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 7),
              child: Row(
                children: [
                  SafeNetworkImage(
                    url: thread.authorAvatar,
                    width: 20,
                    height: 20,
                    borderRadius: BorderRadius.circular(10),
                    errorWidget: CircleAvatar(
                      radius: 10,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        size: 12,
                        color: AppColors.textSecondary(context),
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
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 15,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(thread.likeCount),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
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
    final height = _mockHeight(thread.id);
    final placeholder = _buildPlaceholder(context, height);

    return Stack(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: FeedDisplayService.compactTextOnlyPosts,
          builder: (context, compactTextOnlyPosts, _) {
            if (!hasCover && compactTextOnlyPosts) {
              return const SizedBox.shrink();
            }
            if (!hasCover) return placeholder;
            return SensitiveMedia(
              labels: thread.sensitiveLabels,
              blockedHeight: height,
              child: SafeNetworkImage(
                url: thread.cover,
                width: double.infinity,
                height: height,
                fit: BoxFit.cover,
                errorWidget: placeholder,
              ),
            );
          },
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

  Widget _buildPlaceholder(BuildContext context, double height) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF2B2228), Color(0xFF202934)]
              : const [Color(0xFFFFF1F5), Color(0xFFF0F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 38,
          color: AppColors.textSecondary(context),
        ),
      ),
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
