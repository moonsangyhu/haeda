import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/core/utils/time.dart';

void main() {
  group('effectiveToday', () {
    test('returns previous day when time is before cutoff hour', () {
      // 01:59 with cutoff=2 → subtract 2h → 23:59 previous day
      final result = effectiveToday(DateTime(2026, 3, 9, 1, 59), 2);
      expect(result, DateTime(2026, 3, 8));
    });

    test('returns same day when time equals cutoff hour exactly', () {
      // 02:00 with cutoff=2 → subtract 2h → 00:00 same day
      final result = effectiveToday(DateTime(2026, 3, 9, 2, 0), 2);
      expect(result, DateTime(2026, 3, 9));
    });

    test('returns same day with cutoff=0 (midnight boundary)', () {
      // 00:00 with cutoff=0 → no shift
      final result = effectiveToday(DateTime(2026, 3, 9, 0, 0), 0);
      expect(result, DateTime(2026, 3, 9));
    });

    test('returns same day for normal daytime hours with cutoff=2', () {
      // 12:00 with cutoff=2 → subtract 2h → 10:00 same day
      final result = effectiveToday(DateTime(2026, 3, 9, 12, 0), 2);
      expect(result, DateTime(2026, 3, 9));
    });

    test('handles month boundary correctly', () {
      // Mar 1 00:30 with cutoff=1 → subtract 1h → Feb 28 23:30
      final result = effectiveToday(DateTime(2026, 3, 1, 0, 30), 1);
      expect(result, DateTime(2026, 2, 28));
    });
  });
}
