/// Human-facing stringification of KromScript values.
library;

import 'numbers.dart';

/// Converts a KromScript value to its display string.
///
/// KromScript has a single number type and the interpreter computes on Dart
/// doubles, so `3` would naïvely display as `3.0` everywhere — `toString`,
/// string interpolation, `+` concatenation, `print`. Numbers are rendered
/// through [kromCanonicalNumber], the single numeric rule (see
/// `runtime/numbers.dart`), so a whole number prints without its trailing `.0`
/// whichever Dart spelling it arrived in and true decimals stay untouched.
///
/// This is a DISPLAY rule only: `jsonStringify` (wire format) is deliberately
/// not routed through it, so payloads keep their numeric JSON encoding.
String kromDisplay(Object? value) {
  if (value == null) return 'null';
  if (value is num) return kromCanonicalNumber(value).toString();
  if (value is List) {
    return '[${value.map(kromDisplay).join(', ')}]';
  }
  if (value is Map) {
    return '{${value.entries.map((e) => '${e.key}: ${kromDisplay(e.value)}').join(', ')}}';
  }
  return value.toString();
}
