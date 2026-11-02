import 'list_helpers.dart';
import 'natives.dart';
import 'native_helpers.dart';

/// List utilities. A list argument may be `null`, which is an empty list; two
/// values are equal per [equalityKey]. Arguments are never modified.
void registerListNatives(NativeFunctions registry) {
  registry.register('chunk', _nativeChunk);
  registry.register('compact', _nativeCompact);
  registry.register('pluck', _nativePluck);
  registry.register('zip', _nativeZip);
  registry.register('fromEntries', _nativeFromEntries);
  registry.register('difference', _nativeDifference);
  registry.register('intersection', _nativeIntersection);
  registry.register('union', _nativeUnion);
  registry.register('sum', _nativeSum);
  registry.register('avg', _nativeAvg);
  registry.register('unique', _nativeUnique);
  registry.register('flatten', _nativeFlatten);
  registry.register('push', _nativePush);
  registry.register('concat', _nativeConcat);
  registry.register('sortBy', _nativeSortBy);
}

Object? _nativeChunk(List<Object?> args) {
  requireArgs(args, 2, 'chunk');
  final list = listArg('chunk', args[0]);
  final n = args[1];
  if (n is! num || !n.isFinite || n.truncate() < 1) {
    throw ArgumentError('chunk requires a size of at least 1');
  }
  final size = n.truncate();
  return <Object?>[
    for (var start = 0; start < list.length; start += size)
      list.sublist(
          start, start + size > list.length ? list.length : start + size)
  ];
}

Object? _nativeCompact(List<Object?> args) {
  requireArgs(args, 1, 'compact');
  return listArg('compact', args[0]).where((item) => item != null).toList();
}

Object? _nativePluck(List<Object?> args) {
  requireArgs(args, 2, 'pluck');
  final list = listArg('pluck', args[0]);
  final path = args[1];
  if (path is! String) {
    throw ArgumentError('pluck requires a string path as second argument');
  }
  return [for (final item in list) atPath(item, path)];
}

Object? _nativeZip(List<Object?> args) {
  final lists = [for (final a in args) listArg('zip', a)];
  if (lists.isEmpty) return <Object?>[];
  final shortest = lists.map((l) => l.length).reduce((a, b) => a < b ? a : b);
  return <Object?>[
    for (var row = 0; row < shortest; row++) [for (final l in lists) l[row]]
  ];
}

Object? _nativeFromEntries(List<Object?> args) {
  requireArgs(args, 1, 'fromEntries');
  final entries = <String, Object?>{};
  for (final item in listArg('fromEntries', args[0])) {
    if (item is! List || item.length < 2) {
      throw ArgumentError(
          'fromEntries requires each element to be a [key, value] pair');
    }
    entries[canonicalString(item[0])] = item[1];
  }
  return sortedObject(entries);
}

(List<Object?>, List<Object?>) _twoLists(String name, List<Object?> args) {
  requireArgs(args, 2, name);
  final a = listArg(name, args[0]);
  final b = args[1] == null || args[1] is List
      ? listArg(name, args[1])
      : throw ArgumentError('$name requires an array as second argument');
  return (a, b);
}

Object? _nativeDifference(List<Object?> args) {
  final (a, b) = _twoLists('difference', args);
  final excluded = {for (final item in b) equalityKey(item)};
  return [
    for (final item in a)
      if (!excluded.contains(equalityKey(item))) item
  ];
}

Object? _nativeIntersection(List<Object?> args) {
  final (a, b) = _twoLists('intersection', args);
  final kept = {for (final item in b) equalityKey(item)};
  final seen = <String>{};
  return [
    for (final item in a)
      if (kept.contains(equalityKey(item)) && seen.add(equalityKey(item))) item
  ];
}

Object? _nativeUnion(List<Object?> args) {
  final seen = <String>{};
  final result = <Object?>[];
  for (var i = 0; i < args.length; i++) {
    if (i > 0 && args[i] != null && args[i] is! List) {
      throw ArgumentError('union requires array arguments');
    }
    for (final item in listArg('union', args[i])) {
      if (seen.add(equalityKey(item))) result.add(item);
    }
  }
  return result;
}

/// The numbers of a list for [name]. `null` counts as `0`, as it does in
/// arithmetic: `sum(map(rows, fn(r) { return r.total }))` adds up the rows
/// that have a total, the same way `a + b` treats a missing operand.
List<double> _numbers(String name, Object? value) => [
      for (final item in listArg(name, value))
        if (item == null)
          0.0
        else if (item is num)
          item.toDouble()
        else
          throw ArgumentError('$name requires an array of numbers')
    ];

Object? _nativeSum(List<Object?> args) {
  requireArgs(args, 1, 'sum');
  return _numbers('sum', args[0]).fold<double>(0, (total, n) => total + n);
}

Object? _nativeAvg(List<Object?> args) {
  requireArgs(args, 1, 'avg');
  final numbers = _numbers('avg', args[0]);
  if (numbers.isEmpty) return 0.0;
  return numbers.fold<double>(0, (total, n) => total + n) / numbers.length;
}

Object? _nativeUnique(List<Object?> args) {
  requireArgs(args, 1, 'unique');
  final seen = <String>{};
  return [
    for (final item in listArg('unique', args[0]))
      if (seen.add(equalityKey(item))) item
  ];
}

/// One level only: `flatten([1, [2, [3]]])` is `[1, 2, [3]]`.
Object? _nativeFlatten(List<Object?> args) {
  requireArgs(args, 1, 'flatten');
  return [
    for (final item in listArg('flatten', args[0]))
      if (item is List) ...item else item
  ];
}

/// A new list: the argument is never modified, so `push` is used as
/// `items = push(items, x)`.
Object? _nativePush(List<Object?> args) {
  if (args.length < 2) {
    throw ArgumentError('push requires at least 2 arguments (array, item...)');
  }
  return [...listArg('push', args[0]), ...args.skip(1)];
}

Object? _nativeConcat(List<Object?> args) {
  final result = <Object?>[];
  for (final a in args) {
    if (a != null && a is! List) {
      throw ArgumentError('concat requires array arguments');
    }
    result.addAll(listArg('concat', a));
  }
  return result;
}

/// Stable: items with the same key keep their order, in both directions.
Object? _nativeSortBy(List<Object?> args) {
  requireArgsRange(args, 2, 3, 'sortBy');
  final list = listArg('sortBy', args[0]);
  final path = args[1];
  if (path is! String) {
    throw ArgumentError('sortBy requires a string path as second argument');
  }
  final order = args.length == 3 ? args[2] : 'asc';
  if (order != 'asc' && order != 'desc') {
    throw ArgumentError('sortBy order must be "asc" or "desc"');
  }
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final cmp = compareKeys(atPath(a.$2, path), atPath(b.$2, path));
    if (cmp != 0) return order == 'desc' ? -cmp : cmp;
    return a.$1.compareTo(b.$1);
  });
  return [for (final (_, item) in indexed) item];
}
