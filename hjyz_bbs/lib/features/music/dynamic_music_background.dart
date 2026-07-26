import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/services/music_cache_service.dart';
import 'music_player_controller.dart';

// Flutter translation/adaptation of NeriPlayer's HyperBackground and
// BgEffectPainter (GPL-3.0-or-later, Copyright 2025 NeriPlayer developers).
// RuntimeShader is replaced by an opt-in cross-platform CustomPainter. The
// default path is a cached static gradient because Flutter's full-screen blur
// is substantially more expensive than NeriPlayer's Android GPU shader.
class DynamicMusicBackground extends StatefulWidget {
  final MusicTrack track;
  final bool playing;
  final bool advancedBlur;
  final bool musicReactive;
  final bool dynamicBackground;
  final bool coverBlurBackground;
  final double coverBlurAmount;
  final double coverBlurDarken;

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

  @override
  State<DynamicMusicBackground> createState() =>
      _DynamicMusicBackgroundState();
}

class _DynamicMusicBackgroundState extends State<DynamicMusicBackground>
    with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _shaderProgram;
  static const _normalFrameInterval = Duration(milliseconds: 33);
  static const _blurFrameInterval = Duration(milliseconds: 50);

  late final AnimationController _motionController;
  final _frameRepaint = ChangeNotifier();
  final _reactiveClock = Stopwatch();
  MusicBackgroundPalette? _targetPalette;
  ui.FragmentShader? _shader;
  bool _shaderLoading = false;
  Brightness? _brightness;
  var _loadRevision = 0;
  Duration _lastMotionFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 62832),
    )..addListener(_onMotionTick);
    _syncAnimationState();
    unawaited(_ensureShader());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_brightness == brightness) return;
    _brightness = brightness;
    unawaited(_loadPalette());
  }

  @override
  void didUpdateWidget(covariant DynamicMusicBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.url != widget.track.url) {
      _reactiveClock.reset();
    }
    if (oldWidget.track.url != widget.track.url ||
        oldWidget.track.coverUrl != widget.track.coverUrl ||
        oldWidget.track.coverArt != widget.track.coverArt) {
      unawaited(_loadPalette());
    }
    if (oldWidget.playing != widget.playing ||
        oldWidget.advancedBlur != widget.advancedBlur ||
        oldWidget.musicReactive != widget.musicReactive ||
        oldWidget.dynamicBackground != widget.dynamicBackground ||
        oldWidget.coverBlurBackground != widget.coverBlurBackground) {
      _syncAnimationState();
      unawaited(_ensureShader());
    }
  }

  bool get _shouldAnimate =>
      widget.dynamicBackground || (widget.musicReactive && widget.playing);

  void _syncAnimationState() {
    if (_shouldAnimate) {
      if (!_motionController.isAnimating) {
        _lastMotionFrame = Duration.zero;
        _motionController.repeat();
      }
    } else {
      _motionController.stop();
    }

    if (widget.musicReactive && widget.playing) {
      if (!_reactiveClock.isRunning) _reactiveClock.start();
    } else {
      _reactiveClock.stop();
    }
  }

  void _onMotionTick() {
    final elapsed = _motionController.lastElapsedDuration;
    if (elapsed == null) return;
    final interval = widget.advancedBlur
        ? _blurFrameInterval
        : _normalFrameInterval;
    if (elapsed - _lastMotionFrame < interval) return;
    _lastMotionFrame = elapsed;
    _frameRepaint.notifyListeners();
  }

  Future<void> _ensureShader() async {
    final effectsEnabled = widget.advancedBlur ||
        widget.musicReactive ||
        widget.dynamicBackground;
    if (!effectsEnabled || _shader != null || _shaderLoading) return;
    _shaderLoading = true;
    try {
      final program = await (_shaderProgram ??=
          ui.FragmentProgram.fromAsset('shaders/music_background.frag'));
      final shader = program.fragmentShader();
      if (!mounted) return;
      setState(() => _shader = shader);
    } catch (_) {
      _shaderProgram = null;
    } finally {
      _shaderLoading = false;
    }
  }

  Future<void> _loadPalette() async {
    final revision = ++_loadRevision;
    const dark = true;
    final loadedImage = await _loadCoverImage(widget.track);
    MusicBackgroundPalette? palette;
    if (loadedImage != null) {
      try {
        palette = await MusicBackgroundPalette.fromImage(
          loadedImage.image,
          dark: dark,
        );
      } catch (_) {}
      if (loadedImage.owned) loadedImage.image.dispose();
    }
    if (!mounted || revision != _loadRevision) return;

    final fallback = MusicBackgroundPalette.fallback(
      Theme.of(context).colorScheme,
      dark: dark,
    );
    setState(() {
      _targetPalette = palette ?? fallback;
    });
  }

  @override
  void dispose() {
    _motionController.dispose();
    _frameRepaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dark = true;
    final fallback = MusicBackgroundPalette.fallback(
      Theme.of(context).colorScheme,
      dark: dark,
    );
    final palette = _targetPalette ?? fallback;
    if (widget.coverBlurBackground) {
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _StaticPaletteBackground(palette: palette, dark: true),
            _BlurredCoverBackground(
              track: widget.track,
              blurAmount: widget.coverBlurAmount,
              darken: widget.coverBlurDarken,
            ),
          ],
        ),
      );
    }
    final effectsEnabled = widget.advancedBlur ||
        widget.musicReactive ||
        widget.dynamicBackground;

    if (!effectsEnabled) {
      return RepaintBoundary(
        child: _StaticPaletteBackground(palette: palette, dark: dark),
      );
    }

    final shader = _shader;
    if (shader == null) {
      return RepaintBoundary(
        child: _StaticPaletteBackground(palette: palette, dark: dark),
      );
    }

    Widget effect = CustomPaint(
      isComplex: true,
      willChange: _shouldAnimate,
      painter: _GpuBackgroundPainter(
        shader: shader,
        palette: palette,
        motion: _motionController,
        reactiveClock: _reactiveClock,
        playing: widget.playing,
        musicReactive: widget.musicReactive,
        dynamicBackground: widget.dynamicBackground,
        dark: dark,
        repaint: _frameRepaint,
      ),
    );
    if (widget.advancedBlur) {
      effect = _DownsampledBlur(child: effect);
    }

    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            effect,
            const RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                willChange: false,
                painter: _BackgroundGrainPainter(),
              ),
            ),
            _BackgroundShade(dark: dark),
          ],
        ),
      ),
    );
  }
}

class _StaticPaletteBackground extends StatelessWidget {
  final MusicBackgroundPalette palette;
  final bool dark;

  const _StaticPaletteBackground({required this.palette, required this.dark});

  @override
  Widget build(BuildContext context) {
    final base = palette.colors[0];
    final accent = palette.colors[1];
    final low = palette.colors[3];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, dark ? Colors.black : Colors.white, 0.12)!,
            Color.lerp(accent, base, 0.58)!,
            Color.lerp(low, dark ? Colors.black : Colors.white, 0.18)!,
          ],
          stops: const [0, 0.52, 1],
        ),
      ),
      child: _BackgroundShade(dark: dark),
    );
  }
}

class _BlurredCoverBackground extends StatefulWidget {
  final MusicTrack track;
  final double blurAmount;
  final double darken;

  const _BlurredCoverBackground({
    required this.track,
    required this.blurAmount,
    required this.darken,
  });

  @override
  State<_BlurredCoverBackground> createState() =>
      _BlurredCoverBackgroundState();
}

class _BlurredCoverBackgroundState extends State<_BlurredCoverBackground> {
  _CoverVisual? _visual;
  var _loadRevision = 0;
  var _dependenciesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _dependenciesReady = true;
    unawaited(_resolveCover());
  }

  @override
  void didUpdateWidget(covariant _BlurredCoverBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.url != widget.track.url ||
        oldWidget.track.coverUrl != widget.track.coverUrl ||
        oldWidget.track.coverArt != widget.track.coverArt) {
      unawaited(_resolveCover());
    }
  }

  Future<void> _resolveCover() async {
    final revision = ++_loadRevision;
    final track = widget.track;
    Uint8List? bytes = track.coverArt;
    ImageProvider<Object>? provider;
    var key = 'cover:${track.url}';

    if (bytes == null || bytes.isEmpty) {
      final source = track.coverUrl?.trim() ?? '';
      if (source.isNotEmpty) {
        final resolved = MusicCacheService.instance.resolveUrl(source);
        if (resolved.isNotEmpty) {
          provider = ResizeImage.resizeIfNeeded(
            640,
            640,
            NetworkImage(resolved),
          );
          key = 'network:$resolved';
        }
      } else {
        try {
          bytes = (await MusicCacheService.instance.loadMetadata(track.url))
              .coverArt;
        } catch (_) {}
      }
    }

    if (provider == null && bytes != null && bytes.isNotEmpty) {
      provider = ResizeImage.resizeIfNeeded(
        384,
        384,
        MemoryImage(bytes),
      );
      key = 'memory:${track.url}:${bytes.length}:${identityHashCode(bytes)}';
    }

    if (!mounted || revision != _loadRevision) return;
    final resolvedProvider = provider;
    if (resolvedProvider == null) {
      setState(() => _visual = null);
      return;
    }

    try {
      await precacheImage(resolvedProvider, context);
    } catch (_) {
      return;
    }
    if (!mounted || revision != _loadRevision) return;
    setState(() => _visual = _CoverVisual(key, resolvedProvider));
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visual;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: visual == null
          ? const SizedBox.expand(key: ValueKey('no-cover'))
          : _BlurredCoverImage(
              key: ValueKey(visual.key),
              provider: visual.provider,
              blurAmount: widget.blurAmount,
              darken: widget.darken,
            ),
    );
  }
}

class _CoverVisual {
  final String key;
  final ImageProvider<Object> provider;

  const _CoverVisual(this.key, this.provider);
}

class _BlurredCoverImage extends StatelessWidget {
  static const _renderScale = 0.35;

  final ImageProvider<Object> provider;
  final double blurAmount;
  final double darken;

  const _BlurredCoverImage({
    super.key,
    required this.provider,
    required this.blurAmount,
    required this.darken,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedBlur = blurAmount.clamp(0.0, 500.0).toDouble();
    final normalizedDarken = darken.clamp(0.0, 0.8).toDouble();
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: SizedBox(
                  width: constraints.maxWidth * _renderScale,
                  height: constraints.maxHeight * _renderScale,
                  child: Transform.scale(
                    scale: 1 / _renderScale,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: normalizedBlur * _renderScale,
                        sigmaY: normalizedBlur * _renderScale,
                        tileMode: ui.TileMode.clamp,
                      ),
                      child: Image(
                        image: provider,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (normalizedDarken > 0)
            ColoredBox(
              color: Colors.black.withValues(alpha: normalizedDarken),
            ),
        ],
      ),
    );
  }
}

class _BackgroundShade extends StatelessWidget {
  final bool dark;

  const _BackgroundShade({required this.dark});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [
                  Color(0x30000000),
                  Color(0x08000000),
                  Color(0x52000000),
                ]
              : const [
                  Color(0x18FFFFFF),
                  Color(0x06FFFFFF),
                  Color(0x3DFFFFFF),
                ],
          stops: const [0, 0.48, 1],
        ),
      ),
    );
  }
}

class _DownsampledBlur extends StatelessWidget {
  // Keep the apparent blur radius while rasterizing a much smaller layer.
  static const _renderScale = 0.28;
  static const _overscan = 1.18;

  final Widget child;

  const _DownsampledBlur({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SizedBox(
            width: constraints.maxWidth * _renderScale,
            height: constraints.maxHeight * _renderScale,
            child: Transform.scale(
              scale: _overscan / _renderScale,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 8.4,
                  sigmaY: 8.4,
                  tileMode: ui.TileMode.mirror,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

(double, double) _reactiveValues(
  Duration position, {
  required bool playing,
}) {
  if (!playing) return (0, 0);
  final seconds = position.inMilliseconds / 1000;
  final level = (0.46 +
          math.sin(seconds * 2.31) * 0.16 +
          math.sin(seconds * 5.17 + 1.2) * 0.11)
      .clamp(0.08, 0.92)
      .toDouble();
  final beatPhase = (seconds * 2.0) % 1.0;
  final beat = math.exp(-beatPhase * 8.5).clamp(0.0, 1.0).toDouble();
  return (level, beat);
}

class _LoadedCoverImage {
  final ui.Image image;
  final bool owned;

  const _LoadedCoverImage(this.image, {required this.owned});
}

Future<_LoadedCoverImage?> _loadCoverImage(MusicTrack track) async {
  Uint8List? bytes = track.coverArt;
  if (bytes == null) {
    try {
      bytes = (await MusicCacheService.instance.loadMetadata(track.url)).coverArt;
    } catch (_) {}
  }
  if (bytes != null && bytes.isNotEmpty) {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 128,
        targetHeight: 128,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return _LoadedCoverImage(frame.image, owned: true);
    } catch (_) {}
  }

  final source = track.coverUrl?.trim() ?? '';
  if (source.isEmpty) return null;
  final url = MusicCacheService.instance.resolveUrl(source);
  if (url.isEmpty) return null;

  final completer = Completer<_LoadedCoverImage?>();
  final stream = NetworkImage(url).resolve(
    const ImageConfiguration(size: Size(128, 128)),
  );
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) {
        completer.complete(_LoadedCoverImage(info.image, owned: false));
      }
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

final _musicCoverSeedCache = <String, Color>{};
final _musicCoverSeedLoads = <String, Future<Color?>>{};

Future<Color?> loadMusicCoverSeedColor(MusicTrack track) {
  final coverArt = track.coverArt;
  final key = [
    track.url,
    track.coverUrl ?? '',
    coverArt?.length ?? 0,
    coverArt == null ? 0 : identityHashCode(coverArt),
  ].join('|');
  final cached = _musicCoverSeedCache[key];
  if (cached != null) return Future.value(cached);

  return _musicCoverSeedLoads.putIfAbsent(key, () async {
    try {
      final loadedImage = await _loadCoverImage(track);
      if (loadedImage == null) return null;
      try {
        final data = await loadedImage.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (data == null) return null;
        final swatches = _quantize(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        if (swatches.isEmpty) return null;

        final dominant = swatches.first.color;
        final muted = _pickSwatch(swatches, (hsl) => 1 - hsl.saturation);
        final vibrant = _pickSwatch(swatches, (hsl) => hsl.saturation);
        final seed = vibrant ?? muted ?? dominant;
        _musicCoverSeedCache[key] = seed;
        if (_musicCoverSeedCache.length > 64) {
          _musicCoverSeedCache.remove(_musicCoverSeedCache.keys.first);
        }
        return seed;
      } finally {
        if (loadedImage.owned) loadedImage.image.dispose();
      }
    } finally {
      _musicCoverSeedLoads.remove(key);
    }
  });
}

enum _PaletteRole { base, accent, light, dark, bridge }

class MusicBackgroundPalette {
  final List<Color> colors;

  const MusicBackgroundPalette(this.colors);

  factory MusicBackgroundPalette.fallback(
    ColorScheme scheme, {
    required bool dark,
  }) {
    final base = scheme.primaryContainer;
    final accent = scheme.tertiary;
    return MusicBackgroundPalette([
      _softenColor(base, base, dark, _PaletteRole.base),
      _softenColor(accent, base, dark, _PaletteRole.accent),
      _softenColor(scheme.secondaryContainer, base, dark, _PaletteRole.light),
      _softenColor(scheme.surfaceContainerLowest, base, dark, _PaletteRole.dark),
      _softenColor(
        Color.lerp(accent, base, 0.42)!,
        base,
        dark,
        _PaletteRole.bridge,
      ),
    ]);
  }

  static Future<MusicBackgroundPalette> fromImage(
    ui.Image image, {
    required bool dark,
  }) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw StateError('Unable to read cover pixels');
    final swatches = _quantize(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    if (swatches.isEmpty) throw StateError('Cover palette is empty');

    final dominant = swatches.first.color;
    final muted = _pickSwatch(swatches, (hsl) => 1 - hsl.saturation) ?? dominant;
    final vibrant = _pickSwatch(swatches, (hsl) => hsl.saturation) ?? dominant;
    final light = _pickSwatch(
          swatches,
          (hsl) => hsl.lightness * 0.72 + hsl.saturation * 0.28,
        ) ??
        vibrant;
    final darkColor = _pickSwatch(
          swatches,
          (hsl) => (1 - hsl.lightness) * 0.76 + hsl.saturation * 0.24,
        ) ??
        dominant;
    final base = muted;
    final accent = _ensureAccent(vibrant, base);
    final bridge = Color.lerp(Color.lerp(accent, light, 0.5), base, 0.24)!;

    return MusicBackgroundPalette([
      _softenColor(base, base, dark, _PaletteRole.base),
      _softenColor(accent, base, dark, _PaletteRole.accent),
      _softenColor(light, base, dark, _PaletteRole.light),
      _softenColor(darkColor, base, dark, _PaletteRole.dark),
      _softenColor(bridge, base, dark, _PaletteRole.bridge),
    ]);
  }

  static MusicBackgroundPalette lerp(
    MusicBackgroundPalette from,
    MusicBackgroundPalette to,
    double fraction,
  ) {
    return MusicBackgroundPalette([
      for (var index = 0; index < 5; index++)
        Color.lerp(from.colors[index], to.colors[index], fraction)!,
    ]);
  }
}

class _ColorBin {
  int count = 0;
  int red = 0;
  int green = 0;
  int blue = 0;

  Color get color => Color.fromARGB(
        255,
        red ~/ count,
        green ~/ count,
        blue ~/ count,
      );
}

class _ColorSwatch {
  final Color color;
  final int population;

  const _ColorSwatch(this.color, this.population);
}

List<_ColorSwatch> _quantize(Uint8List pixels) {
  final bins = <int, _ColorBin>{};
  final pixelCount = pixels.length ~/ 4;
  final stride = math.max(1, pixelCount ~/ 4096);
  for (var pixel = 0; pixel < pixelCount; pixel += stride) {
    final offset = pixel * 4;
    if (pixels[offset + 3] < 180) continue;
    final red = pixels[offset];
    final green = pixels[offset + 1];
    final blue = pixels[offset + 2];
    final key = (red >> 4) << 8 | (green >> 4) << 4 | (blue >> 4);
    final bin = bins.putIfAbsent(key, _ColorBin.new);
    bin
      ..count += 1
      ..red += red
      ..green += green
      ..blue += blue;
  }
  final result = bins.values
      .where((bin) => bin.count > 0)
      .map((bin) => _ColorSwatch(bin.color, bin.count))
      .toList()
    ..sort((a, b) => b.population.compareTo(a.population));
  return result.take(16).toList();
}

Color? _pickSwatch(
  List<_ColorSwatch> swatches,
  double Function(HSLColor hsl) score,
) {
  _ColorSwatch? best;
  var bestScore = -double.infinity;
  final maxPopulation = swatches.first.population;
  for (final swatch in swatches) {
    final hsl = HSLColor.fromColor(swatch.color);
    final populationScore =
        (swatch.population / maxPopulation).clamp(0.0, 1.0).toDouble();
    final value = score(hsl) * 0.78 + populationScore * 0.22;
    if (value > bestScore) {
      best = swatch;
      bestScore = value;
    }
  }
  return best?.color;
}

Color _ensureAccent(Color color, Color fallback) {
  var hsl = HSLColor.fromColor(color);
  if (hsl.saturation >= 0.24) return color;
  final fallbackHsl = HSLColor.fromColor(fallback);
  final hue = hsl.saturation > 0.04
      ? hsl.hue
      : fallbackHsl.saturation > 0.04
          ? fallbackHsl.hue
          : 320.0;
  hsl = hsl.withHue(hue).withSaturation(0.48).withLightness(
        hsl.lightness.clamp(0.40, 0.68).toDouble(),
      );
  return hsl.toColor();
}

Color _softenColor(
  Color raw,
  Color anchor,
  bool dark,
  _PaletteRole role,
) {
  final rawHsl = HSLColor.fromColor(raw);
  final anchorHsl = HSLColor.fromColor(anchor);
  final hueDifference = (rawHsl.hue - anchorHsl.hue).abs() % 360;
  final hueDistance = math.min(hueDifference, 360 - hueDifference);
  final hueConflict = hueDistance > 105 &&
      rawHsl.saturation > 0.28 &&
      anchorHsl.saturation > 0.20;
  final anchorBlend = switch (role) {
    _PaletteRole.base => 0.08,
    _PaletteRole.accent => hueConflict ? 0.18 : 0.04,
    _PaletteRole.light => hueConflict ? 0.24 : 0.08,
    _PaletteRole.dark => hueConflict ? 0.42 : 0.22,
    _PaletteRole.bridge => 0.20,
  };
  var hsl = HSLColor.fromColor(Color.lerp(raw, anchor, anchorBlend)!);
  final saturationScale = switch (role) {
    _PaletteRole.base => 0.94,
    _PaletteRole.accent => 1.14,
    _PaletteRole.light => 1.02,
    _PaletteRole.dark => 0.76,
    _PaletteRole.bridge => 0.96,
  };
  final saturationMax = role == _PaletteRole.accent
      ? (dark ? 0.70 : 0.64)
      : (dark ? 0.64 : 0.56);
  final saturationFloor = hsl.saturation < 0.05
      ? (role == _PaletteRole.accent ? 0.30 : 0.0)
      : role == _PaletteRole.dark
          ? 0.10
          : role == _PaletteRole.accent
              ? 0.30
              : 0.14;
  final targetLightness = switch (role) {
    _PaletteRole.base => dark ? 0.34 : 0.58,
    _PaletteRole.accent => dark ? 0.48 : 0.66,
    _PaletteRole.light => dark ? 0.62 : 0.82,
    _PaletteRole.dark => dark ? 0.18 : 0.34,
    _PaletteRole.bridge => dark ? 0.46 : 0.66,
  };
  final lightnessBlend = switch (role) {
    _PaletteRole.base => 0.18,
    _PaletteRole.accent => 0.18,
    _PaletteRole.light => 0.24,
    _PaletteRole.dark => 0.34,
    _PaletteRole.bridge => 0.20,
  };
  hsl = hsl
      .withSaturation(
        (hsl.saturation * saturationScale)
            .clamp(saturationFloor, saturationMax)
            .toDouble(),
      )
      .withLightness(
        ui.lerpDouble(hsl.lightness, targetLightness, lightnessBlend)!
            .clamp(dark ? 0.12 : 0.28, dark ? 0.66 : 0.86)
            .toDouble(),
      );
  return hsl.toColor();
}

class _GpuBackgroundPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final MusicBackgroundPalette palette;
  final Animation<double> motion;
  final Stopwatch reactiveClock;
  final bool playing;
  final bool musicReactive;
  final bool dynamicBackground;
  final bool dark;
  final Paint _paint;

  _GpuBackgroundPainter({
    required this.shader,
    required this.palette,
    required this.motion,
    required this.reactiveClock,
    required this.playing,
    required this.musicReactive,
    required this.dynamicBackground,
    required this.dark,
    required Listenable repaint,
  })  : _paint = (Paint()..shader = shader),
        super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final time = motion.value * math.pi * 20;
    final reactive = musicReactive
        ? _reactiveValues(reactiveClock.elapsed, playing: playing)
        : (0.0, 0.0);
    final level = reactive.$1;
    final beat = reactive.$2;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, level)
      ..setFloat(4, beat)
      ..setFloat(5, dynamicBackground ? 1 : 0);
    for (var index = 0; index < palette.colors.length; index++) {
      final color = palette.colors[index];
      final offset = 6 + index * 4;
      shader
        ..setFloat(offset, color.r)
        ..setFloat(offset + 1, color.g)
        ..setFloat(offset + 2, color.b)
        ..setFloat(offset + 3, color.a);
    }
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(covariant _GpuBackgroundPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.palette != palette ||
      oldDelegate.motion != motion ||
      oldDelegate.reactiveClock != reactiveClock ||
      oldDelegate.playing != playing ||
      oldDelegate.musicReactive != musicReactive ||
      oldDelegate.dynamicBackground != dynamicBackground ||
      oldDelegate.dark != dark;
}

class _BackgroundGrainPainter extends CustomPainter {
  const _BackgroundGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 0.8;
    for (var index = 0; index < 720; index++) {
      final x = ((index * 73) % 997) / 997 * size.width;
      final y = ((index * 151 + 47) % 991) / 991 * size.height;
      final light = index.isEven;
      paint.color = (light ? Colors.white : Colors.black).withValues(
        alpha: light ? 0.020 : 0.014,
      );
      canvas.drawCircle(Offset(x, y), 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundGrainPainter oldDelegate) => false;
}
