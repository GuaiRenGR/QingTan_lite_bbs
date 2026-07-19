import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../api/api_client.dart';

class ImageCacheService {
  ImageCacheService._();

  static final ImageCacheService instance = ImageCacheService._();

  final CacheManager cacheManager = CacheManager(
    Config(
      'hjyz_bbs_images',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );

  final Queue<String> _preloadQueue = Queue<String>();
  final Set<String> _queuedUrls = <String>{};
  bool _preloading = false;

  String resolveUrl(String source) {
    return ApiClient.instance.resolveUrl(source);
  }

  CachedNetworkImageProvider provider(String source) {
    return CachedNetworkImageProvider(
      resolveUrl(source),
      cacheManager: cacheManager,
    );
  }

  void preload(Iterable<String> sources, {int maxItems = 8}) {
    var added = 0;
    for (final source in sources) {
      if (added >= maxItems) break;

      final url = resolveUrl(source);
      if (url.isEmpty || !_queuedUrls.add(url)) continue;

      _preloadQueue.add(url);
      added++;
    }

    if (!_preloading && _preloadQueue.isNotEmpty) {
      _drainPreloadQueue();
    }
  }

  Future<void> _drainPreloadQueue() async {
    _preloading = true;

    while (_preloadQueue.isNotEmpty) {
      final url = _preloadQueue.removeFirst();
      try {
        await cacheManager.getSingleFile(url);
      } catch (_) {
      } finally {
        _queuedUrls.remove(url);
      }

      await Future<void>.delayed(const Duration(milliseconds: 12));
    }

    _preloading = false;
  }
}
