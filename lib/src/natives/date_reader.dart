/// Date reading and UTC calendar shared by the date natives.
///
/// A date argument is milliseconds since the epoch or ISO-8601 text. Every
/// calendar computation is done in UTC so a script gives the same answer on
/// every host. `DateTime.parse` is not used: it normalises `2026-02-29` to
/// March 1st, and a date that does not exist must read as unreadable.
library;

const int msPerDay = 86400000;

/// Limit of `DateTime`, in milliseconds either side of the epoch.
const int maxMillis = 8640000000000000;

/// Reads a date argument, or returns `null` when [value] is not a date.
DateTime? readDate(Object? value) {
  if (value is num) {
    if (!value.isFinite) return null;
    return fromMillis(value.truncate());
  }
  if (value is String) return _parseIso(value.trim());
  return null;
}

/// UTC instant at [ms], or `null` outside the range `DateTime` can hold.
DateTime? fromMillis(int ms) {
  if (ms < -maxMillis || ms > maxMillis) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

/// Builds a UTC date, rejecting out-of-range fields instead of normalising
/// them. [millisecond] is already truncated to milliseconds.
DateTime? buildDate(
    int year, int month, int day, int hour, int minute, int second,
    [int millisecond = 0]) {
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > daysIn(year, month) ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  return DateTime.utc(year, month, day, hour, minute, second, millisecond);
}

int daysIn(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// `YYYY-MM-DDTHH:mm:ss.SSSZ`
String isoString(DateTime t) => formatTokens(t, 'YYYY-MM-DDTHH:mm:ss.SSSZ');

/// Time of day in milliseconds.
int timeOfDay(DateTime t) =>
    ((t.hour * 60 + t.minute) * 60 + t.second) * 1000 + t.millisecond;

/// Whole calendar months from [a] to [b], negative when [b] is before [a].
int monthsBetween(DateTime a, DateTime b) {
  if (b.isBefore(a)) return -monthsBetween(b, a);
  var months = (b.year - a.year) * 12 + b.month - a.month;
  if (b.day < a.day || (b.day == a.day && timeOfDay(b) < timeOfDay(a))) {
    months--;
  }
  return months;
}

/// Adds [n] calendar months; a day that does not exist in the target month
/// becomes that month's last day.
DateTime addMonthsClamped(DateTime t, int n) {
  final total = t.month - 1 + n;
  final yearShift = _floorDiv(total, 12);
  final year = t.year + yearShift;
  final month = total - yearShift * 12 + 1;
  final last = daysIn(year, month);
  final day = t.day > last ? last : t.day;
  return DateTime.utc(
      year, month, day, t.hour, t.minute, t.second, t.millisecond);
}

int _floorDiv(int a, int b) {
  final q = a ~/ b;
  return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
}

// ============ ISO text ============

/// Reads `YYYY-MM-DD[(T| )HH:mm[:ss[.fraction]][Z|±HH:mm|±HHmm]]`.
DateTime? _parseIso(String s) {
  final p = _Scanner(s);
  final year = p.digits(4);
  final dash1 = p.literal('-');
  final month = p.digits(2);
  final dash2 = p.literal('-');
  final day = p.digits(2);
  if (year == null || !dash1 || month == null || !dash2 || day == null) {
    return null;
  }

  var hour = 0, minute = 0, second = 0, millisecond = 0, offset = 0;
  if (!p.done) {
    if (!p.literal('T') && !p.literal(' ')) return null;
    final h = p.digits(2);
    if (h == null || !p.literal(':')) return null;
    final m = p.digits(2);
    if (m == null) return null;
    hour = h;
    minute = m;
    if (p.literal(':')) {
      final sec = p.digits(2);
      if (sec == null) return null;
      second = sec;
      if (p.literal('.')) {
        final fraction = p.fraction(9);
        if (fraction.isEmpty) return null;
        millisecond = int.parse(fraction.padRight(3, '0').substring(0, 3));
      }
    }
    if (!p.done) {
      if (p.literal('Z')) {
        // UTC
      } else if (p.peek == '+' || p.peek == '-') {
        final negative = p.peek == '-';
        p.advance();
        final oh = p.digits(2);
        if (oh == null) return null;
        p.literal(':');
        final om = p.digits(2);
        if (om == null || oh > 23 || om > 59) return null;
        offset = oh * 3600 + om * 60;
        if (negative) offset = -offset;
      } else {
        return null;
      }
    }
  }
  if (!p.done) return null;

  final t = buildDate(year, month, day, hour, minute, second, millisecond);
  return t?.subtract(Duration(seconds: offset));
}

class _Scanner {
  final String s;
  int pos = 0;

  _Scanner(this.s);

  bool get done => pos >= s.length;

  String? get peek => done ? null : s[pos];

  void advance() => pos++;

  bool literal(String c) {
    if (!done && s[pos] == c) {
      pos++;
      return true;
    }
    return false;
  }

  /// Exactly [n] ASCII digits, or `null` without consuming anything.
  int? digits(int n) {
    if (pos + n > s.length) return null;
    var value = 0;
    for (var i = 0; i < n; i++) {
      final c = s.codeUnitAt(pos + i);
      if (c < 0x30 || c > 0x39) return null;
      value = value * 10 + (c - 0x30);
    }
    pos += n;
    return value;
  }

  /// Up to [max] ASCII digits.
  String fraction(int max) {
    final start = pos;
    while (!done && pos - start < max) {
      final c = s.codeUnitAt(pos);
      if (c < 0x30 || c > 0x39) break;
      pos++;
    }
    return s.substring(start, pos);
  }
}

// ============ Format tokens ============

/// Tried in this order at each position of a format: the longest wins.
const _tokens = ['YYYY', 'SSS', 'YY', 'MM', 'DD', 'HH', 'mm', 'ss'];

String _tokenAt(String format, int i) {
  for (final token in _tokens) {
    if (format.startsWith(token, i)) return token;
  }
  return '';
}

String _pad(int n, int width) =>
    n < 0 ? '-${_pad(-n, width)}' : n.toString().padLeft(width, '0');

/// Formats [t] (UTC) with the tokens `YYYY YY MM DD HH mm ss SSS`; anything
/// else is copied.
String formatTokens(DateTime t, String format) {
  final out = StringBuffer();
  var i = 0;
  while (i < format.length) {
    final token = _tokenAt(format, i);
    switch (token) {
      case 'YYYY':
        out.write(_pad(t.year, 4));
      case 'YY':
        out.write(_pad(t.year % 100, 2));
      case 'MM':
        out.write(_pad(t.month, 2));
      case 'DD':
        out.write(_pad(t.day, 2));
      case 'HH':
        out.write(_pad(t.hour, 2));
      case 'mm':
        out.write(_pad(t.minute, 2));
      case 'ss':
        out.write(_pad(t.second, 2));
      case 'SSS':
        out.write(_pad(t.millisecond, 3));
      default:
        out.write(format[i]);
        i++;
        continue;
    }
    i += token.length;
  }
  return out.toString();
}

/// Reads [text] with the tokens of [format]. Each token reads exactly its
/// width in digits, literals must match and the whole text must be consumed.
/// `YY` is not readable and counts as two literal letters. A missing year is
/// 1970, any other missing field the start of its range.
DateTime? parseTokens(String text, String format) {
  var year = 1970, month = 1, day = 1, hour = 0, minute = 0, second = 0;
  var millisecond = 0;
  final p = _Scanner(text);
  var i = 0;
  while (i < format.length) {
    final token = _tokenAt(format, i);
    final int? value;
    switch (token) {
      case 'YYYY':
        value = p.digits(4);
        if (value == null) return null;
        year = value;
      case 'MM':
        value = p.digits(2);
        if (value == null) return null;
        month = value;
      case 'DD':
        value = p.digits(2);
        if (value == null) return null;
        day = value;
      case 'HH':
        value = p.digits(2);
        if (value == null) return null;
        hour = value;
      case 'mm':
        value = p.digits(2);
        if (value == null) return null;
        minute = value;
      case 'ss':
        value = p.digits(2);
        if (value == null) return null;
        second = value;
      case 'SSS':
        value = p.digits(3);
        if (value == null) return null;
        millisecond = value;
      default:
        if (!p.literal(format[i])) return null;
        i++;
        continue;
    }
    i += token.length;
  }
  if (!p.done) return null;
  return buildDate(year, month, day, hour, minute, second, millisecond);
}
