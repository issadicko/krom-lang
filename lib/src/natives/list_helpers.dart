/// Reading rules shared by the list natives and the by-key builtins
/// (`groupBy`, `sumBy`…): list arguments, dotted paths, equality and ordering.
library;

import '../runtime/numbers.dart';
import 'native_helpers.dart';

/// Reads a list argument for [name]; `null` is an empty list, any other
/// non-list value raises.
List<Object?> listArg(String name, Object? value) {
  if (value == null) return <Object?>[];
  if (value is List) return value;
  throw ArgumentError('$name requires an array as first argument');
}

/// Reads a dotted path: object keys, or list indexes written in digits.
/// The empty path is the value itself; a missing step gives `null`.
Object? atPath(Object? value, String path) {
  if (path.isEmpty) return value;
  var current = value;
  for (final segment in path.split('.')) {
    if (current is Map) {
      current = current[segment];
    } else if (current is List) {
      final index = int.tryParse(segment);
      if (index == null ||
          index < 0 ||
          index >= current.length ||
          segment != index.toString()) {
        return null;
      }
      current = current[index];
    } else {
      return null;
    }
  }
  return current;
}

/// The text of [value] with keys sorted and integral numbers without `.0`:
/// the same text for the same value, whatever the order its keys were built in.
String canonicalString(Object? value) {
  if (value == null) return 'null';
  if (value is num) return _numberText(value);
  if (value is List) return '[${value.map(canonicalString).join(', ')}]';
  if (value is Map) {
    final entries = [
      for (final e in value.entries) MapEntry(e.key.toString(), e.value)
    ]..sort((a, b) => a.key.compareTo(b.key));
    final parts = entries.map((e) => '${e.key}: ${canonicalString(e.value)}');
    return '{${parts.join(', ')}}';
  }
  return value.toString();
}

/// Plain decimal text: no trailing `.0`, no exponent.
String _numberText(num n) {
  final canonical = kromCanonicalNumber(n);
  if (canonical is int) return canonical.toString();
  final d = canonical as double;
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d.isNegative ? '-Inf' : '+Inf';
  if (d == d.truncateToDouble()) return BigInt.from(d).toString();
  final text = d.toString();
  final e = text.indexOf('e');
  if (e < 0) return text;
  return _expandExponent(
      text.substring(0, e), int.parse(text.substring(e + 1)));
}

String _expandExponent(String mantissa, int exponent) {
  final negative = mantissa.startsWith('-');
  final unsigned = negative ? mantissa.substring(1) : mantissa;
  final dot = unsigned.indexOf('.');
  final digits = unsigned.replaceFirst('.', '');
  final point = (dot < 0 ? unsigned.length : dot) + exponent;
  final String text;
  if (point <= 0) {
    text = '0.${'0' * -point}$digits';
  } else if (point >= digits.length) {
    text = '$digits${'0' * (point - digits.length)}';
  } else {
    text = '${digits.substring(0, point)}.${digits.substring(point)}';
  }
  return negative ? '-$text' : text;
}

/// Two values are equal when they have the same type and the same canonical
/// form: `1` equals `1.0` but not `"1"`, and key order does not matter.
String equalityKey(Object? value) =>
    '${typeName(value)}:${canonicalString(value)}';

/// Orders two values: numbers numerically, anything else by canonical text.
int compareKeys(Object? a, Object? b) {
  if (a is num && b is num) return a.compareTo(b);
  return canonicalString(a).compareTo(canonicalString(b));
}

/// An object whose keys are listed in sorted order, the order in which every
/// SDK prints one, so a grouping reads the same wherever it ran.
Map<String, Object?> sortedObject(Map<String, Object?> entries) {
  final keys = entries.keys.toList()..sort();
  return {for (final k in keys) k: entries[k]};
}
