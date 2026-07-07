import 'dart:math';
import 'natives.dart';
import 'native_helpers.dart';

void registerMathNatives(NativeFunctions registry) {
  registry.register('abs', _nativeAbs);
  registry.register('floor', _nativeFloor);
  registry.register('ceil', _nativeCeil);
  registry.register('round', _nativeRound);
  registry.register('min', _nativeMin);
  registry.register('max', _nativeMax);
  registry.register('pow', _nativePow);
  registry.register('sqrt', _nativeSqrt);
  registry.register('sin', _nativeSin);
  registry.register('cos', _nativeCos);
  registry.register('tan', _nativeTan);
  registry.register('log', _nativeLog);
  registry.register('log10', _nativeLog10);
  registry.register('exp', _nativeExp);
  registry.register('range', _nativeRange);
}

/// range(fin) | range(debut, fin) | range(debut, fin, pas)
/// Half-open interval [debut, fin) — range(3) => [0, 1, 2].
Object? _nativeRange(List<Object?> args) {
  requireArgsRange(args, 1, 3, 'range');
  var start = 0.0;
  double end;
  var step = 1.0;
  if (args.length == 1) {
    end = getArgAsDouble(args, 0, 'range');
  } else {
    start = getArgAsDouble(args, 0, 'range');
    end = getArgAsDouble(args, 1, 'range');
    if (args.length == 3) step = getArgAsDouble(args, 2, 'range');
  }
  if (step == 0) throw ArgumentError('range: step must not be 0');
  // Native allocation escapes the interpreter's op budget: cap the size so
  // range(1e12) cannot OOM the host.
  final count = ((end - start) / step).ceil();
  if (count > 1000000) {
    throw ArgumentError('range: too many elements ($count, max 1000000)');
  }
  final out = <Object?>[];
  if (step > 0) {
    for (var v = start; v < end; v += step) {
      out.add(v);
    }
  } else {
    for (var v = start; v > end; v += step) {
      out.add(v);
    }
  }
  return out;
}

Object? _nativeAbs(List<Object?> args) {
  requireArgs(args, 1, 'abs');
  return getArgAsDouble(args, 0, 'abs').abs();
}

Object? _nativeFloor(List<Object?> args) {
  requireArgs(args, 1, 'floor');
  return getArgAsDouble(args, 0, 'floor').floorToDouble();
}

Object? _nativeCeil(List<Object?> args) {
  requireArgs(args, 1, 'ceil');
  return getArgAsDouble(args, 0, 'ceil').ceilToDouble();
}

Object? _nativeRound(List<Object?> args) {
  requireArgs(args, 1, 'round');
  return getArgAsDouble(args, 0, 'round').roundToDouble();
}

Object? _nativeMin(List<Object?> args) {
  if (args.length < 2) throw ArgumentError('min requires at least 2 arguments');
  return args.map((a) => toDouble(a, name: 'min argument')).reduce(min);
}

Object? _nativeMax(List<Object?> args) {
  if (args.length < 2) throw ArgumentError('max requires at least 2 arguments');
  return args.map((a) => toDouble(a, name: 'max argument')).reduce(max);
}

Object? _nativePow(List<Object?> args) {
  requireArgs(args, 2, 'pow');
  return pow(getArgAsDouble(args, 0, 'pow'), getArgAsDouble(args, 1, 'pow'))
      .toDouble();
}

Object? _nativeSqrt(List<Object?> args) {
  requireArgs(args, 1, 'sqrt');
  final n = getArgAsDouble(args, 0, 'sqrt');
  if (n < 0) throw ArgumentError('sqrt of negative number');
  return sqrt(n);
}

Object? _nativeSin(List<Object?> args) {
  requireArgs(args, 1, 'sin');
  return sin(getArgAsDouble(args, 0, 'sin'));
}

Object? _nativeCos(List<Object?> args) {
  requireArgs(args, 1, 'cos');
  return cos(getArgAsDouble(args, 0, 'cos'));
}

Object? _nativeTan(List<Object?> args) {
  requireArgs(args, 1, 'tan');
  return tan(getArgAsDouble(args, 0, 'tan'));
}

Object? _nativeLog(List<Object?> args) {
  requireArgs(args, 1, 'log');
  final n = getArgAsDouble(args, 0, 'log');
  if (n <= 0) throw ArgumentError('log of non-positive number');
  return log(n);
}

Object? _nativeLog10(List<Object?> args) {
  requireArgs(args, 1, 'log10');
  final n = getArgAsDouble(args, 0, 'log10');
  if (n <= 0) throw ArgumentError('log10 of non-positive number');
  return log(n) / ln10;
}

Object? _nativeExp(List<Object?> args) {
  requireArgs(args, 1, 'exp');
  return exp(getArgAsDouble(args, 0, 'exp'));
}
