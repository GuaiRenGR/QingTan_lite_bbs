import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/music.dart';
import '../services/music_api_service.dart';

class MusicArtwork extends StatelessWidget {
  const MusicArtwork({
    super.key,
    required this.track,
    required this.size,
    this.borderRadius = 6,
  });

  final MusicTrack track;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: FutureBuilder<String>(
        future: MusicApiService.instance.resolveCoverUrl(track),
        builder: (context, snapshot) {
          final url = snapshot.data ?? '';
          if (url.isEmpty) return _fallback(context);
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => _fallback(context),
              errorWidget: (_, _, _) => _fallback(context),
            ),
          );
        },
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.42,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}
