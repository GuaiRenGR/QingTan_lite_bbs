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
        child: Video(
          controller: controller,
          controls: AdaptiveVideoControls,
        ),
      ),
    );
  }
}
