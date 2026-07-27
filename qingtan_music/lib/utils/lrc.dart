class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
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
