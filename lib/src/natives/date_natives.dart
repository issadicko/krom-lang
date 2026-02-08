import 'natives.dart';
import 'native_helpers.dart';

void registerDateNatives(NativeFunctions registry) {
  registry.register('now', _nativeNow);
  registry.register('date', _nativeDate);
  registry.register('time', _nativeTime);
  registry.register('datetime', _nativeDatetime);
  registry.register('timestamp', _nativeTimestamp);
  registry.register('formatDate', _nativeFormatDate);
  registry.register('year', _nativeYear);
  registry.register('month', _nativeMonth);
  registry.register('day', _nativeDay);
  registry.register('hour', _nativeHour);
  registry.register('minute', _nativeMinute);
  registry.register('second', _nativeSecond);
  registry.register('dayOfWeek', _nativeDayOfWeek);
  registry.register('addDays', _nativeAddDays);
  registry.register('addHours', _nativeAddHours);
  registry.register('diffDays', _nativeDiffDays);
}

Object? _nativeNow(List<Object?> args) {
  requireArgs(args, 0, 'now');
  return DateTime.now().millisecondsSinceEpoch.toDouble();
}

Object? _nativeDate(List<Object?> args) {
  requireArgs(args, 0, 'date');
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

Object? _nativeTime(List<Object?> args) {
  requireArgs(args, 0, 'time');
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
}

Object? _nativeDatetime(List<Object?> args) {
  requireArgs(args, 0, 'datetime');
  return DateTime.now().toIso8601String();
}

Object? _nativeTimestamp(List<Object?> args) {
  if (args.isEmpty) {
    return DateTime.now().millisecondsSinceEpoch.toDouble();
  }
  final dateStr = getArgAsString(args, 0, 'timestamp');
  final parsed = DateTime.tryParse(dateStr);
  if (parsed == null) {
    throw ArgumentError('cannot parse date: $dateStr');
  }
  return parsed.millisecondsSinceEpoch.toDouble();
}

Object? _nativeFormatDate(List<Object?> args) {
  requireArgsRange(args, 1, 2, 'formatDate');
  final ts = getArgAsInt(args, 0, 'formatDate');
  final format = args.length == 2 ? getArgAsString(args, 1, 'formatDate') : 'YYYY-MM-DD';
  final date = DateTime.fromMillisecondsSinceEpoch(ts);

  var result = format;
  result = result.replaceAll('YYYY', date.year.toString().padLeft(4, '0'));
  result = result.replaceAll('MM', date.month.toString().padLeft(2, '0'));
  result = result.replaceAll('DD', date.day.toString().padLeft(2, '0'));
  result = result.replaceAll('HH', date.hour.toString().padLeft(2, '0'));
  result = result.replaceAll('mm', date.minute.toString().padLeft(2, '0'));
  result = result.replaceAll('ss', date.second.toString().padLeft(2, '0'));
  return result;
}

Object? _nativeYear(List<Object?> args) {
  final ts = args.isEmpty
      ? DateTime.now().millisecondsSinceEpoch
      : getArgAsInt(args, 0, 'year');
  return DateTime.fromMillisecondsSinceEpoch(ts).year.toDouble();
}

Object? _nativeMonth(List<Object?> args) {
  final ts = args.isEmpty
      ? DateTime.now().millisecondsSinceEpoch
      : getArgAsInt(args, 0, 'month');
  return DateTime.fromMillisecondsSinceEpoch(ts).month.toDouble();
}

Object? _nativeDay(List<Object?> args) {
  final ts = args.isEmpty
      ? DateTime.now().millisecondsSinceEpoch
      : getArgAsInt(args, 0, 'day');
  return DateTime.fromMillisecondsSinceEpoch(ts).day.toDouble();
}

Object? _nativeHour(List<Object?> args) {
  final ts = args.isEmpty
      ? DateTime.now().millisecondsSinceEpoch
      : getArgAsInt(args, 0, 'hour');
  return DateTime.fromMillisecondsSinceEpoch(ts).hour.toDouble();
}

Object? _nativeMinute(List<Object?> args) {
  final ts = args.isEmpty
      ? DateTime.now().millisecondsSinceEpoch
      : getArgAsInt(args, 0, 'minute');
  return DateTime.fromMillisecondsSinceEpoch(ts).minute.toDouble();
}

Object? _nativeSecond(List<Object?> args) {
  final ts = args.isEmpty
      ? DateTime.now().millisecondsSinceEpoch
      : getArgAsInt(args, 0, 'second');
  return DateTime.fromMillisecondsSinceEpoch(ts).second.toDouble();
}

Object? _nativeDayOfWeek(List<Object?> args) {
  final ts = args.isEmpty
      ? DateTime.now().millisecondsSinceEpoch
      : getArgAsInt(args, 0, 'dayOfWeek');
  // Dart: weekday is 1=Monday, 7=Sunday. We want 0=Sunday.
  final weekday = DateTime.fromMillisecondsSinceEpoch(ts).weekday;
  return (weekday == 7 ? 0 : weekday).toDouble();
}

Object? _nativeAddDays(List<Object?> args) {
  requireArgs(args, 2, 'addDays');
  final ts = getArgAsInt(args, 0, 'addDays');
  final days = getArgAsInt(args, 1, 'addDays');
  final date = DateTime.fromMillisecondsSinceEpoch(ts);
  return date.add(Duration(days: days)).millisecondsSinceEpoch.toDouble();
}

Object? _nativeAddHours(List<Object?> args) {
  requireArgs(args, 2, 'addHours');
  final ts = getArgAsInt(args, 0, 'addHours');
  final hours = getArgAsInt(args, 1, 'addHours');
  final date = DateTime.fromMillisecondsSinceEpoch(ts);
  return date.add(Duration(hours: hours)).millisecondsSinceEpoch.toDouble();
}

Object? _nativeDiffDays(List<Object?> args) {
  requireArgs(args, 2, 'diffDays');
  final ts1 = getArgAsInt(args, 0, 'diffDays');
  final ts2 = getArgAsInt(args, 1, 'diffDays');
  final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
  final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
  return d2.difference(d1).inDays.toDouble();
}
