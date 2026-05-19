import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../auth/auth_controller.dart';
import '../main/main_tab_provider.dart';
import '../thread/widgets/thread_waterfall_grid.dart';
import 'home_feed_controller.dart';
import 'widgets/home_channel_tabs.dart';
import 'widgets/home_top_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _toast(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 500) {
      ref.read(homeFeedControllerProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(homeFeedControllerProvider);
    final controller = ref.read(homeFeedControllerProvider.notifier);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          HomeTopBar(
            onAvatarTap: () {
              ref.read(mainTabIndexProvider.notifier).state = 4;
            },
            onSearchTap: () {
              _toast('搜索功能开发中');
            },
            onMessageTap: () {
              if (auth.loggedIn) {
                context.push('/messages');
              } else {
                _toast('登录后可以使用私信');
                context.push('/login');
              }
            },
          ),
          HomeChannelTabs(
            current: state.channel,
            onChanged: controller.switchChannel,
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (state.loading && state.items.isEmpty) {
                  return const LoadingView();
                }

                if (state.error != null && state.items.isEmpty) {
                  return ErrorView(
                    message: state.error!,
                    onRetry: controller.refresh,
                  );
                }

                if (state.items.isEmpty) {
                  return ErrorView(
                    message: '暂无内容',
                    onRetry: controller.refresh,
                  );
                }

                final threadMaps = state.items
                    .map((e) => e.toMap())
                    .toList();

                return RefreshIndicator(
                  color: const Color(0xFFFB7299),
                  displacement: 46,
                  onRefresh: controller.refresh,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: ThreadWaterfallGrid(
                      threads: threadMaps,
                      physics: const AlwaysScrollableScrollPhysics(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
