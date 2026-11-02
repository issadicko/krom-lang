import 'list_helpers.dart';
import 'natives.dart';
import 'native_helpers.dart';

/// Object utilities. Keys come in sorted order, the order in which every SDK
/// prints an object. `null` behaves as an empty object, so a value that has
/// not been loaded yet reads as having no keys; any other value raises.
void registerObjectNatives(NativeFunctions registry) {
  registry.register('keys', _nativeKeys);
  registry.register('values', _nativeValues);
  registry.register('entries', _nativeEntries);
  registry.register('has', _nativeHas);
}

Map<String, Object?> _objectArg(String name, Object? value) {
  if (value == null) return const {};
  if (value is Map) {
    return {for (final e in value.entries) e.key.toString(): e.value};
  }
  throw ArgumentError('$name requires an object argument');
}

List<String> _sortedKeys(Map<String, Object?> object) =>
    object.keys.toList()..sort();

Object? _nativeKeys(List<Object?> args) {
  requireArgs(args, 1, 'keys');
  return _sortedKeys(_objectArg('keys', args[0]));
}

Object? _nativeValues(List<Object?> args) {
  requireArgs(args, 1, 'values');
  final object = _objectArg('values', args[0]);
  return [for (final k in _sortedKeys(object)) object[k]];
}

Object? _nativeEntries(List<Object?> args) {
  requireArgs(args, 1, 'entries');
  final object = _objectArg('entries', args[0]);
  return [
    for (final k in _sortedKeys(object)) [k, object[k]]
  ];
}

/// An object has a key (a present key holding `null` counts); a list has an
/// equal value, per the equality of the list functions: `1` equals `1.0` but
/// not `"1"`.
Object? _nativeHas(List<Object?> args) {
  requireArgs(args, 2, 'has');
  final collection = args[0];
  if (collection == null) return false;
  if (collection is Map) {
    final key = args[1];
    if (key is! String) {
      throw ArgumentError('has requires a string key for objects');
    }
    return collection.containsKey(key);
  }
  if (collection is List) {
    final target = equalityKey(args[1]);
    return collection.any((item) => equalityKey(item) == target);
  }
  throw ArgumentError('has requires an object or array as first argument');
}
