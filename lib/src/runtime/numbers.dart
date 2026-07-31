/// The one numeric-representation rule for values crossing the host boundary.
library;

/// THE RULE — one canonical numeric representation, applied on every path.
///
/// KromScript has a single number type and the interpreter computes on Dart
/// [double]s. That does not change: `1 + 1` is still `2.0` while it is being
/// evaluated, integer division, `%` and overflow behave exactly as before.
/// What is canonical is the Dart type a number has **when it crosses between
/// the interpreter and the host**:
///
/// * an integral value is an [int] — `2.0` becomes `2`, an incoming `3` stays `3`
/// * anything else is a [double] — `2.5` stays `2.5`
///
/// so the type no longer depends on the path a value happened to take
/// (issue #14: `m.n`, `m["n"]`, `1 + 1` and `l.length` used to give `3`, `3`,
/// `2.0`, `3.0`). `jsonEncode(result.value)` is stable, and it is stable on the
/// spelling the rest of the language already treats as canonical: `kromDisplay`
/// prints a whole number without its trailing `.0`, and the cross-implementation
/// conformance suite pins `print(3)` to `3` and `print(3.5)` to `3.5`. `int` is
/// the Dart type that serialises to those same characters — `3.0` is the one
/// form the canon never uses.
///
/// Applied at every crossing:
///
/// * host variables going in — `KromScript.run`/`withVariable(s)`,
///   `Interpreter.withVariables`, `KSEngine.setVariable`, `KSEngine.invoke` args
/// * values coming out — `ScriptResult.value`, `KSEngineResult.value`,
///   `KSEngine.invokeSync`, `KSEngine.getVariable`, `KSEngine.reactiveState`
/// * both directions of `KromBindable` — property and method results coming in,
///   call arguments going out
///
/// Deliberately *not* applied to three things, so that this stays one rule and
/// not a rule plus a habit:
///
/// * arguments of native functions (`registerFunction`), which share the
///   interpreter's own dispatch with the built-ins — what they receive is an
///   interpreter value, so declare them `num`;
/// * `jsonStringify`, the in-script wire format, unchanged since 1.0.0;
/// * `KSEngine.getState()`, a debug dump of the raw environment (functions,
///   natives, `Rx` wrappers) rather than a value channel.
num kromCanonicalNumber(num value) {
  if (value is int) return value;
  final d = value as double;
  // Doubles are exact integers well past 1e15; beyond that `truncate()` could
  // overflow or drop digits, so larger magnitudes keep their double form. Same
  // guard as `kromDisplay`, which renders through this function.
  if (d.isFinite && d.abs() < 1e15 && d == d.truncateToDouble()) {
    return d.truncate();
  }
  return d;
}

/// Applies [kromCanonicalNumber] to [value] and, recursively, to every number
/// inside a [List] or a [Map] it contains.
///
/// Returns the argument itself when nothing needs changing, so host data that
/// is already canonical — the common case, a map of `int`s — is passed through
/// without being copied. A collection that does hold a non-canonical number is
/// rebuilt rather than mutated in place: the host's own object is never written
/// to, and an unmodifiable one never throws.
Object? kromCanonicalValue(Object? value) {
  if (value is num) return kromCanonicalNumber(value);
  if (value is List) return _canonicalList(value);
  if (value is Map) return _canonicalMap(value);
  return value;
}

Object? _canonicalList(List<Object?> value) {
  List<Object?>? copy;
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    final canonical = kromCanonicalValue(item);
    if (identical(canonical, item)) continue;
    copy ??= List<Object?>.of(value);
    copy[i] = canonical;
  }
  return copy ?? value;
}

Object? _canonicalMap(Map<Object?, Object?> value) {
  Map<Object?, Object?>? copy;
  for (final entry in value.entries) {
    final canonical = kromCanonicalValue(entry.value);
    if (identical(canonical, entry.value)) continue;
    // String keys are kept String-keyed: object literals and host payloads are
    // `Map<String, Object?>`, and hosts cast the result back to that.
    copy ??= value is Map<String, Object?>
        ? Map<String, Object?>.of(value)
        : Map<Object?, Object?>.of(value);
    copy[entry.key] = canonical;
  }
  return copy ?? value;
}
