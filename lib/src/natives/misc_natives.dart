import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../reactive/rx.dart';
import '../reactive/rx_list.dart';
import 'natives.dart';
import 'native_helpers.dart';

void registerMiscNatives(NativeFunctions registry) {
    // Reactive factories
    registry.register('Obs', createObs);
    registry.register('List', createRxList);

    // Type functions
    registry.register('typeOf', _nativeTypeOf);
    registry.register('isNull', _nativeIsNull);
    registry.register('isNumber', _nativeIsNumber);
    registry.register('isString', _nativeIsString);
    registry.register('isBool', _nativeIsBool);
    registry.register('toInt', _nativeToInt);
    registry.register('toDouble', _nativeToDouble);

    // Random functions
    registry.register('random', _nativeRandom);
    registry.register('randomInt', _nativeRandomInt);
    registry.register('randomUUID', _nativeRandomUUID);

    // Crypto/Hash functions
    registry.register('md5', _nativeMd5);
    registry.register('sha1', _nativeSha1);
    registry.register('sha256', _nativeSha256);

    // Array functions
    registry.register('sort', _nativeSort);
    registry.register('reverse', _nativeReverse);
    registry.register('size', _nativeSize);
    registry.register('first', _nativeFirst);
    registry.register('last', _nativeLast);
    registry.register('slice', _nativeSlice);
    registry.register('setProperty', _nativeSetProperty);
}

// ============ Type functions ============

Object? _nativeTypeOf(List<Object?> args) {
  requireArgs(args, 1, 'typeOf');
  final arg = args[0];
  if (arg == null) return 'null';
  if (arg is String) return 'string';
  if (arg is double || arg is int) return 'number';
  if (arg is bool) return 'boolean';
  if (arg is Map) return 'object';
  if (arg is List) return 'array';
  return 'unknown';
}

Object? _nativeIsNull(List<Object?> args) {
  requireArgs(args, 1, 'isNull');
  return args[0] == null;
}

Object? _nativeIsNumber(List<Object?> args) {
  requireArgs(args, 1, 'isNumber');
  return args[0] is double || args[0] is int;
}

Object? _nativeIsString(List<Object?> args) {
  requireArgs(args, 1, 'isString');
  return args[0] is String;
}

Object? _nativeIsBool(List<Object?> args) {
  requireArgs(args, 1, 'isBool');
  return args[0] is bool;
}

// ============ Conversion functions ============

Object? _nativeToInt(List<Object?> args) {
  try {
    if (args.isEmpty) return 0.0;
    final value = args[0];
    if (value == null) return 0.0;
    
    if (value is int) return value.toDouble();
    if (value is double) return value.toInt().toDouble();
    if (value is bool) return value ? 1.0 : 0.0;
    
    if (value is String) {
      if (value.isEmpty) return 0.0;
      final n = num.tryParse(value);
      if (n != null) return n.toInt().toDouble();
      return 0.0;
    }
    
    // Lists, Maps, etc return 0
    return 0.0;
  } catch (e) {
    print('Error converting to int: $e');
    return 0.0;
  }
}

Object? _nativeToDouble(List<Object?> args) {
  try {
    if (args.isEmpty) return 0.0;
    final value = args[0];
    if (value == null) return 0.0;
    
    if (value is num) return value.toDouble();
    if (value is bool) return value ? 1.0 : 0.0;
    
    if (value is String) {
      if (value.isEmpty) return 0.0;
      final n = double.tryParse(value);
      if (n != null) return n;
      return 0.0;
    }
    
    return 0.0;
  } catch (e) {
    print('Error converting to double: $e');
    return 0.0;
  }
}

// ============ Random functions ============

final _random = Random();

Object? _nativeRandom(List<Object?> args) {
  requireArgs(args, 0, 'random');
  return _random.nextDouble();
}

Object? _nativeRandomInt(List<Object?> args) {
  requireArgs(args, 2, 'randomInt');
  final minVal = getArgAsInt(args, 0, 'randomInt');
  final maxVal = getArgAsInt(args, 1, 'randomInt');
  if (minVal >= maxVal)
    throw ArgumentError('randomInt: min must be less than max');
  return (_random.nextInt(maxVal - minVal + 1) + minVal).toDouble();
}

Object? _nativeRandomUUID(List<Object?> args) {
  requireArgs(args, 0, 'randomUUID');
  // Generate UUID v4
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

// ============ Crypto/Hash functions ============

Object? _nativeMd5(List<Object?> args) {
  requireArgs(args, 1, 'md5');
  return md5.convert(utf8.encode(getArgAsString(args, 0, 'md5'))).toString();
}

Object? _nativeSha1(List<Object?> args) {
  requireArgs(args, 1, 'sha1');
  return sha1.convert(utf8.encode(getArgAsString(args, 0, 'sha1'))).toString();
}

Object? _nativeSha256(List<Object?> args) {
  requireArgs(args, 1, 'sha256');
  return sha256
      .convert(utf8.encode(getArgAsString(args, 0, 'sha256')))
      .toString();
}

// ============ Array functions ============

Object? _nativeSort(List<Object?> args) {
  requireArgsRange(args, 1, 2, 'sort');
  final arr = List.of(getArgAsList(args, 0, 'sort'));
  final ascending = args.length < 2 || (args[1] as String) != 'desc';
  arr.sort((a, b) {
    final cmp = compareValues(a, b);
    return ascending ? cmp : -cmp;
  });
  return arr;
}

Object? _nativeReverse(List<Object?> args) {
  requireArgs(args, 1, 'reverse');
  return getArgAsList(args, 0, 'reverse').reversed.toList();
}

Object? _nativeSize(List<Object?> args) {
  requireArgs(args, 1, 'size');
  final v = args[0];
  if (v is List) return v.length.toDouble();
  if (v is String) return v.length.toDouble();
  if (v is Map) return v.length.toDouble();
  throw ArgumentError('size requires an array, string, or object, got ${v?.runtimeType}');
}

Object? _nativeFirst(List<Object?> args) {
  requireArgs(args, 1, 'first');
  final arr = getArgAsList(args, 0, 'first');
  return arr.isEmpty ? null : arr.first;
}

Object? _nativeLast(List<Object?> args) {
  requireArgs(args, 1, 'last');
  final arr = getArgAsList(args, 0, 'last');
  return arr.isEmpty ? null : arr.last;
}

Object? _nativeSlice(List<Object?> args) {
  requireArgsRange(args, 2, 3, 'slice');
  final arr = getArgAsList(args, 0, 'slice');
  final start = getArgAsInt(args, 1, 'slice').clamp(0, arr.length);
  if (args.length == 3) {
    final end = getArgAsInt(args, 2, 'slice').clamp(start, arr.length);
    return arr.sublist(start, end);
  }
  return arr.sublist(start);
}

Object? _nativeSetProperty(List<Object?> args) {
  requireArgs(args, 3, 'setProperty');
  final target = args[0];
  final key = args[1];
  final value = args[2];

  if (target is Map) {
    target[key] = value;
    return value;
  } else if (target is List) {
    final index = toDouble(key, name: 'setProperty index').toInt();
    if (index >= 0 && index < target.length) {
      target[index] = value;
      return value;
    }
    throw RangeError('Index out of range: $index');
  }
  throw ArgumentError('setProperty requires a map or array as target');
}

// ============ Helpers ============

int compareValues(Object? a, Object? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;

  // Use toDouble from helper isn't quite right here as we want to know if it IS a number without throwing
  if ((a is num || a is String && double.tryParse(a) != null) &&
      (b is num || b is String && double.tryParse(b) != null)) {
       // Safe to compare as numbers
       final aNum = toDouble(a);
       final bNum = toDouble(b);
       return aNum.compareTo(bNum);
  }

  return a.toString().compareTo(b.toString());
}
