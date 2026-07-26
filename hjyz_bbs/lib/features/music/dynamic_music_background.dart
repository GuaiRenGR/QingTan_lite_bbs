import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/services/music_cache_service.dart';
import 'music_player_controller.dart';

// Flutter translation/adaptation of NeriPlayer's HyperBackground and
// BgEffectPainter (GPL-3.0-or-later, Copyright 2025 NeriPlayer developers).
// The Android RuntimeShader, Palette and audio-reactive flow are represented
// here by a cross-platform CustomPainter, local palette quantizer and a
// playback-position envelope.
class DynamicMusicBackground extends StatefulWidget {
  final MusicTrack track;
  final bool playing;
  final Duration position;

  const DynamicMusicBackground({
    super.key,
    required this.track,
    required this.playing,
    required this.position,
  });

  @override
  State<DynamicMusicBackground> createState() =>
      _DynamicMusicBackgroundState();
}

class _DynamicMusicBackgroundState extends State<DynamicMusicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  MusicBackgroundPalette? _fromPalette;
  MusicBackgroundPalette? _targetPalette;
  Brightness? _brightness;
  var _paletteRevision = 0;
  var _loadRevision = 0;
  final _playbackClock = Stopwatch();
  Duration _positionAnchor = Duration.zero;
  Duration _clockAnchor = Duration.zero;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 62832),
    )..repeat();
    _playbackClock.start();
    _resetPositionAnchor();
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
    if (oldWidget.position != widget.position ||
        oldWidget.playing != widget.playing ||
        oldWidget.track.url != widget.track.url) {
      _resetPositionAnchor();
    }
    if (oldWidget.track.url != widget.track.url ||
        oldWidget.track.coverUrl != widget.track.coverUrl ||
        oldWidget.track.coverArt != widget.track.coverArt) {
      unawaited(_loadPalette());
    }
  }

  void _resetPositionAnchor() {
    _positionAnchor = widget.position;
    _clockAnchor = _playbackClock.elapsed;
  }

  Future<void> _loadPalette() async {
    final revision = ++_loadRevision;
    final dark = (_brightness ?? Theme.of(context).brightness) == Brightness.dark;
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
      _fromPalette = _targetPalette ?? fallback;
      _targetPalette = palette ?? fallback;
      _paletteRevision++;
    });
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fallback = MusicBackgroundPalette.fallback(
      Theme.of(context).colorScheme,
      dark: dark,
    );
    final from = _fromPalette ?? fallback;
    final target = _targetPalette ?? fallback;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_paletteRevision),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
        builder: (context, fraction, _) {
          final palette = MusicBackgroundPalette.lerp(from, target, fraction);
          return AnimatedBuilder(
            animation: _motionController,
            builder: (context, _) {
              final reactive = _reactiveValues(
                _effectivePosition(),
                playing: widget.playing,
              );
              return ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.scale(
                      scale: 1.18,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 30,
                          sigmaY: 30,
                          tileMode: ui.TileMode.mirror,
                        ),
                        child: CustomPaint(
                          isComplex: true,
                          willChange: true,
                          painter: _HyperBackgroundPainter(
                            palette: palette,
                            time: _motionController.value * math.pi * 20,
                            level: reactive.$1,
                            beat: reactive.$2,
                            dark: dark,
                          ),
                        ),
                      ),
                    ),
                    const CustomPaint(painter: _BackgroundGrainPainter()),
                    DecoratedBox(
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
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Duration _effectivePosition() {
    if (!widget.playing) return _positionAnchor;
    return _positionAnchor + (_playbackClock.elapsed - _clockAnchor);
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
      ..count++
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

class _HyperBackgroundPainter extends CustomPainter {
  static const _points = <(double, double, double)>[
    (0.52, 0.46, 0.92),
    (0.14, 0.32, 0.74),
    (0.92, 0.30, 0.76),
    (0.26, 0.88, 0.80),
    (0.84, 0.86, 0.84),
  ];

  final MusicBackgroundPalette palette;
  final double time;
  final double level;
  final double beat;
  final bool dark;

  const _HyperBackgroundPainter({
    required this.palette,
    required this.time,
    required this.level,
    required this.beat,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final levelEase = _smoothStep(0.04, 0.82, level);
    final beatEase = _smoothStep(0.03, 0.62, beat);
    final motionEase = (0.42 * levelEase + 0.82 * beatEase)
        .clamp(0.0, 1.0)
        .toDouble();
    final zoom = 1 + 0.024 * levelEase + 0.105 * beatEase;
    final pointOffset = 0.10 + 0.022 * levelEase + 0.108 * beatEase;
    final radiusMultiplier = 1 + 0.045 * levelEase + 0.220 * beatEase;
    final globalX = motionEase * 0.006 * math.sin(time * 1.9);
    final globalY = motionEase * 0.006 * math.cos(time * 1.6);
    final maxDimension = math.max(size.width, size.height);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = palette.colors.first,
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-size.width / 2, -size.height / 2);

    for (var index = 0; index < _points.length; index++) {
      final point = _points[index];
      var x = point.$1 + math.sin(time + point.$2) * pointOffset + globalX;
      var y = point.$2 + math.cos(time + point.$1) * pointOffset + globalY;
      final pushX = x - 0.5 + 0.0001;
      final pushY = y - 0.5 + 0.0001;
      final pushLength = math.sqrt(pushX * pushX + pushY * pushY);
      if (pushLength > 0) {
        final pushScale = beatEase * 0.118 / pushLength;
        x += pushX * pushScale;
        y += pushY * pushScale;
      }
      final radius = point.$3 * radiusMultiplier * maxDimension * 0.70;
      final center = Offset(x * size.width, y * size.height);
      final color = palette.colors[index];
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..blendMode = dark ? BlendMode.screen : BlendMode.softLight
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: dark ? 0.94 : 0.88),
            color.withValues(alpha: dark ? 0.34 : 0.28),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.46, 1],
        ).createShader(rect);
      canvas.drawCircle(center, radius, paint);
    }
    canvas.restore();
  }

  double _smoothStep(double edge0, double edge1, double value) {
    final t = ((value - edge0) / (edge1 - edge0))
        .clamp(0.0, 1.0)
        .toDouble();
    return t * t * (3 - 2 * t);
  }

  @override
  bool shouldRepaint(covariant _HyperBackgroundPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.level != level ||
      oldDelegate.beat != beat ||
      oldDelegate.dark != dark ||
      oldDelegate.palette != palette;
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
      canvas.drawPoint(Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundGrainPainter oldDelegate) => false;
}
