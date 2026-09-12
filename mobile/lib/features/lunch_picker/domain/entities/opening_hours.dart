enum OpeningStatus { open, closed, unknown }

/// Thin wrapper around an OSM `opening_hours` string. Parsing is
/// intentionally forgiving: it only understands "HH:MM-HH:MM" ranges (and
/// "24/7"), ignores day-of-week rules, and falls back to [unknown] rather
/// than guessing wrong.
class OpeningHours {
  const OpeningHours(this.raw);

  final String raw;

  static final _rangePattern = RegExp(
    r'(\d{1,2}):(\d{2})\s*[-–—]\s*(\d{1,2}):(\d{2})',
  );

  OpeningStatus statusAt(DateTime now) {
    if (raw.trim().isEmpty) return OpeningStatus.unknown;
    if (raw.contains('24/7')) return OpeningStatus.open;

    final ranges = _rangePattern.allMatches(raw).toList();
    if (ranges.isEmpty) return OpeningStatus.unknown;

    final minutesNow = now.hour * 60 + now.minute;
    for (final m in ranges) {
      final start = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
      var end = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
      if (end == 0) end = 24 * 60;
      if (end < start) end += 24 * 60; // crosses midnight
      if (minutesNow >= start && minutesNow <= end) return OpeningStatus.open;
    }
    return OpeningStatus.closed;
  }

  String label(DateTime now) {
    switch (statusAt(now)) {
      case OpeningStatus.open:
        return raw.contains('24/7') ? 'mở 24/7' : 'đang mở';
      case OpeningStatus.closed:
        return 'đang đóng';
      case OpeningStatus.unknown:
        return raw.trim().isEmpty ? 'giờ mở: chưa rõ' : raw;
    }
  }
}
