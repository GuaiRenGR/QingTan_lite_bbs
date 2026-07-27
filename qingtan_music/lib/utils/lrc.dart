class LyricLine {
  const LyricLine({
    required this.time,
    required this.text,
    this.translation = '',
  });

  final Duration time;
  final String text;
  final String translation;

  LyricLine copyWith({String? translation}) {
    return LyricLine(
      time: time,
      text: text,
      translation: translation ?? this.translation,
    );
  }
}

final _timestampPattern = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

List<LyricLine> parseLrc(String raw) {
  final lines = <LyricLine>[];
  for (final row in raw.split(RegExp(r'\r?\n'))) {
    final matches = _timestampPattern.allMatches(row).toList(growable: false);
    if (matches.isEmpty) continue;
    final text = row.replaceAll(_timestampPattern, '').trim();
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fraction = match.group(3) ?? '';
      final milliseconds = fraction.isEmpty
          ? 0
          : fraction.length == 1
              ? (int.tryParse(fraction) ?? 0) * 100
              : fraction.length == 2
                  ? (int.tryParse(fraction) ?? 0) * 10
                  : int.tryParse(fraction.substring(0, 3)) ?? 0;
      lines.add(
        LyricLine(
          time: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
          text: text.isEmpty ? '…' : text,
        ),
      );
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

List<LyricLine> parseBilingualLrc(
  String original,
  String translated, {
  Duration tolerance = const Duration(milliseconds: 500),
}) {
  final originalLines = parseLrc(original);
  final translatedLines = parseLrc(translated);
  if (originalLines.isEmpty) return translatedLines;
  if (translatedLines.isEmpty) return originalLines;

  final merged = <LyricLine>[];
  var translatedIndex = 0;
  for (final originalLine in originalLines) {
    if (translatedIndex >= translatedLines.length) {
      merged.add(originalLine);
      continue;
    }
    while (translatedIndex + 1 < translatedLines.length &&
        _distance(
              translatedLines[translatedIndex + 1].time,
              originalLine.time,
            ) <
            _distance(
              translatedLines[translatedIndex].time,
              originalLine.time,
            )) {
      translatedIndex++;
    }

    final candidate = translatedLines[translatedIndex];
    final matches =
        _distance(candidate.time, originalLine.time) <= tolerance.inMilliseconds;
    merged.add(
      matches
          ? originalLine.copyWith(translation: candidate.text)
          : originalLine,
    );
    if (matches) translatedIndex++;
  }
  return merged;
}

String buildBilingualLrc(String original, String translated) {
  final originalLines = parseLrc(original);
  final translatedLines = parseLrc(translated);
  if (originalLines.isEmpty && translatedLines.isEmpty) return '';

  final entries = <({LyricLine line, bool translated})>[
    for (final line in originalLines) (line: line, translated: false),
    for (final line in translatedLines) (line: line, translated: true),
  ]..sort((a, b) {
      final byTime = a.line.time.compareTo(b.line.time);
      if (byTime != 0) return byTime;
      if (a.translated == b.translated) return 0;
      return a.translated ? 1 : -1;
    });

  return entries
      .map((entry) => '${_formatTimestamp(entry.line.time)}${entry.line.text}')
      .join('\n');
}

int _distance(Duration left, Duration right) =>
    (left.inMilliseconds - right.inMilliseconds).abs();

String _formatTimestamp(Duration value) {
  final totalMilliseconds = value.inMilliseconds.clamp(0, 359999999);
  final minutes = totalMilliseconds ~/ Duration.millisecondsPerMinute;
  final seconds =
      (totalMilliseconds ~/ Duration.millisecondsPerSecond).remainder(60);
  final milliseconds = totalMilliseconds.remainder(1000);
  return '[${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${milliseconds.toString().padLeft(3, '0')}]';
}

int activeLyricIndex(List<LyricLine> lines, Duration position) {
  if (lines.isEmpty || position < lines.first.time) return -1;
  var low = 0;
  var high = lines.length - 1;
  while (low <= high) {
    final middle = (low + high) >> 1;
    if (lines[middle].time <= position) {
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }
  return high;
}
