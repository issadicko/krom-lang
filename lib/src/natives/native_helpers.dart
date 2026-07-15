/// Helper functions for native function argument validation.
library;

/// Throws an [ArgumentError] if [args] does not have exactly [count] elements.
void requireArgs(List<Object?> args, int count, String name) {
  if (args.length != count) {
    throw ArgumentError('$name requires $count argument(s)');
  }
}

/// Throws an [ArgumentError] if [args] has fewer than [min] or more than [max] elements.
void requireArgsRange(List<Object?> args, int min, int max, String name) {
  if (args.length < min || args.length > max) {
    throw ArgumentError('$name requires between $min and $max argument(s)');
  }
}

/// Helper to convert a value to double strictly (no parsing strings unless allowString is true).
///
/// Throws [ArgumentError] if conversion fails.
double toDouble(Object? value, {String? name}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  // We generally don't want implicit string->number conversion in strict mode
  // but existing implementation did it. Let's keep existing behavior for now
  // but centralize it here.
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  final msg = name != null ? '$name must be a number' : 'expected a number';
  throw ArgumentError('$msg, got ${value?.runtimeType ?? "null"} ($value)');
}

/// Helper to get an argument at [index] as a [String].
String getArgAsString(List<Object?> args, int index, String funcName) {
  if (index >= args.length) {
    throw ArgumentError('$funcName: missing argument at index $index');
  }
  final val = args[index];
  if (val is String) return val;
  throw ArgumentError(
      '$funcName argument $index must be a string, got ${val?.runtimeType ?? "null"}');
}

/// Helper to get an argument at [index] as a [double].
double getArgAsDouble(List<Object?> args, int index, String funcName) {
  if (index >= args.length) {
    throw ArgumentError('$funcName: missing argument at index $index');
  }
  try {
    return toDouble(args[index], name: '$funcName argument $index');
  } catch (e) {
    throw ArgumentError(e.toString());
  }
}

/// Helper to get an argument at [index] as an [int].
int getArgAsInt(List<Object?> args, int index, String funcName) {
  return getArgAsDouble(args, index, funcName).toInt();
}

/// Helper to get an argument at [index] as a [bool].
bool getArgAsBool(List<Object?> args, int index, String funcName) {
  if (index >= args.length) {
    throw ArgumentError('$funcName: missing argument at index $index');
  }
  final val = args[index];
  if (val is bool) return val;
  throw ArgumentError(
      '$funcName argument $index must be a boolean, got ${val?.runtimeType ?? "null"}');
}

/// Helper to get an argument at [index] as a [List].
List getArgAsList(List<Object?> args, int index, String funcName) {
  if (index >= args.length) {
    throw ArgumentError('$funcName: missing argument at index $index');
  }
  final val = args[index];
  if (val is List) return val;
  throw ArgumentError(
      '$funcName argument $index must be a list, got ${val?.runtimeType ?? "null"}');
}

/// Helper to get an argument at [index] as a [Map].
Map getArgAsMap(List<Object?> args, int index, String funcName) {
  if (index >= args.length) {
    throw ArgumentError('$funcName: missing argument at index $index');
  }
  final val = args[index];
  if (val is Map) return val;
  throw ArgumentError(
      '$funcName argument $index must be a map, got ${val?.runtimeType ?? "null"}');
}
