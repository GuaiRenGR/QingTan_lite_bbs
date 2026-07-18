import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/notification_service.dart';
import '../auth/auth_controller.dart';
import 'widgets/home_feed_page.dart';
import 'widgets/home_top_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;

  final tabs = const [
    _HomeTab('推荐', 'recommend'),
    _HomeTab('热门', 'hot'),
    _HomeTab('精华', 'digest'),
    _HomeTab('最新', 'latest'),
  ];

  final _feedRefreshCallbacks = <VoidCallback>[];

  @override
  void initState() {
    super.initState();

    tabController = TabController(
      length: tabs.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  void refreshCurrentFeed() {
    final index = tabController.index;
    if (index < _feedRefreshCallbacks.length) {
      _feedRefreshCallbacks[index]();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          HomeTopBar(
            onAvatarTap: () {
              final auth = ref.read(authControllerProvider);
              final userId =
                  int.tryParse(auth.user?['id']?.toString() ?? '') ?? 0;
              if (userId > 0) {
                context.push('/user/$userId');
              }
            },
            onSearchTap: () {
              context.push('/search');
            },
            onMessageTap: () async {
              await context.push('/messages');
              await NotificationService().checkNow();
            },
          ),

          // 注意：这里没有"关注"
          Container(
            alignment: Alignment.centerLeft,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFFFB7299),
              unselectedLabelColor: Colors.black87,
              indicatorColor: const Color(0xFFFB7299),
              indicatorWeight: 3,
              tabs: [
                for (final tab in tabs) Tab(text: tab.title),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                for (int i = 0; i < tabs.length; i++)
                  HomeFeedPage(
                    key: PageStorageKey('home-feed-${tabs[i].type}'),
                    type: tabs[i].type,
                    onRefreshReady: (callback) {
                      if (i < _feedRefreshCallbacks.length) {
                        _feedRefreshCallbacks[i] = callback;
                      } else {
                        _feedRefreshCallbacks.add(callback);
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTab {
  final String title;
  final String type;

  const _HomeTab(this.title, this.type);
}
