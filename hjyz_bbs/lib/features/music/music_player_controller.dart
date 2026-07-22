import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/music_cache_service.dart';

final musicPlayerProvider =
    StateNotifierProvider<MusicPlayerController, MusicPlayerState>((ref) {
  return MusicPlayerController();
});

class MusicTrack {
  final String? uuid;
  final String url;
  final String title;
  final String artist;
  final Uint8List? coverArt;
  final String? coverUrl;
  final String? lyricsUrl;

  const MusicTrack({
    this.uuid,
    required this.url,
    required this.title,
    this.artist = '',
    this.coverArt,
    this.coverUrl,
    this.lyricsUrl,
  });

  MusicTrack merge(MusicTrack other) {
    final nextTitle = other.title == '音乐' && title != '音乐'
        ? title
        : other.title.trim();
    return MusicTrack(
      uuid: other.uuid?.trim().isNotEmpty == true ? other.uuid : uuid,
      url: url,
      title: nextTitle.isNotEmpty ? nextTitle : title,
      artist: other.artist.trim().isNotEmpty ? other.artist.trim() : artist,
      coverArt: other.coverArt ?? coverArt,
      coverUrl: other.coverUrl?.trim().isNotEmpty == true ? other.coverUrl : coverUrl,
      lyricsUrl: other.lyricsUrl?.trim().isNotEmpty == true
          ? other.lyricsUrl
          : lyricsUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'url': url,
      'title': title,
      'artist': artist,
      'cover_url': coverUrl,
      'lyrics_url': lyricsUrl,
    };
  }

  static MusicTrack? fromJson(dynamic value) {
    if (value is! Map) return null;

    final url = value['url']?.toString().trim() ?? '';
    if (url.isEmpty) return null;

    final title = value['title']?.toString().trim() ?? '';
    return MusicTrack(
      uuid: value['uuid']?.toString().trim().isEmpty == true ? null : value['uuid']?.toString().trim(),
      url: url,
      title: title.isEmpty ? '音乐' : title,
      artist: value['artist']?.toString().trim() ?? '',
      coverUrl: value['cover_url']?.toString().trim().isEmpty == true ? null : value['cover_url']?.toString().trim(),
      lyricsUrl: value['lyrics_url']?.toString().trim().isEmpty == true
          ? null
          : value['lyrics_url']?.toString().trim(),
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
    _storageQueue = _restorePlaylist();
  }

  static const _playlistStorageKey = 'music_player_playlist_v1';

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  String? _loadedUrl;
  bool _handlingCompletion = false;
  Future<void> _storageQueue = Future.value();

  int upsertTrack(MusicTrack track) {
    final url = track.url.trim();
    if (url.isEmpty) return -1;

    final normalized = MusicTrack(
      uuid: track.uuid?.trim().isEmpty == true ? null : track.uuid?.trim(),
      url: url,
      title: track.title.trim().isEmpty ? '音乐' : track.title.trim(),
      artist: track.artist.trim(),
      coverArt: track.coverArt,
      coverUrl: track.coverUrl?.trim().isEmpty == true ? null : track.coverUrl?.trim(),
      lyricsUrl: track.lyricsUrl?.trim().isEmpty == true
          ? null
          : track.lyricsUrl?.trim(),
    );
    final tracks = List<MusicTrack>.from(state.playlist);
    final index = tracks.indexWhere((item) => item.uuid != null && item.uuid == normalized.uuid || item.url == url);

    if (index >= 0) {
      tracks[index] = tracks[index].merge(normalized);
      state = state.copyWith(playlist: List.unmodifiable(tracks));
      _schedulePersist();
      return index;
    }

    tracks.add(normalized);
    state = state.copyWith(
      playlist: List.unmodifiable(tracks),
      currentIndex: state.currentIndex < 0 ? 0 : state.currentIndex,
    );
    _schedulePersist();
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

  Future<void> playTracks(
    Iterable<MusicTrack> tracks, {
    bool autoplay = true,
  }) async {
    final unique = <MusicTrack>[];
    final keys = <String>{};
    for (final track in tracks) {
      final url = track.url.trim();
      if (url.isEmpty) continue;
      final uuid = track.uuid?.trim() ?? '';
      final key = uuid.isNotEmpty ? 'uuid:$uuid' : 'url:$url';
      if (!keys.add(key)) continue;
      unique.add(
        MusicTrack(
          uuid: uuid.isEmpty ? null : uuid,
          url: url,
          title: track.title.trim().isEmpty ? '音乐' : track.title.trim(),
          artist: track.artist.trim(),
          coverArt: track.coverArt,
          coverUrl: track.coverUrl?.trim().isEmpty == true
              ? null
              : track.coverUrl?.trim(),
          lyricsUrl: track.lyricsUrl?.trim().isEmpty == true
              ? null
              : track.lyricsUrl?.trim(),
        ),
      );
    }
    if (unique.isEmpty) return;

    await _player.stop();
    _loadedUrl = null;
    state = MusicPlayerState(
      playlist: List.unmodifiable(unique),
      currentIndex: 0,
      loading: true,
    );
    _schedulePersist();
    await _loadIndex(0, autoplay: autoplay);
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
    _schedulePersist();
  }

  Future<void> clearPlaylist() async {
    await _player.stop();
    _loadedUrl = null;
    state = const MusicPlayerState();
    _schedulePersist();
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
      _schedulePersist();
      final cachedFile = await MusicCacheService.instance.getCachedAudio(track.url);
      if (cachedFile == null) {
        await _player.setUrl(track.url);
      } else {
        await _player.setFilePath(cachedFile.path);
      }
      _loadedUrl = track.url;
      if (mounted) state = state.copyWith(loading: false, clearError: true);
      if (autoplay) _startPlayback();
      _preloadNext(index);
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

  void _preloadNext(int currentIndex) {
    if (state.playlist.length < 2) return;
    final nextIndex = (currentIndex + 1) % state.playlist.length;
    unawaited(
      MusicCacheService.instance.preloadAudio(state.playlist[nextIndex].url),
    );
    final lyricsUrl = state.playlist[nextIndex].lyricsUrl;
    if (lyricsUrl != null && lyricsUrl.isNotEmpty) {
      unawaited(MusicCacheService.instance.loadLyrics(lyricsUrl));
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

  Future<void> _restorePlaylist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_playlistStorageKey);
      if (raw == null || raw.isEmpty || !mounted) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final restored = (decoded['playlist'] as List? ?? const [])
          .map(MusicTrack.fromJson)
          .whereType<MusicTrack>()
          .toList();
      if (restored.isEmpty) return;

      final currentTrackUrl = state.currentTrack?.url;
      for (final track in state.playlist) {
        final index = restored.indexWhere((item) =>
            (item.uuid != null && item.uuid == track.uuid) || item.url == track.url);
        if (index >= 0) {
          restored[index] = restored[index].merge(track);
        } else {
          restored.add(track);
        }
      }

      final storedIndex = decoded['current_index'] is int
          ? decoded['current_index'] as int
          : int.tryParse(decoded['current_index']?.toString() ?? '') ?? 0;
      final fallbackIndex = storedIndex < 0
          ? 0
          : (storedIndex >= restored.length ? restored.length - 1 : storedIndex);
      final currentIndex = currentTrackUrl == null
          ? fallbackIndex
          : restored.indexWhere((track) => track.url == currentTrackUrl);

      state = state.copyWith(
        playlist: List.unmodifiable(restored),
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
      );
    } catch (_) {}
  }

  void _schedulePersist() {
    _storageQueue = _storageQueue.then((_) => _persistPlaylist()).catchError((_) {});
  }

  Future<void> _persistPlaylist() async {
    final preferences = await SharedPreferences.getInstance();
    final data = {
      'playlist': state.playlist.map((track) => track.toJson()).toList(),
      'current_index': state.currentIndex,
    };
    await preferences.setString(_playlistStorageKey, jsonEncode(data));
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
