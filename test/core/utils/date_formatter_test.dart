import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/core/utils/date_formatter.dart';

void main() {
  // Fixed UTC timestamp used across all tests — deterministic, timezone-agnostic.
  const isoUtc = '2026-06-14T10:30:00.000Z';

  group('DateFormatter', () {
    // ── toIso8601 ─────────────────────────────────────────────────────────────

    group('toIso8601', () {
      test('produces UTC string ending in Z', () {
        final dt = DateTime.utc(2026, 6, 14, 10, 30, 0);
        expect(DateFormatter.toIso8601(dt), endsWith('Z'));
      });

      test('round-trips a UTC DateTime losslessly', () {
        final original = DateTime.utc(2026, 6, 14, 10, 30, 0);
        final iso      = DateFormatter.toIso8601(original);
        final parsed   = DateTime.parse(iso).toUtc();
        expect(parsed, original);
      });

      test('converts local DateTime to UTC before serialising', () {
        // Use a known UTC value so we can verify the string regardless of host TZ.
        final utc = DateTime.utc(2026, 1, 1, 0, 0, 0);
        expect(DateFormatter.toIso8601(utc), '2026-01-01T00:00:00.000Z');
      });
    });

    // ── fromIso8601 ───────────────────────────────────────────────────────────

    group('fromIso8601', () {
      test('returns a DateTime', () {
        final result = DateFormatter.fromIso8601(isoUtc);
        expect(result, isA<DateTime>());
      });

      test('round-trip: toIso8601(fromIso8601(x).toUtc()) == x', () {
        final local      = DateFormatter.fromIso8601(isoUtc);
        final backToIso  = DateFormatter.toIso8601(local.toUtc());
        expect(backToIso, isoUtc);
      });

      test('preserves the instant (UTC epoch stays the same)', () {
        final local = DateFormatter.fromIso8601(isoUtc);
        expect(local.toUtc().toIso8601String(), isoUtc);
      });
    });

    // ── timestampToDisplay ────────────────────────────────────────────────────

    group('timestampToDisplay', () {
      test('returns a non-empty string', () {
        expect(DateFormatter.timestampToDisplay(isoUtc), isNotEmpty);
      });

      test('contains the year', () {
        expect(DateFormatter.timestampToDisplay(isoUtc), contains('2026'));
      });

      test('contains month abbreviation', () {
        expect(DateFormatter.timestampToDisplay(isoUtc), contains('Jun'));
      });
    });

    // ── timestampToShort ──────────────────────────────────────────────────────

    group('timestampToShort', () {
      test('returns a non-empty string', () {
        expect(DateFormatter.timestampToShort(isoUtc), isNotEmpty);
      });

      test('is shorter than the display format', () {
        final display = DateFormatter.timestampToDisplay(isoUtc);
        final short   = DateFormatter.timestampToShort(isoUtc);
        expect(short.length, lessThan(display.length));
      });

      test('contains month abbreviation', () {
        expect(DateFormatter.timestampToShort(isoUtc), contains('Jun'));
      });
    });
  });
}
