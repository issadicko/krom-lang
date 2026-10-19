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
