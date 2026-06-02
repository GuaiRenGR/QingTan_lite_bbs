import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../thread/thread_model.dart';
import 'home_repository.dart';

final homeFeedControllerProvider =
    StateNotifierProvider<HomeFeedController, HomeFeedState>((ref) {
  return HomeFeedController(HomeRepository())..refresh();
});

class HomeFeedState {
  final bool loading;
  final bool refreshing;
  final bool loadingMore;
  final bool noMore;
  final int page;
  final String channel;
  final List<ThreadModel> items;
  final String? error;

  const HomeFeedState({
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.noMore = false,
    this.page = 1,
    this.channel = 'recommend',
    this.items = const [],
    this.error,
  });

  HomeFeedState copyWith({
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    bool? noMore,
    int? page,
    String? channel,
    List<ThreadModel>? items,
    String? error,
  }) {
    return HomeFeedState(
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      noMore: noMore ?? this.noMore,
      page: page ?? this.page,
      channel: channel ?? this.channel,
      items: items ?? this.items,
      error: error,
    );
  }
}

class HomeFeedController extends StateNotifier<HomeFeedState> {
  final HomeRepository repository;

  HomeFeedController(this.repository) : super(const HomeFeedState());

  Future<void> refresh() async {
    if (state.refreshing) return;

    state = state.copyWith(
      loading: state.items.isEmpty,
      refreshing: true,
      page: 1,
      noMore: false,
      error: null,
    );

    // 刷新时传入当前已展示的 ID 列表用于去重
    final excludeIds = state.items.map((e) => e.id).toList();

    final result = await repository.fetchFeed(
      page: 1,
      channel: state.channel,
      excludeIds: excludeIds,
    );

    if (result.success) {
      final list = result.data ?? [];

      state = state.copyWith(
        loading: false,
        refreshing: false,
        items: list,
        page: 1,
        noMore: list.isEmpty,
        error: null,
      );
    } else {
      state = state.copyWith(
        loading: false,
        refreshing: false,
        error: result.message,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loading ||
        state.refreshing ||
        state.loadingMore ||
        state.noMore) {
      return;
    }

    state = state.copyWith(
      loadingMore: true,
      error: null,
    );

    final nextPage = state.page + 1;

    final result = await repository.fetchFeed(
      page: nextPage,
      channel: state.channel,
    );

    if (result.success) {
      final list = result.data ?? [];

      state = state.copyWith(
        loadingMore: false,
        page: nextPage,
        items: [...state.items, ...list],
        noMore: list.isEmpty,
        error: null,
      );
    } else {
      state = state.copyWith(
        loadingMore: false,
        error: result.message,
      );
    }
  }

  Future<void> switchChannel(String channel) async {
    if (state.channel == channel) return;

    state = HomeFeedState(
      channel: channel,
      loading: true,
    );

    await refresh();
  }
}
