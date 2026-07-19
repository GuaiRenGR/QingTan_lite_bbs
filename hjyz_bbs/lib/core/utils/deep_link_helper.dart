class DeepLinkHelper {
  const DeepLinkHelper._();

  static String? locationFor(Uri uri) {
    if (uri.scheme.toLowerCase() != 'hyjzbbs') return null;

    final segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((segment) => segment.isNotEmpty),
    ];
    if (segments.length != 2) return null;

    final target = segments.first.toLowerCase();
    final value = segments.last;

    if (target == 'thread' || target == 'user') {
      final id = int.tryParse(value) ?? 0;
      return id > 0 ? '/$target/$id' : null;
    }

    if (target == 'dv' && value.isNotEmpty) {
      return '/dv/${Uri.encodeComponent(value)}';
    }

    return null;
  }
}
