import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'music_player_controller.dart';

final musicFavoritesProvider = StateNotifierProvider<MusicFavoritesController,
    MusicFavoritesState>((ref) {
  return MusicFavoritesController();
});

class MusicFavoritesState {
  final int userId;
  final bool loading;
  final bool initialized;
  final List<MusicTrack> tracks;
  final String? error;

  const MusicFavoritesState({
    this.userId = 0,
    this.loading = false,
    this.initialized = false,
    this.tracks = const [],
    this.error,
  });

  bool contains(MusicTrack track) => track.uuid != null
      ? tracks.any((item) => item.uuid == track.uuid)
      : tracks.any((item) => item.url == track.url);

  MusicFavoritesState copyWith({
    int? userId,
    bool? loading,
    bool? initialized,
    List<MusicTrack>? tracks,
    String? error,
    bool clearError = false,
  }) {
    return MusicFavoritesState(
      userId: userId ?? this.userId,
      loading: loading ?? this.loading,
      initialized: initialized ?? this.initialized,
      tracks: tracks ?? this.tracks,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MusicFavoritesController extends StateNotifier<MusicFavoritesState> {
  MusicFavoritesController() : super(const MusicFavoritesState());

  Future<void> load(int userId, {bool force = false}) async {
    if (userId <= 0) {
      state = const MusicFavoritesState();
      return;
    }
    if (!force && state.userId == userId && (state.loading || state.initialized)) {
      return;
    }

    state = MusicFavoritesState(
      userId: userId,
      loading: true,
      initialized: false,
      tracks: state.userId == userId ? state.tracks : const [],
    );
    final result = await ApiClient.instance.get('music/playlists/default');
    if (!mounted || state.userId != userId) return;

    if (!result.success || result.data is! Map<String, dynamic>) {
      state = state.copyWith(
        loading: false,
        initialized: true,
        error: result.message,
      );
      return;
    }

    final data = result.data as Map<String, dynamic>;
    final rawTracks = data['tracks'] is List ? data['tracks'] as List : const [];
    final tracks = rawTracks
        .map(MusicTrack.fromJson)
        .whereType<MusicTrack>()
        .toList(growable: false);
    state = MusicFavoritesState(
      userId: userId,
      initialized: true,
      tracks: List.unmodifiable(tracks),
    );
  }

  Future<bool?> toggle(MusicTrack track) async {
    if (state.userId <= 0 || state.loading) return null;

    if (track.uuid == null || track.uuid!.isEmpty) return null;
    final wasFavorite = state.contains(track);
    final result = await ApiClient.instance.post(
      'music/favorites/toggle',
      data: {
        'music_uuid': track.uuid,
      },
    );
    if (!result.success || result.data is! Map<String, dynamic>) {
      if (mounted) state = state.copyWith(error: result.message);
      return null;
    }

    final favorited = (result.data as Map<String, dynamic>)['is_favorited'] == true ||
        (result.data as Map<String, dynamic>)['is_favorited'] == 1;
    final tracks = List<MusicTrack>.from(state.tracks);
    final index = tracks.indexWhere((item) => item.uuid == track.uuid);
    if (favorited) {
      if (index >= 0) {
        tracks[index] = tracks[index].merge(track);
      } else {
        tracks.insert(0, track);
      }
    } else if (index >= 0) {
      tracks.removeAt(index);
    } else if (wasFavorite) {
      await load(state.userId, force: true);
      return false;
    }

    if (mounted) {
      state = state.copyWith(
        tracks: List.unmodifiable(tracks),
        clearError: true,
      );
    }
    return favorited;
  }
}
