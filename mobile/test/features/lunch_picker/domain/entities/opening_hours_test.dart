import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lunch_picker/domain/entities/opening_hours.dart';

void main() {
  final noon = DateTime(2026, 1, 1, 12);

  group('OpeningHours.statusAt', () {
    test('empty string is unknown', () {
      expect(const OpeningHours('').statusAt(noon), OpeningStatus.unknown);
    });

    test('24/7 is always open', () {
      expect(const OpeningHours('24/7').statusAt(noon), OpeningStatus.open);
    });

    test('inside a plain HH:MM-HH:MM range is open', () {
      expect(
        const OpeningHours('11:00-14:00').statusAt(noon),
        OpeningStatus.open,
      );
    });

    test('outside every range is closed', () {
      expect(
        const OpeningHours('18:00-22:00').statusAt(noon),
        OpeningStatus.closed,
      );
    });

    test('a range that crosses midnight is handled', () {
      final lateNight = DateTime(2026, 1, 1, 23, 30);
      expect(
        const OpeningHours('20:00-02:00').statusAt(lateNight),
        OpeningStatus.open,
      );
    });

    test('day-of-week prefixes are ignored, only the time range matters', () {
      expect(
        const OpeningHours('Mo-Su 07:00-23:00').statusAt(noon),
        OpeningStatus.open,
      );
    });

    test('unparseable text is unknown, not closed', () {
      expect(
        const OpeningHours('by appointment').statusAt(noon),
        OpeningStatus.unknown,
      );
    });
  });
}
