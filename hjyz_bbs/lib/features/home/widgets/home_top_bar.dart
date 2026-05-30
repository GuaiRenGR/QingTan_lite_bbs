import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../auth/auth_controller.dart';

class HomeTopBar extends ConsumerStatefulWidget {
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onMessageTap;

  const HomeTopBar({
    super.key,
    this.onAvatarTap,
    this.onSearchTap,
    this.onMessageTap,
  });

  @override
  ConsumerState<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends ConsumerState<HomeTopBar> {
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> refreshUnread() async {
    await _loadUnread();
  }

  Future<void> _loadUnread() async {
    final result = await ApiClient.instance.get('messages/unread');
    if (!mounted || !result.success) return;
    if (result.data is Map) {
      final count = (result.data as Map)['unread_count'];
      if (mounted) {
        setState(() {
          unreadCount = count is int ? count : (int.tryParse('$count') ?? 0);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    final avatar = auth.user?['avatar']?.toString() ?? '';

    return Container(
      color: AppColors.card(context),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 12,
        right: 12,
        bottom: 8,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onAvatarTap,
            child: SafeNetworkImage(
              url: avatar.isNotEmpty ? avatar : AppConfig.defaultAvatar,
              width: 36,
              height: 36,
              borderRadius: BorderRadius.circular(18),
              errorWidget: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                child: Icon(
                  auth.loggedIn ? Icons.person : Icons.person_outline,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: widget.onSearchTap,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.inputFill(context),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '搜索帖子、版块、用户',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onMessageTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.mail_outline_rounded,
                    color: Colors.grey.shade800,
                    size: 25,
                  ),
                  if (auth.loggedIn && unreadCount > 0)
                    Positioned(
                      right: 2,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB7299),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
