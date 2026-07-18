import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

final musicPlayerProvider =
    StateNotifierProvider<MusicPlayerController, MusicPlayerState>((ref) {
  return MusicPlayerController();
});

class MusicTrack {
  final String url;
  final String title;
  final Uint8List? coverArt;

  const MusicTrack({
    required this.url,
    required this.title,
    this.coverArt,
  });

  MusicTrack merge(MusicTrack other) {
    final nextTitle = other.title == '音乐' && title != '音乐'
        ? title
        : other.title.trim();
    return MusicTrack(
      url: url,
      title: nextTitle.isNotEmpty ? nextTitle : title,
      coverArt: other.coverArt ?? coverArt,
    );
  }
}

class MusicPlayerState {
  final List<MusicTrack> playlist;
  final int currentIndex;
  final bool playing;
  final bool loading;
  final Duration position;
  final Duration duration;
  final String? error;

  const MusicPlayerState({
    this.playlist = const [],
    this.currentIndex = -1,
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  MusicTrack? get currentTrack {
    if (currentIndex < 0 || currentIndex >= playlist.length) return null;
    return playlist[currentIndex];
  }

  MusicPlayerState copyWith({
    List<MusicTrack>? playlist,
    int? currentIndex,
    bool? playing,
    bool? loading,
    Duration? position,
    Duration? duration,
    String? error,
    bool clearError = false,
  }) {
    return MusicPlayerState(
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      playing: playing ?? this.playing,
      loading: loading ?? this.loading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MusicPlayerController extends StateNotifier<MusicPlayerState> {
  MusicPlayerController() : super(const MusicPlayerState()) {
    _positionSub = _player.positionStream.listen((position) {
      if (mounted) state = state.copyWith(position: position);
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (mounted && duration != null) {
        state = state.copyWith(duration: duration);
      }
    });
    _playerStateSub = _player.playerStateStream.listen((playerState) {
      if (!mounted) return;

      final processingState = playerState.processingState;
      state = state.copyWith(
        playing: playerState.playing,
        loading: processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering,
      );

      if (processingState == ProcessingState.completed &&
          !_handlingCompletion) {
        _handlingCompletion = true;
        unawaited(_handleCompletion());
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  String? _loadedUrl;
  bool _handlingCompletion = false;

  int upsertTrack(MusicTrack track) {
    final url = track.url.trim();
    if (url.isEmpty) return -1;

    final normalized = MusicTrack(
      url: url,
      title: track.title.trim().isEmpty ? '音乐' : track.title.trim(),
      coverArt: track.coverArt,
    );
    final tracks = List<MusicTrack>.from(state.playlist);
    final index = tracks.indexWhere((item) => item.url == url);

    if (index >= 0) {
      tracks[index] = tracks[index].merge(normalized);
      state = state.copyWith(playlist: List.unmodifiable(tracks));
      return index;
    }

    tracks.add(normalized);
    state = state.copyWith(
      playlist: List.unmodifiable(tracks),
      currentIndex: state.currentIndex < 0 ? 0 : state.currentIndex,
    );
    return tracks.length - 1;
  }

  Future<void> selectTrack(
    MusicTrack track, {
    bool autoplay = false,
  }) async {
    final index = upsertTrack(track);
    if (index < 0) return;

    if (state.currentIndex == index && _loadedUrl == state.playlist[index].url) {
      if (autoplay) await play();
      return;
    }

    await _loadIndex(index, autoplay: autoplay);
  }

  Future<void> toggleTrack(MusicTrack track) async {
    final index = upsertTrack(track);
    if (index < 0) return;

    if (state.currentIndex != index || _loadedUrl != state.playlist[index].url) {
      await _loadIndex(index, autoplay: true);
      return;
    }

    await toggle();
  }

  Future<void> toggle() async {
    if (state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    final track = state.currentTrack;
    if (track == null) return;

    if (_loadedUrl != track.url) {
      await _loadIndex(state.currentIndex, autoplay: true);
      return;
    }

    _startPlayback();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> playNext() async {
    if (state.playlist.isEmpty) return;
    final nextIndex = (state.currentIndex + 1) % state.playlist.length;
    await _loadIndex(nextIndex, autoplay: true);
  }

  Future<void> playPrevious() async {
    if (state.playlist.isEmpty) return;
    final previousIndex = state.currentIndex <= 0
        ? state.playlist.length - 1
        : state.currentIndex - 1;
    await _loadIndex(previousIndex, autoplay: true);
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= state.playlist.length) return;

    final tracks = List<MusicTrack>.from(state.playlist)..removeAt(index);
    if (tracks.isEmpty) {
      await clearPlaylist();
      return;
    }

    if (index == state.currentIndex) {
      final autoplay = state.playing;
      await _player.stop();
      _loadedUrl = null;
      final nextIndex = index >= tracks.length ? tracks.length - 1 : index;
      state = state.copyWith(
        playlist: List.unmodifiable(tracks),
        currentIndex: nextIndex,
        playing: false,
        position: Duration.zero,
        duration: Duration.zero,
        clearError: true,
      );
      await _loadIndex(nextIndex, autoplay: autoplay);
      return;
    }

    final currentIndex = index < state.currentIndex
        ? state.currentIndex - 1
        : state.currentIndex;
    state = state.copyWith(
      playlist: List.unmodifiable(tracks),
      currentIndex: currentIndex,
    );
  }

  Future<void> clearPlaylist() async {
    await _player.stop();
    _loadedUrl = null;
    state = const MusicPlayerState();
  }

  Future<void> _loadIndex(int index, {required bool autoplay}) async {
    if (index < 0 || index >= state.playlist.length) return;

    final track = state.playlist[index];
    try {
      await _player.pause();
      state = state.copyWith(
        currentIndex: index,
        playing: false,
        loading: true,
        position: Duration.zero,
        duration: Duration.zero,
        clearError: true,
      );
      await _player.setUrl(track.url);
      _loadedUrl = track.url;
      if (mounted) state = state.copyWith(loading: false, clearError: true);
      if (autoplay) _startPlayback();
    } catch (_) {
      _loadedUrl = null;
      if (mounted) {
        state = state.copyWith(
          playing: false,
          loading: false,
          error: '音乐加载失败',
        );
      }
    }
  }

  void _startPlayback() {
    unawaited(
      _player.play().catchError((_) {
        if (mounted) {
          state = state.copyWith(error: '音乐播放失败', loading: false);
        }
      }),
    );
  }

  Future<void> _handleCompletion() async {
    try {
      if (state.playlist.length > 1) {
        await playNext();
      } else {
        await _player.pause();
        await _player.seek(Duration.zero);
      }
    } finally {
      _handlingCompletion = false;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
