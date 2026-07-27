import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/music.dart';
import '../services/music_api_service.dart';

class DynamicMusicBackground extends StatefulWidget {
  const DynamicMusicBackground({
    super.key,
    required this.track,
    required this.playing,
    required this.advancedBlur,
    required this.musicReactive,
    required this.dynamicBackground,
    required this.coverBlurBackground,
    required this.coverBlurAmount,
    required this.coverBlurDarken,
  });

  final MusicTrack track;
  final bool playing;
  final bool advancedBlur;
  final bool musicReactive;
  final bool dynamicBackground;
  final bool coverBlurBackground;
  final double coverBlurAmount;
  final double coverBlurDarken;

  @override
  State<DynamicMusicBackground> createState() =>
      _DynamicMusicBackgroundState();
}

class _DynamicMusicBackgroundState extends State<DynamicMusicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  _CoverPalette? _palette;
  String _coverUrl = '';
  var _loadRevision = 0;

  bool get _shouldAnimate =>
      widget.dynamicBackground || (widget.musicReactive && widget.playing);

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    );
    _syncMotion();
    unawaited(_loadCover());
  }

  @override
  void didUpdateWidget(covariant DynamicMusicBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.key != widget.track.key ||
        oldWidget.track.coverUrl != widget.track.coverUrl) {
      unawaited(_loadCover());
    }
    if (oldWidget.playing != widget.playing ||
        oldWidget.dynamicBackground != widget.dynamicBackground ||
        oldWidget.musicReactive != widget.musicReactive) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (_shouldAnimate) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  Future<void> _loadCover() async {
    final revision = ++_loadRevision;
    var url = '';
    _CoverPalette? palette;
    try {
      url = await MusicApiService.instance.resolveCoverUrl(widget.track);
      palette = url.isEmpty ? null : await _paletteForUrl(url);
    } catch (_) {}
    if (!mounted || revision != _loadRevision) return;
    setState(() {
      _coverUrl = url;
      _palette = palette;
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _palette ?? _CoverPalette.fallback(Theme.of(context));
    if (widget.coverBlurBackground && _coverUrl.isNotEmpty) {
      return RepaintBoundary(
        child: _BlurredCoverBackground(
          url: _coverUrl,
          fallback: colors,
          blurAmount: widget.coverBlurAmount,
          darken: widget.coverBlurDarken,
        ),
      );
    }

    Widget background = AnimatedBuilder(
      animation: _motion,
      builder: (context, _) => CustomPaint(
        painter: _DynamicPalettePainter(
          palette: colors,
          phase: _motion.value * math.pi * 2,
          dynamicBackground: widget.dynamicBackground,
          musicReactive: widget.musicReactive,
          playing: widget.playing,
        ),
      ),
    );
    if (widget.advancedBlur) {
      background = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
          tileMode: ui.TileMode.mirror,
        ),
        child: Transform.scale(scale: 1.08, child: background),
      );
    }
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          background,
          const _BackgroundShade(),
        ],
      ),
    );
  }
}

class _BlurredCoverBackground extends StatelessWidget {
  const _BlurredCoverBackground({
    required this.url,
    required this.fallback,
    required this.blurAmount,
    required this.darken,
  });

  final String url;
  final _CoverPalette fallback;
  final double blurAmount;
  final double darken;

  @override
  Widget build(BuildContext context) {
    final normalizedBlur = blurAmount.clamp(0, 500).toDouble();
    final normalizedDarken = darken.clamp(0, 0.8).toDouble();
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _DynamicPalettePainter(
            palette: fallback,
            phase: 0,
            dynamicBackground: false,
            musicReactive: false,
            playing: false,
          ),
        ),
        Transform.scale(
          scale: 1.25,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: normalizedBlur,
              sigmaY: normalizedBlur,
              tileMode: ui.TileMode.clamp,
            ),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        if (normalizedDarken > 0)
          ColoredBox(color: Colors.black.withValues(alpha: normalizedDarken)),
        const _BackgroundShade(),
      ],
    );
  }
}

class _BackgroundShade extends StatelessWidget {
  const _BackgroundShade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x30000000),
            Color(0x08000000),
            Color(0x52000000),
          ],
          stops: [0, 0.48, 1],
        ),
      ),
    );
  }
}

class _DynamicPalettePainter extends CustomPainter {
  const _DynamicPalettePainter({
    required this.palette,
    required this.phase,
    required this.dynamicBackground,
    required this.musicReactive,
    required this.playing,
  });

  final _CoverPalette palette;
  final double phase;
  final bool dynamicBackground;
  final bool musicReactive;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        [palette.base, palette.dark],
      );
    canvas.drawRect(rect, background);

    final motion = dynamicBackground ? phase : 0.0;
    final pulse = musicReactive && playing
        ? 1 + 0.13 * (0.5 + 0.5 * math.sin(phase * 9))
        : 1.0;
    final shortest = math.min(size.width, size.height);
    final blobs = [
      (
        Offset(
          size.width * (0.24 + 0.12 * math.sin(motion)),
          size.height * (0.24 + 0.08 * math.cos(motion * 0.8)),
        ),
        palette.accent,
        shortest * 0.92 * pulse,
      ),
      (
        Offset(
          size.width * (0.80 + 0.10 * math.cos(motion * 0.7)),
          size.height * (0.40 + 0.14 * math.sin(motion * 1.1)),
        ),
        palette.light,
        shortest * 0.78 * pulse,
      ),
      (
        Offset(
          size.width * (0.46 + 0.16 * math.cos(motion * 0.9)),
          size.height * (0.86 + 0.07 * math.sin(motion * 1.3)),
        ),
        palette.bridge,
        shortest * 1.02 * pulse,
      ),
    ];
    for (final blob in blobs) {
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          blob.$1,
          blob.$3,
          [
            blob.$2.withValues(alpha: 0.78),
            blob.$2.withValues(alpha: 0),
          ],
        );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DynamicPalettePainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.phase != phase ||
        oldDelegate.dynamicBackground != dynamicBackground ||
        oldDelegate.musicReactive != musicReactive ||
        oldDelegate.playing != playing;
  }
}

class _CoverPalette {
  const _CoverPalette({
    required this.base,
    required this.accent,
    required this.light,
    required this.dark,
    required this.bridge,
  });

  final Color base;
  final Color accent;
  final Color light;
  final Color dark;
  final Color bridge;

  factory _CoverPalette.fallback(ThemeData theme) {
    final colors = theme.colorScheme;
    return _CoverPalette(
      base: _darken(colors.primaryContainer, 0.30),
      accent: colors.primary,
      light: colors.tertiary,
      dark: _darken(colors.surface, 0.10),
      bridge: colors.secondary,
    );
  }
}

final _paletteCache = <String, _CoverPalette>{};
final _paletteLoads = <String, Future<_CoverPalette?>>{};

Future<_CoverPalette?> _paletteForUrl(String url) {
  final cached = _paletteCache[url];
  if (cached != null) return Future.value(cached);
  return _paletteLoads.putIfAbsent(url, () async {
    try {
      final image = await _loadNetworkImage(url);
      if (image == null) return null;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      var red = 0;
      var green = 0;
      var blue = 0;
      var count = 0;
      final pixelCount = bytes.length ~/ 4;
      final stride = math.max(1, pixelCount ~/ 2048);
      for (var pixel = 0; pixel < pixelCount; pixel += stride) {
        final offset = pixel * 4;
        if (bytes[offset + 3] < 180) continue;
        red += bytes[offset];
        green += bytes[offset + 1];
        blue += bytes[offset + 2];
        count++;
      }
      if (count == 0) return null;
      final base = Color.fromARGB(
        255,
        red ~/ count,
        green ~/ count,
        blue ~/ count,
      );
      final hsl = HSLColor.fromColor(base);
      final accent = hsl
          .withSaturation(math.max(0.46, hsl.saturation))
          .withLightness(0.50)
          .toColor();
      final light = hsl.withLightness(0.66).toColor();
      final dark = hsl
          .withSaturation(hsl.saturation * 0.72)
          .withLightness(0.16)
          .toColor();
      final palette = _CoverPalette(
        base: hsl.withLightness(0.30).toColor(),
        accent: accent,
        light: light,
        dark: dark,
        bridge: Color.lerp(accent, base, 0.48)!,
      );
      _paletteCache[url] = palette;
      if (_paletteCache.length > 64) {
        _paletteCache.remove(_paletteCache.keys.first);
      }
      return palette;
    } finally {
      _paletteLoads.remove(url);
    }
  });
}

Future<ui.Image?> _loadNetworkImage(String url) async {
  final completer = Completer<ui.Image?>();
  final stream = NetworkImage(url).resolve(
    const ImageConfiguration(size: Size(128, 128)),
  );
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image);
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!completer.isCompleted) completer.complete(null);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future.timeout(
    const Duration(seconds: 8),
    onTimeout: () {
      stream.removeListener(listener);
      return null;
    },
  );
}

Future<Color?> loadMusicCoverSeedColor(MusicTrack track) async {
  try {
    final url = await MusicApiService.instance.resolveCoverUrl(track);
    return (url.isEmpty ? null : await _paletteForUrl(url))?.accent;
  } catch (_) {
    return null;
  }
}

Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0, 1).toDouble())
      .toColor();
}
