import 'date_reader.dart';
import 'natives.dart';
import 'native_helpers.dart';

/// Dates are read by [readDate] (milliseconds or ISO text) and computed in UTC.
/// A date that cannot be read gives `null`; a wrong count or format raises.
void registerDateNatives(NativeFunctions registry) {
  registry.register('now', _nativeNow);
  registry.register('date', _nativeDate);
  registry.register('time', _nativeTime);
  registry.register('datetime', _nativeDatetime);
  registry.register('timestamp', _nativeTimestamp);
  registry.register('toISO', _nativeToISO);
  registry.register('isDate', _nativeIsDate);
  registry.register('formatDate', _nativeFormatDate);
  registry.register('parseDate', _nativeParseDate);
  registry.register('year', _calendarField('year', (t) => t.year));
  registry.register('month', _calendarField('month', (t) => t.month));
  registry.register('day', _calendarField('day', (t) => t.day));
  registry.register('hour', _calendarField('hour', (t) => t.hour));
  registry.register('minute', _calendarField('minute', (t) => t.minute));
  registry.register('second', _calendarField('second', (t) => t.second));
  // Dart: weekday is 1=Monday, 7=Sunday. We want 0=Sunday.
  registry.register('dayOfWeek',
      _calendarField('dayOfWeek', (t) => t.weekday == 7 ? 0 : t.weekday));
  registry.register('daysInMonth', _nativeDaysInMonth);
  registry.register('isWeekend', _nativeIsWeekend);

  registry.register('addDays', _shiftBy('addDays', msPerDay));
  registry.register('addHours', _shiftBy('addHours', 3600000));
  registry.register('addMinutes', _shiftBy('addMinutes', 60000));
  registry.register('addSeconds', _shiftBy('addSeconds', 1000));
  registry.register(
      'addMonths',
      _shift('addMonths', 3300000,
          (t, n) => addMonthsClamped(t, n).millisecondsSinceEpoch));
  registry.register(
      'addYears',
      _shift('addYears', 275000,
          (t, n) => addMonthsClamped(t, 12 * n).millisecondsSinceEpoch));

  registry.register('diffDays', _between('diffDays', _elapsed(msPerDay)));
  registry.register('diffHours', _between('diffHours', _elapsed(3600000)));
  registry.register('diffMinutes', _between('diffMinutes', _elapsed(60000)));
  registry.register('diffMonths', _between('diffMonths', monthsBetween));
  registry.register(
      'diffYears', _between('diffYears', (a, b) => monthsBetween(a, b) ~/ 12));
  registry.register('age', _nativeAge);

  registry.register('startOfDay',
      _period('startOfDay', (t) => DateTime.utc(t.year, t.month, t.day)));
  registry.register(
      'endOfDay',
      _period('endOfDay',
          (t) => DateTime.utc(t.year, t.month, t.day, 23, 59, 59, 999)));
  registry.register('startOfMonth',
      _period('startOfMonth', (t) => DateTime.utc(t.year, t.month)));
  registry.register(
      'endOfMonth',
      _period(
          'endOfMonth',
          (t) => DateTime.utc(
              t.year, t.month, daysIn(t.year, t.month), 23, 59, 59, 999)));
}

/// An optional date argument: absent means now, present but unreadable `null`.
DateTime? _dateOrNow(List<Object?> args) =>
    args.isEmpty ? DateTime.now().toUtc() : readDate(args[0]);

double? _ms(DateTime? t) => t?.millisecondsSinceEpoch.toDouble();

/// A count: a number, truncated toward zero.
int _count(String name, Object? value) {
  if (value is num && value.isFinite) return value.truncate();
  throw ArgumentError('$name requires a number as second argument');
}

// ============ Current date and time ============

Object? _nativeNow(List<Object?> args) {
  requireArgs(args, 0, 'now');
  return DateTime.now().millisecondsSinceEpoch.toDouble();
}

Object? _nativeDate(List<Object?> args) {
  requireArgs(args, 0, 'date');
  return formatTokens(DateTime.now().toUtc(), 'YYYY-MM-DD');
}

Object? _nativeTime(List<Object?> args) {
  requireArgs(args, 0, 'time');
  return formatTokens(DateTime.now().toUtc(), 'HH:mm:ss');
}

Object? _nativeDatetime(List<Object?> args) {
  requireArgs(args, 0, 'datetime');
  return isoString(DateTime.now().toUtc());
}

Object? _nativeTimestamp(List<Object?> args) {
  requireArgsRange(args, 0, 1, 'timestamp');
  return _ms(_dateOrNow(args));
}

// ============ Reading and writing dates ============

Object? _nativeToISO(List<Object?> args) {
  requireArgs(args, 1, 'toISO');
  final t = readDate(args[0]);
  return t == null ? null : isoString(t);
}

Object? _nativeIsDate(List<Object?> args) {
  requireArgs(args, 1, 'isDate');
  return readDate(args[0]) != null;
}

Object? _nativeFormatDate(List<Object?> args) {
  requireArgsRange(args, 1, 2, 'formatDate');
  final format =
      args.length == 2 ? getArgAsString(args, 1, 'formatDate') : 'YYYY-MM-DD';
  final t = readDate(args[0]);
  return t == null ? null : formatTokens(t, format);
}

Object? _nativeParseDate(List<Object?> args) {
  requireArgs(args, 2, 'parseDate');
  final format = getArgAsString(args, 1, 'parseDate');
  final text = args[0];
  if (text is! String) return null;
  return _ms(parseTokens(text, format));
}

// ============ Calendar fields ============

NativeFunc _calendarField(String name, int Function(DateTime) field) {
  return (List<Object?> args) {
    requireArgsRange(args, 0, 1, name);
    final t = _dateOrNow(args);
    return t == null ? null : field(t).toDouble();
  };
}

Object? _nativeDaysInMonth(List<Object?> args) {
  requireArgs(args, 1, 'daysInMonth');
  final t = readDate(args[0]);
  return t == null ? null : daysIn(t.year, t.month).toDouble();
}

Object? _nativeIsWeekend(List<Object?> args) {
  requireArgs(args, 1, 'isWeekend');
  final t = readDate(args[0]);
  if (t == null) return null;
  return t.weekday == DateTime.saturday || t.weekday == DateTime.sunday;
}

// ============ Arithmetic ============

/// `name(date, n)`: [apply] returns the new instant in milliseconds. The count
/// is checked before the date, so a wrong count raises even on an unreadable
/// date. A [limit] on the count keeps the arithmetic from overflowing, and a
/// result `DateTime` cannot hold is no date at all.
NativeFunc _shift(String name, int limit, int Function(DateTime, int) apply) {
  return (List<Object?> args) {
    requireArgs(args, 2, name);
    final n = _count(name, args[1]);
    final t = readDate(args[0]);
    if (t == null || n.abs() > limit) return null;
    try {
      return _ms(fromMillis(apply(t, n)));
    } on ArgumentError {
      return null;
    }
  };
}

/// [_shift] by a fixed number of milliseconds per unit.
NativeFunc _shiftBy(String name, int unit) => _shift(
    name, maxMillis ~/ unit, (t, n) => t.millisecondsSinceEpoch + n * unit);

/// `name(a, b)`: [measure] in whole units from `a` to `b`, `null` if either
/// date is unreadable.
NativeFunc _between(String name, int Function(DateTime, DateTime) measure) {
  return (List<Object?> args) {
    requireArgs(args, 2, name);
    final a = readDate(args[0]);
    final b = readDate(args[1]);
    if (a == null || b == null) return null;
    return measure(a, b).toDouble();
  };
}

/// Whole [unit]s between two instants, truncated toward zero.
int Function(DateTime, DateTime) _elapsed(int unit) =>
    (a, b) => (b.millisecondsSinceEpoch - a.millisecondsSinceEpoch) ~/ unit;

Object? _nativeAge(List<Object?> args) {
  requireArgsRange(args, 1, 2, 'age');
  final birth = readDate(args[0]);
  if (birth == null) return null;
  final at = _dateOrNow(args.sublist(1));
  if (at == null) return null;
  return (monthsBetween(birth, at) ~/ 12).toDouble();
}

// ============ Periods ============

NativeFunc _period(String name, DateTime Function(DateTime) bound) {
  return (List<Object?> args) {
    requireArgs(args, 1, name);
    final t = readDate(args[0]);
    return t == null ? null : _ms(bound(t));
  };
}
