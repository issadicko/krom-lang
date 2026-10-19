import 'package:krom_script/krom_script.dart';
import 'package:test/test.dart';

Object? ev(String source) => KromScript.eval(source);

String? iso(String date) => ev('toISO($date)') as String?;

void main() {
  group('Date reading', () {
    test('a date alone is midnight UTC', () {
      expect(iso('"2026-01-31"'), equals('2026-01-31T00:00:00.000Z'));
    });

    test('hours and minutes, with or without seconds', () {
      expect(iso('"2026-01-31T10:20"'), equals('2026-01-31T10:20:00.000Z'));
      expect(iso('"2026-01-31T10:20:30"'), equals('2026-01-31T10:20:30.000Z'));
    });

    test('a space may replace the T', () {
      expect(iso('"2026-01-31 10:20:30"'), equals('2026-01-31T10:20:30.000Z'));
    });

    test('the fraction is kept to milliseconds by truncation', () {
      expect(
          iso('"2026-01-31T10:20:30.9"'), equals('2026-01-31T10:20:30.900Z'));
      expect(iso('"2026-01-31T10:20:30.1239"'),
          equals('2026-01-31T10:20:30.123Z'));
      expect(iso('"2026-01-31T10:20:30.123999999"'),
          equals('2026-01-31T10:20:30.123Z'));
    });

    test('a zone moves the instant to UTC', () {
      expect(iso('"2026-01-31T10:20:30Z"'), equals('2026-01-31T10:20:30.000Z'));
      expect(iso('"2026-01-31T10:20:30+01:00"'),
          equals('2026-01-31T09:20:30.000Z'));
      expect(iso('"2026-01-31T10:20:30-02:30"'),
          equals('2026-01-31T12:50:30.000Z'));
      expect(iso('"2026-01-31T10:20:30+0100"'),
          equals('2026-01-31T09:20:30.000Z'));
      expect(
          iso('"2026-01-31T00:30+01:00"'), equals('2026-01-30T23:30:00.000Z'));
    });

    test('surrounding spaces are ignored', () {
      expect(iso('"  2026-01-31  "'), equals('2026-01-31T00:00:00.000Z'));
    });

    test('a number is milliseconds since the epoch, fraction truncated', () {
      expect(iso('0'), equals('1970-01-01T00:00:00.000Z'));
      expect(iso('1500.9'), equals('1970-01-01T00:00:01.500Z'));
      expect(iso('-1.9'), equals('1969-12-31T23:59:59.999Z'));
    });

    test('a number beyond what a date can hold is unreadable', () {
      expect(ev('toISO(8640000000000000)'), isNotNull);
      expect(ev('toISO(8640000000000001)'), isNull);
      expect(ev('toISO(-1000000000000000000000000000000)'), isNull);
      expect(ev('toISO(1000000000000000000000000000000)'), isNull);
    });

    test('a day that does not exist is not a date', () {
      for (final text in [
        '2026-02-29',
        '2025-02-29',
        '1900-02-29',
        '2026-04-31',
        '2026-00-10',
        '2026-13-01',
        '2026-01-00',
        '2026-01-32',
      ]) {
        expect(ev('isDate("$text")'), isFalse, reason: text);
        expect(iso('"$text"'), isNull, reason: text);
      }
    });

    test('leap years are honoured', () {
      expect(iso('"2024-02-29"'), equals('2024-02-29T00:00:00.000Z'));
      expect(iso('"2000-02-29"'), equals('2000-02-29T00:00:00.000Z'));
    });

    test('a time field out of range is not a date', () {
      for (final text in [
        '2026-01-01T24:00:00',
        '2026-01-01T23:60:00',
        '2026-01-01T23:59:60',
        '2026-01-01T10:00:00+24:00',
        '2026-01-01T10:00:00+01:60',
      ]) {
        expect(ev('isDate("$text")'), isFalse, reason: text);
      }
    });

    test('text that is not an ISO date is not a date', () {
      for (final text in [
        '',
        'nope',
        '2026',
        '2026-1-01',
        '2026-01-1',
        '26-01-01',
        '2026/01/01',
        '2026-01-01T',
        '2026-01-01T10',
        '2026-01-01T1:00',
        '2026-01-01T10:00:',
        '2026-01-01T10:00:00.',
        '2026-01-01T10:00:00Zjunk',
        '2026-01-01T10:00:00+01',
        '2026-01-01x',
        '2026-01-01T10:00:00.1234567890',
      ]) {
        expect(ev('isDate("$text")'), isFalse, reason: text);
      }
    });

    test('anything else is unreadable', () {
      expect(ev('isDate(null)'), isFalse);
      expect(ev('isDate(true)'), isFalse);
      expect(ev('isDate([0])'), isFalse);
      expect(ev('isDate({a: 1})'), isFalse);
      expect(ev('isDate(0)'), isTrue);
      expect(ev('toISO(null)'), isNull);
      expect(ev('year(true)'), isNull);
    });
  });

  group('Changed behaviour of existing functions', () {
    test('timestamp is null for an unreadable date instead of raising', () {
      expect(ev('timestamp("nope")'), isNull);
      expect(ev('timestamp(null)'), isNull);
      expect(ev('timestamp("2026-02-29")'), isNull);
    });

    test('timestamp reads text in UTC', () {
      expect(ev('timestamp("1970-01-02")'), equals(86400000));
      expect(ev('timestamp("1970-01-01T01:00:00+01:00")'), equals(0));
    });

    test('calendar fields are in UTC', () {
      expect(ev('year("2026-12-31T23:59:59-05:00")'), equals(2027));
      expect(ev('month("2026-12-31T23:59:59-05:00")'), equals(1));
      expect(ev('day("2026-10-19T23:30:00-02:00")'), equals(20));
      expect(ev('hour("2026-10-19T23:30:00-02:00")'), equals(1));
      expect(ev('minute("2026-10-19T23:30:45Z")'), equals(30));
      expect(ev('second("2026-10-19T23:30:45Z")'), equals(45));
    });

    test(
        'calendar fields without argument read now, an unreadable date is null',
        () {
      expect(ev('year()'), greaterThanOrEqualTo(2024));
      expect(ev('month("nope")'), isNull);
    });

    test('dayOfWeek: 0 is Sunday', () {
      expect(ev('dayOfWeek("2026-10-18")'), equals(0));
      expect(ev('dayOfWeek("2026-10-19")'), equals(1));
      expect(ev('dayOfWeek("2026-10-24")'), equals(6));
    });

    test('date, time and datetime are in UTC', () {
      expect(ev('date()'), matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(ev('time()'), matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
      expect(ev('datetime()'),
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$')));
    });

    test('addDays and addHours return milliseconds, count truncated', () {
      expect(ev('addDays("1970-01-01", 1)'), equals(86400000));
      expect(ev('addDays("1970-01-02", -1.9)'), equals(0));
      expect(ev('addHours("1970-01-01", 1.9)'), equals(3600000));
      expect(ev('addDays("nope", 1)'), isNull);
    });

    test('a count that is not a number raises, even on an unreadable date', () {
      expect(() => ev('addDays("2026-10-19", "2")'),
          throwsA(isA<KromScriptException>()));
      expect(() => ev('addDays("nope", "2")'),
          throwsA(isA<KromScriptException>()));
      expect(() => ev('addMonths("2026-10-19", null)'),
          throwsA(isA<KromScriptException>()));
    });

    test('diffDays truncates toward zero', () {
      expect(ev('diffDays("2026-10-19", "2026-10-26")'), equals(7));
      expect(ev('diffDays("2026-10-26T12:00:00Z", "2026-10-19")'), equals(-7));
      expect(ev('diffDays("2026-10-19", "2026-10-19T23:59:59Z")'), equals(0));
      expect(ev('diffDays("2026-10-19", null)'), isNull);
      expect(ev('diffDays("nope", "2026-10-19")'), isNull);
    });

    test('formatDate reads text and knows the new tokens', () {
      expect(
          ev('formatDate("2026-03-05T07:08:09.045Z", "DD/MM/YY HH:mm:ss.SSS")'),
          equals('05/03/26 07:08:09.045'));
      expect(ev('formatDate("2026-10-19")'), equals('2026-10-19'));
      expect(ev('formatDate(0, "YYYY")'), equals('1970'));
      expect(ev('formatDate("nope")'), isNull);
    });

    test('formatDate copies what is not a token', () {
      expect(ev('formatDate("2026-10-19", "YYYY-MM-DD, YYYY")'),
          equals('2026-10-19, 2026'));
      expect(ev('formatDate("2026-10-19", "le DD/MM (YYYYY)")'),
          equals('le 19/10 (2026Y)'));
      expect(() => ev('formatDate("2026-10-19", 3)'),
          throwsA(isA<KromScriptException>()));
    });
  });

  group('parseDate', () {
    test('reads the tokens of the format', () {
      expect(iso('parseDate("19/10/2026 08:05", "DD/MM/YYYY HH:mm")'),
          equals('2026-10-19T08:05:00.000Z'));
      expect(
          iso('parseDate("2026-10-19 08:05:09.012", "YYYY-MM-DD HH:mm:ss.SSS")'),
          equals('2026-10-19T08:05:09.012Z'));
    });

    test('missing fields default to the start of the year', () {
      expect(
          iso('parseDate("2026", "YYYY")'), equals('2026-01-01T00:00:00.000Z'));
      expect(iso('parseDate("2026-03", "YYYY-MM")'),
          equals('2026-03-01T00:00:00.000Z'));
    });

    test('each token reads exactly its width', () {
      expect(ev('parseDate("9/10/2026", "DD/MM/YYYY")'), isNull);
      expect(ev('parseDate("19/10/26", "DD/MM/YYYY")'), isNull);
      expect(ev('parseDate("19/10/20260", "DD/MM/YYYY")'), isNull);
    });

    test('literals must match and the whole text must be consumed', () {
      expect(ev('parseDate("19-10-2026", "DD/MM/YYYY")'), isNull);
      expect(ev('parseDate("19/10/2026 extra", "DD/MM/YYYY")'), isNull);
      expect(ev('parseDate("19/10", "DD/MM/YYYY")'), isNull);
    });

    test('a date that does not exist is null', () {
      expect(ev('parseDate("31/02/2026", "DD/MM/YYYY")'), isNull);
      expect(ev('parseDate("29/02/2026", "DD/MM/YYYY")'), isNull);
      expect(iso('parseDate("29/02/2024", "DD/MM/YYYY")'),
          equals('2024-02-29T00:00:00.000Z'));
      expect(ev('parseDate("19/10/2026 24:00", "DD/MM/YYYY HH:mm")'), isNull);
    });

    test('YY cannot be read: it is two literal letters', () {
      expect(ev('parseDate("26", "YY")'), isNull);
      expect(ev('parseDate("YY", "YY")'), equals(0));
    });

    test('text that is not a string is null, a format that is not raises', () {
      expect(ev('parseDate(null, "YYYY")'), isNull);
      expect(ev('parseDate(2026, "YYYY")'), isNull);
      expect(() => ev('parseDate("2026", null)'),
          throwsA(isA<KromScriptException>()));
    });
  });

  group('Calendar arithmetic', () {
    test('addMonths clamps to the last day of the target month', () {
      expect(iso('addMonths("2026-01-31", 1)'),
          equals('2026-02-28T00:00:00.000Z'));
      expect(iso('addMonths("2024-01-31T08:00:00Z", 1)'),
          equals('2024-02-29T08:00:00.000Z'));
      expect(iso('addMonths("2026-03-31", -1)'),
          equals('2026-02-28T00:00:00.000Z'));
      expect(iso('addMonths("2026-10-31", 2)'),
          equals('2026-12-31T00:00:00.000Z'));
    });

    test('addMonths crosses years in both directions', () {
      expect(iso('addMonths("2026-11-15", 3)'),
          equals('2027-02-15T00:00:00.000Z'));
      expect(iso('addMonths("2026-01-15", -1)'),
          equals('2025-12-15T00:00:00.000Z'));
      expect(iso('addMonths("2026-01-15", -13)'),
          equals('2024-12-15T00:00:00.000Z'));
      expect(iso('addMonths("2026-01-15", 24.9)'),
          equals('2028-01-15T00:00:00.000Z'));
    });

    test('addYears clamps a leap day', () {
      expect(
          iso('addYears("2024-02-29", 1)'), equals('2025-02-28T00:00:00.000Z'));
      expect(
          iso('addYears("2024-02-29", 4)'), equals('2028-02-29T00:00:00.000Z'));
      expect(iso('addYears("2026-10-19T10:00:00Z", -1)'),
          equals('2025-10-19T10:00:00.000Z'));
    });

    test('addMinutes and addSeconds', () {
      expect(iso('addMinutes("2026-10-19T10:00:00Z", 90)'),
          equals('2026-10-19T11:30:00.000Z'));
      expect(iso('addSeconds("2026-10-19T10:00:00Z", -30)'),
          equals('2026-10-19T09:59:30.000Z'));
    });

    test('a result no date can hold is null', () {
      expect(ev('addYears("2026-01-01", 1000000000000)'), isNull);
      expect(ev('addDays("2026-01-01", 1000000000000)'), isNull);
    });

    test('diffHours and diffMinutes truncate toward zero', () {
      expect(ev('diffHours("2026-10-19T08:00:00Z", "2026-10-19T17:59:00Z")'),
          equals(9));
      expect(ev('diffHours("2026-10-19T17:59:00Z", "2026-10-19T08:00:00Z")'),
          equals(-9));
      expect(ev('diffMinutes("2026-10-19T08:00:00Z", "2026-10-19T08:45:59Z")'),
          equals(45));
    });

    test('diffMonths counts whole calendar months', () {
      expect(ev('diffMonths("2026-01-31", "2026-02-28")'), equals(0));
      expect(ev('diffMonths("2026-01-15", "2026-03-15")'), equals(2));
      expect(ev('diffMonths("2026-01-15", "2026-03-14")'), equals(1));
      expect(ev('diffMonths("2026-01-15T10:00:00Z", "2026-03-15T09:59:00Z")'),
          equals(1));
      expect(ev('diffMonths("2025-12-15", "2026-01-15")'), equals(1));
    });

    test('diffMonths is antisymmetric', () {
      expect(ev('diffMonths("2026-03-15", "2026-01-16")'), equals(-1));
      expect(ev('diffMonths("2026-03-15", "2026-01-15")'), equals(-2));
    });

    test('diffYears and age', () {
      expect(ev('diffYears("2000-10-20", "2026-10-19")'), equals(25));
      expect(ev('diffYears("2026-10-19", "2000-10-20")'), equals(-25));
      expect(ev('age("2000-10-19", "2026-10-19")'), equals(26));
      expect(ev('age("2000-10-20", "2026-10-19")'), equals(25));
      expect(ev('age("2000-01-01")'), greaterThanOrEqualTo(26));
    });

    test('age is null when birth or a given date is unreadable', () {
      expect(ev('age("nope", "2026-10-19")'), isNull);
      expect(ev('age("2000-10-19", "nope")'), isNull);
      expect(ev('age("2000-10-19", null)'), isNull);
      expect(ev('age(null)'), isNull);
    });
  });

  group('Periods', () {
    test('start and end of day', () {
      expect(iso('startOfDay("2026-10-19T15:30:00Z")'),
          equals('2026-10-19T00:00:00.000Z'));
      expect(iso('endOfDay("2026-10-19T15:30:00Z")'),
          equals('2026-10-19T23:59:59.999Z'));
      expect(iso('startOfDay("2026-10-19T23:30:00-02:00")'),
          equals('2026-10-20T00:00:00.000Z'));
    });

    test('start and end of month', () {
      expect(iso('startOfMonth("2026-10-19T15:30:00Z")'),
          equals('2026-10-01T00:00:00.000Z'));
      expect(
          iso('endOfMonth("2024-02-10")'), equals('2024-02-29T23:59:59.999Z'));
      expect(
          iso('endOfMonth("2026-12-10")'), equals('2026-12-31T23:59:59.999Z'));
    });

    test('daysInMonth', () {
      expect(ev('daysInMonth("2026-02-01")'), equals(28));
      expect(ev('daysInMonth("2024-02-01")'), equals(29));
      expect(ev('daysInMonth("2026-12-15")'), equals(31));
      expect(ev('daysInMonth("nope")'), isNull);
    });

    test('isWeekend', () {
      expect(ev('isWeekend("2026-10-17")'), isTrue);
      expect(ev('isWeekend("2026-10-18")'), isTrue);
      expect(ev('isWeekend("2026-10-19")'), isFalse);
      expect(ev('isWeekend("nope")'), isNull);
    });
  });

  group('Method syntax', () {
    test('a date function chains on its own result', () {
      expect(ev('"2026-10-19".addDays(1).toISO()'),
          equals('2026-10-20T00:00:00.000Z'));
      expect(ev('"2026-10-19".addMonths(1).addDays(2).formatDate("DD/MM")'),
          equals('21/11'));
    });
  });
}
