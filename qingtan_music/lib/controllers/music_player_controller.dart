import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music.dart';
import '../services/music_api_service.dart';

final musicPlayerProvider =
    StateNotifierProvider<MusicPlayerController, MusicPlayerState>((ref) {
  return MusicPlayerController(MusicApiService.instance);
});

class MusicPlayerState {
  const MusicPlayerState({
    this.playlist = const [],
    this.currentIndex = -1,
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  final List<MusicTrack> playlist;
  final int currentIndex;
  final bool playing;
  final bool loading;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final String? error;

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
    Duration? bufferedPosition,
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
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MusicPlayerController extends StateNotifier<MusicPlayerState> {
  MusicPlayerController(this._api) : super(const MusicPlayerState()) {
    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) state = state.copyWith(position: position);
    });
    _bufferSubscription = _player.bufferedPositionStream.listen((position) {
      if (mounted) state = state.copyWith(bufferedPosition: position);
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (mounted && duration != null) state = state.copyWith(duration: duration);
    });
    _playerSubscription = _player.playerStateStream.listen((value) {
      if (!mounted) return;
      state = state.copyWith(
        playing: value.playing,
        loading: value.processingState == ProcessingState.loading ||
            value.processingState == ProcessingState.buffering,
      );
      if (value.processingState == ProcessingState.completed && !_advancing) {
        _advancing = true;
        unawaited(_handleCompleted());
      }
    });
    unawaited(_restore());
  }

  static const _storageKey = 'qingtan_music_playlist_v1';

  final MusicApiService _api;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerSubscription;
  String? _loadedKey;
  bool _advancing = false;

  Future<void> selectTrack(MusicTrack track, {bool autoplay = true}) async {
    final tracks = List<MusicTrack>.from(state.playlist);
    var index = tracks.indexWhere((item) => item.key == track.key);
    if (index < 0) {
      tracks.add(track);
      index = tracks.length - 1;
    } else {
      tracks[index] = track;
    }
    state = state.copyWith(playlist: List.unmodifiable(tracks));
    await _load(index, autoplay: autoplay);
  }

  Future<void> playAt(int index) => _load(index, autoplay: true);

  Future<void> toggle() async {
    if (state.currentTrack == null) return;
    if (_loadedKey != state.currentTrack!.key) {
      await _load(state.currentIndex, autoplay: true);
    } else if (state.playing) {
      await _player.pause();
    } else {
      _startPlayback();
    }
  }

  Future<void> next() async {
    if (state.playlist.isEmpty) return;
    await _load((state.currentIndex + 1) % state.playlist.length, autoplay: true);
  }

  Future<void> previous() async {
    if (state.playlist.isEmpty) return;
    final index = state.currentIndex <= 0
        ? state.playlist.length - 1
        : state.currentIndex - 1;
    await _load(index, autoplay: true);
  }

  Future<void> seek(Duration value) => _player.seek(value);

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= state.playlist.length) return;
    final removingCurrent = index == state.currentIndex;
    final tracks = List<MusicTrack>.from(state.playlist)..removeAt(index);
    if (tracks.isEmpty) {
      await clear();
      return;
    }
    if (removingCurrent) {
      await _player.stop();
      _loadedKey = null;
      state = state.copyWith(
        playlist: List.unmodifiable(tracks),
        currentIndex: index.clamp(0, tracks.length - 1).toInt(),
        playing: false,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: Duration.zero,
      );
    } else {
      state = state.copyWith(
        playlist: List.unmodifiable(tracks),
        currentIndex: index < state.currentIndex
            ? state.currentIndex - 1
            : state.currentIndex,
      );
    }
    unawaited(_persist());
  }

  Future<void> clear() async {
    await _player.stop();
    _loadedKey = null;
    state = const MusicPlayerState();
    unawaited(_persist());
  }

  Future<void> _load(int index, {required bool autoplay}) async {
    if (index < 0 || index >= state.playlist.length) return;
    final track = state.playlist[index];
    try {
      await _player.pause();
      _loadedKey = null;
      state = state.copyWith(
        currentIndex: index,
        playing: false,
        loading: true,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: Duration.zero,
        clearError: true,
      );
      unawaited(_persist());
      final url = await _api.resolveAudioUrl(track);
      final coverUrl = await _api.resolveCoverUrl(track);
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: track.key,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artUri: coverUrl.isEmpty ? null : Uri.tryParse(coverUrl),
          ),
        ),
      );
      _loadedKey = track.key;
      if (mounted) {
        state = state.copyWith(
          loading: false,
          duration: _player.duration ?? Duration.zero,
          clearError: true,
        );
      }
      if (autoplay) _startPlayback();
    } on MusicApiException catch (error) {
      if (mounted) {
        state = state.copyWith(loading: false, playing: false, error: error.message);
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          loading: false,
          playing: false,
          error: '音乐加载失败',
        );
      }
    }
  }

  Future<void> _handleCompleted() async {
    try {
      if (state.playlist.length > 1) {
        await next();
      } else {
        await _player.pause();
        await _player.seek(Duration.zero);
      }
    } finally {
      _advancing = false;
    }
  }

  void _startPlayback() {
    unawaited(
      _player.play().catchError((_) {
        if (mounted) {
          state = state.copyWith(loading: false, playing: false, error: '音乐播放失败');
        }
      }),
    );
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (raw == null || raw.isEmpty || !mounted) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final playlist = (decoded['playlist'] as List? ?? const [])
          .map(MusicTrack.fromJson)
          .whereType<MusicTrack>()
          .toList(growable: false);
      if (playlist.isEmpty) return;
      final storedIndex = int.tryParse(decoded['current_index']?.toString() ?? '') ?? 0;
      if (state.playlist.isNotEmpty) return;
      state = state.copyWith(
        playlist: List.unmodifiable(playlist),
        currentIndex: storedIndex.clamp(0, playlist.length - 1).toInt(),
      );
    } catch (_) {}
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode({
        'playlist': state.playlist.map((track) => track.toJson()).toList(),
        'current_index': state.currentIndex,
      }),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _bufferSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
