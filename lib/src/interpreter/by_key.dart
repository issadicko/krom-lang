/// Grouping and aggregation by key, `groupBy(list, key)` and its siblings.
///
/// The key is a dotted path read on each item, or a function called as
/// `fn(item, index)`. They are builtins next to `map` and `filter` rather than
/// natives because the function form calls back into the script.
library;

import '../natives/list_helpers.dart';
import '../natives/natives.dart';
import '../runtime/krom_runtime_type.dart';
import '../runtime/krom_types.dart';
import 'values.dart';

const byKeyBuiltins = {
  'groupBy',
  'countBy',
  'indexBy',
  'uniqueBy',
  'sumBy',
  'minBy',
  'maxBy',
  'partition',
};

/// Runs the builtin [name] on [args]: the list, then the key.
Object? callByKey(
    String name, List<Object?> args, KromFunctionInvoker invoker) {
  final keyed = _Keyed(name, args, invoker);
  switch (name) {
    case 'groupBy':
      final groups = <String, Object?>{};
      for (var i = 0; i < keyed.items.length; i++) {
        final group = groups.putIfAbsent(keyed.groupKey(i), () => <Object?>[]);
        (group as List<Object?>).add(keyed.items[i]);
      }
      return sortedObject(groups);
    case 'countBy':
      final counts = <String, Object?>{};
      for (var i = 0; i < keyed.items.length; i++) {
        final group = keyed.groupKey(i);
        counts[group] = ((counts[group] as double?) ?? 0.0) + 1;
      }
      return sortedObject(counts);
    case 'indexBy':
      final index = <String, Object?>{};
      for (var i = 0; i < keyed.items.length; i++) {
        index[keyed.groupKey(i)] = keyed.items[i];
      }
      return sortedObject(index);
    case 'uniqueBy':
      final seen = <String>{};
      return [
        for (var i = 0; i < keyed.items.length; i++)
          if (seen.add(equalityKey(keyed.keys[i]))) keyed.items[i]
      ];
    case 'sumBy':
      var total = 0.0;
      for (final key in keyed.keys) {
        if (key == null) continue;
        if (key is! num) {
          throw ArgumentError(
              'sumBy requires numeric keys, got ${canonicalString(key)}');
        }
        total += key;
      }
      return total;
    case 'minBy':
      return keyed.extreme(-1);
    case 'maxBy':
      return keyed.extreme(1);
    case 'partition':
      final yes = <Object?>[], no = <Object?>[];
      for (var i = 0; i < keyed.items.length; i++) {
        (isTruthy(keyed.keys[i]) ? yes : no).add(keyed.items[i]);
      }
      return <Object?>[yes, no];
  }
  throw ArgumentError('unknown builtin: $name');
}

/// A list with the key of each item, computed once and in list order.
class _Keyed {
  final List<Object?> items;
  final List<Object?> keys;

  _Keyed._(this.items, this.keys);

  factory _Keyed(String name, List<Object?> args, KromFunctionInvoker invoker) {
    if (args.length != 2) {
      throw ArgumentError(
          '$name requires 2 arguments: array and key (path or function)');
    }
    final items = listArg(name, args[0]);
    final key = args[1];
    final Object? Function(Object?, int) keyOf;
    if (key is String) {
      keyOf = (item, _) => atPath(item, key);
    } else if (key is FunctionValue || key is NativeFunctionValue) {
      keyOf =
          (item, index) => invoker.applyFunction(key, [item, index.toDouble()]);
    } else {
      throw ArgumentError('$name requires a path string or a function as key');
    }
    return _Keyed._(items, [
      for (var i = 0; i < items.length; i++) keyOf(items[i], i),
    ]);
  }

  String groupKey(int i) => canonicalString(keys[i]);

  /// The item whose key is the smallest ([wanted] -1) or the largest (1);
  /// `null` keys are skipped and the first item wins on ties.
  Object? extreme(int wanted) {
    var best = -1;
    for (var i = 0; i < keys.length; i++) {
      if (keys[i] == null) continue;
      if (best < 0 || compareKeys(keys[i], keys[best]) * wanted > 0) best = i;
    }
    return best < 0 ? null : items[best];
  }
}
