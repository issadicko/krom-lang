/// Human-facing stringification of KromScript values.
library;

/// Converts a KromScript value to its display string.
///
/// KromScript has a single number type (Dart doubles), so `3` would naïvely
/// display as `3.0` everywhere — `toString`, string interpolation, `+`
/// concatenation, `print`. This helper renders whole numbers without the
/// trailing `.0` while leaving true decimals untouched.
///
/// This is a DISPLAY rule only: `jsonStringify` (wire format) is deliberately
/// not routed through it, so payloads keep their numeric JSON encoding.
String kromDisplay(Object? value) {
  if (value == null) return 'null';
  if (value is double) {
    // Doubles are exact integers well past 1e15; beyond that .truncate()
    // could overflow or lose digits, so fall back to the default rendering.
    if (value.isFinite &&
        value.abs() < 1e15 &&
        value == value.truncateToDouble()) {
      return value.truncate().toString();
    }
    return value.toString();
  }
  if (value is List) {
    return '[${value.map(kromDisplay).join(', ')}]';
  }
  if (value is Map) {
    return '{${value.entries.map((e) => '${e.key}: ${kromDisplay(e.value)}').join(', ')}}';
  }
  return value.toString();
}
