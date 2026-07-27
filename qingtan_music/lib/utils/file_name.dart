String sanitizeFileComponent(String value, {required String fallback}) {
  var result = value.trim();
  result = result.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '、');
  result = result.replaceAll(RegExp(r'\s+'), ' ');
  result = result.replaceAll(RegExp(r'[. ]+$'), '');
  if (result.isEmpty) result = fallback;
  if (result.length > 80) result = result.substring(0, 80).trimRight();
  return result;
}

String buildDownloadBaseName(String title, String artist) {
  final safeTitle = sanitizeFileComponent(title, fallback: '未知歌曲');
  final safeArtist = sanitizeFileComponent(artist, fallback: '未知歌手');
  return '$safeTitle - $safeArtist';
}
