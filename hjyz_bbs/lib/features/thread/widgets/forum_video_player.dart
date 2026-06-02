import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class ForumVideoPlayer extends StatefulWidget {
  final String url;

  const ForumVideoPlayer({
    super.key,
    required this.url,
  });

  @override
  State<ForumVideoPlayer> createState() => _ForumVideoPlayerState();
}

class _ForumVideoPlayerState extends State<ForumVideoPlayer> {
  late final Player player;
  late final VideoController controller;

  bool failed = false;

  @override
  void initState() {
    super.initState();

    player = Player();
    controller = VideoController(player);

    _open();
  }

  Future<void> _open() async {
    try {
      await player.open(
        Media(widget.url),
        play: false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        failed = true;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ForumVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      player.open(
        Media(widget.url),
        play: false,
      );
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Container(
        height: 210,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          '视频加载失败',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _BilibiliVideoControls(
          player: player,
          controller: controller,
        ),
      ),
    );
  }
}

/// B 站风格视频控制器
class _BilibiliVideoControls extends StatefulWidget {
  final Player player;
  final VideoController controller;

  const _BilibiliVideoControls({
    required this.player,
    required this.controller,
  });

  @override
  State<_BilibiliVideoControls> createState() => _BilibiliVideoControlsState();
}

class _BilibiliVideoControlsState extends State<_BilibiliVideoControls>
    with SingleTickerProviderStateMixin {
  bool _showControls = true;
  bool _isBuffering = false;
  bool _isDragging = false;
  double _dragProgress = 0;
  bool _isLongPressing = false;
  bool _wasPlayingBeforeLongPress = false;

  // 双击反馈
  bool _showLeftSeek = false;
  bool _showRightSeek = false;
  Timer? _seekFeedbackTimer;

  // 手势状态
  bool _isLeftSide = false;
  bool _showVerticalIndicator = false;
  String _verticalLabel = '';

  Timer? _hideControlsTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isCompleted = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    widget.player.stream.position.listen((p) {
      if (mounted && !_isDragging) setState(() => _position = p);
    });
    widget.player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    widget.player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
    widget.player.stream.completed.listen((c) {
      if (mounted) setState(() => _isCompleted = c);
    });
    widget.player.stream.buffering.listen((b) {
      if (mounted) setState(() => _isBuffering = b);
    });

    _startHideTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        _hideControls();
      }
    });
  }

  void _toggleControls() {
    if (_showControls) {
      _hideControls();
    } else {
      _showControlsPanel();
    }
  }

  void _showControlsPanel() {
    setState(() => _showControls = true);
    _fadeController.forward();
    _startHideTimer();
  }

  void _hideControls() {
    setState(() => _showControls = false);
    _fadeController.reverse();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  void _togglePlay() {
    widget.player.playOrPause();
    _startHideTimer();
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = Duration(
      milliseconds: max(0, min(target.inMilliseconds, _duration.inMilliseconds)),
    );
    widget.player.seek(clamped);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragProgress = _position.inMilliseconds /
        (_duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, BoxConstraints box) {
    final delta = details.primaryDelta ?? 0;
    final progressDelta = delta / box.maxWidth;
    setState(() {
      _dragProgress =
          (_dragProgress + progressDelta).clamp(0.0, 1.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final target = Duration(
      milliseconds: (_dragProgress * _duration.inMilliseconds).round(),
    );
    widget.player.seek(target);
    setState(() => _isDragging = false);
    _startHideTimer();
  }

  void _onVerticalDragStart(DragStartDetails details, BoxConstraints box) {
    _isLeftSide = details.localPosition.dx < box.maxWidth / 2;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    // 仅显示 UI 反馈，不实际调节系统值
    setState(() {
      _showVerticalIndicator = true;
      _verticalLabel = _isLeftSide ? '亮度' : '音量';
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _showVerticalIndicator = false;
    });
  }

  void _onDoubleTap(TapDownDetails details, BoxConstraints box) {
    final isLeft = details.localPosition.dx < box.maxWidth / 2;
    if (isLeft) {
      _seekRelative(-10);
      setState(() => _showLeftSeek = true);
    } else {
      _seekRelative(10);
      setState(() => _showRightSeek = true);
    }
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showLeftSeek = false;
          _showRightSeek = false;
        });
      }
    });
    _startHideTimer();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _wasPlayingBeforeLongPress = _isPlaying;
    widget.player.setRate(2.0);
    setState(() => _isLongPressing = true);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    widget.player.setRate(1.0);
    setState(() => _isLongPressing = false);
    if (!_wasPlayingBeforeLongPress) {
      widget.player.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          onDoubleTapDown: (d) => _onDoubleTap(d, constraints),
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, constraints),
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onVerticalDragStart: (d) => _onVerticalDragStart(d, constraints),
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onLongPressStart: _onLongPressStart,
          onLongPressEnd: _onLongPressEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 视频
              Video(controller: widget.controller),

              // 加载指示器
              if (_isBuffering)
                const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),

              // 中央播放按钮（暂停时显示）
              if (!_isPlaying && !_isBuffering && _showControls)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),

              // 双击快退反馈
              if (_showLeftSeek)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: constraints.maxWidth / 3,
                  child: Container(
                    alignment: Alignment.center,
                    child: _SeekFeedback(
                      icon: Icons.replay_10,
                      label: '-10s',
                    ),
                  ),
                ),

              // 双击快进反馈
              if (_showRightSeek)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: constraints.maxWidth / 3,
                  child: Container(
                    alignment: Alignment.center,
                    child: _SeekFeedback(
                      icon: Icons.forward_10,
                      label: '+10s',
                    ),
                  ),
                ),

              // 长按倍速指示
              if (_isLongPressing)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '2x',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // 垂直手势指示条
              if (_showVerticalIndicator)
                Positioned(
                  left: _isLeftSide ? 24 : null,
                  right: _isLeftSide ? null : 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isLeftSide
                                ? Icons.brightness_6
                                : Icons.volume_up,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _verticalLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // seek 拖动预览
              if (_isDragging)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 48,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatDuration(Duration(
                          milliseconds:
                              (_dragProgress * _duration.inMilliseconds)
                                  .round(),
                        )),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

              // 控制面板
              if (_showControls)
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildControlsOverlay(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlsOverlay() {
    final progress = _isDragging
        ? _dragProgress
        : (_duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0);

    return Column(
      children: [
        // 顶部渐变遮罩
        Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const Spacer(),
        // 底部渐变遮罩 + 控制栏
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: const Color(0xFFFB7299),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFFFB7299).withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChangeStart: (v) {
                    _isDragging = true;
                    _dragProgress = v;
                  },
                  onChanged: (v) {
                    setState(() => _dragProgress = v);
                  },
                  onChangeEnd: (v) {
                    final target = Duration(
                      milliseconds: (v * _duration.inMilliseconds).round(),
                    );
                    widget.player.seek(target);
                    setState(() => _isDragging = false);
                    _startHideTimer();
                  },
                ),
              ),
              // 底部信息行
              Row(
                children: [
                  // 播放/暂停
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Icon(
                      _isCompleted
                          ? Icons.replay_rounded
                          : (_isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 时间
                  Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 双击快进/快退动画反馈
class _SeekFeedback extends StatefulWidget {
  final IconData icon;
  final String label;

  const _SeekFeedback({required this.icon, required this.label});

  @override
  State<_SeekFeedback> createState() => _SeekFeedbackState();
}

class _SeekFeedbackState extends State<_SeekFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: Colors.white, size: 36),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
