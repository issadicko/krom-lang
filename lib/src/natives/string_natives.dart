import '../runtime/display.dart';
import 'natives.dart';
import 'native_helpers.dart';

void registerStringNatives(NativeFunctions registry) {
  registry.register('toString', _nativeToString);
  registry.register('toNumber', _nativeToNumber);
  registry.register('length', _nativeLength);
  registry.register('substring', _nativeSubstring);
  registry.register('toUpperCase', _nativeToUpperCase);
  registry.register('toLowerCase', _nativeToLowerCase);
  registry.register('trim', _nativeTrim);
  registry.register('split', _nativeSplit);
  registry.register('join', _nativeJoin);
  registry.register('replace', _nativeReplace);
  registry.register('contains', _nativeContains);
  registry.register('startsWith', _nativeStartsWith);
  registry.register('endsWith', _nativeEndsWith);
  registry.register('indexOf', _nativeIndexOf);
  registry.register('padLeft', _nativePadLeft);
  registry.register('padRight', _nativePadRight);
  registry.register('repeat', _nativeRepeat);
}

Object? _nativeToString(List<Object?> args) {
  requireArgs(args, 1, 'toString');
  return kromDisplay(args[0]);
}

Object? _nativeToNumber(List<Object?> args) {
  requireArgs(args, 1, 'toNumber');
  return toDouble(args[0], name: 'toNumber argument');
}

Object? _nativeLength(List<Object?> args) {
  requireArgs(args, 1, 'length');
  // Using getArgAsString would throw if not string, but length might support others?
  // Original implementation supported only String.
  return getArgAsString(args, 0, 'length').length.toDouble();
}

Object? _nativeSubstring(List<Object?> args) {
  requireArgsRange(args, 2, 3, 'substring');
  final str = getArgAsString(args, 0, 'substring');
  final start = getArgAsInt(args, 1, 'substring').clamp(0, str.length);
  if (args.length == 3) {
    final end = getArgAsInt(args, 2, 'substring').clamp(start, str.length);
    return str.substring(start, end);
  }
  return str.substring(start);
}

Object? _nativeToUpperCase(List<Object?> args) {
  requireArgs(args, 1, 'toUpperCase');
  return getArgAsString(args, 0, 'toUpperCase').toUpperCase();
}

Object? _nativeToLowerCase(List<Object?> args) {
  requireArgs(args, 1, 'toLowerCase');
  return getArgAsString(args, 0, 'toLowerCase').toLowerCase();
}

Object? _nativeTrim(List<Object?> args) {
  requireArgs(args, 1, 'trim');
  return getArgAsString(args, 0, 'trim').trim();
}

Object? _nativeSplit(List<Object?> args) {
  requireArgs(args, 2, 'split');
  return getArgAsString(args, 0, 'split')
      .split(getArgAsString(args, 1, 'split'));
}

Object? _nativeJoin(List<Object?> args) {
  requireArgs(args, 2, 'join');
  final arr = getArgAsList(args, 0, 'join');
  final sep = getArgAsString(args, 1, 'join');
  return arr.map(kromDisplay).join(sep);
}

Object? _nativeReplace(List<Object?> args) {
  requireArgs(args, 3, 'replace');
  return getArgAsString(args, 0, 'replace').replaceAll(
      getArgAsString(args, 1, 'replace'), getArgAsString(args, 2, 'replace'));
}

Object? _nativeContains(List<Object?> args) {
  requireArgs(args, 2, 'contains');
  return getArgAsString(args, 0, 'contains')
      .contains(getArgAsString(args, 1, 'contains'));
}

Object? _nativeStartsWith(List<Object?> args) {
  requireArgs(args, 2, 'startsWith');
  return getArgAsString(args, 0, 'startsWith')
      .startsWith(getArgAsString(args, 1, 'startsWith'));
}

Object? _nativeEndsWith(List<Object?> args) {
  requireArgs(args, 2, 'endsWith');
  return getArgAsString(args, 0, 'endsWith')
      .endsWith(getArgAsString(args, 1, 'endsWith'));
}

Object? _nativeIndexOf(List<Object?> args) {
  requireArgs(args, 2, 'indexOf');
  return getArgAsString(args, 0, 'indexOf')
      .indexOf(getArgAsString(args, 1, 'indexOf'))
      .toDouble();
}

Object? _nativePadLeft(List<Object?> args) {
  requireArgsRange(args, 2, 3, 'padLeft');
  final str = args[0]?.toString() ?? '';
  final length = getArgAsInt(args, 1, 'padLeft');
  final padChar =
      args.length > 2 ? (args[2]?.toString() ?? ' ').substring(0, 1) : ' ';
  return str.padLeft(length, padChar);
}

Object? _nativePadRight(List<Object?> args) {
  requireArgsRange(args, 2, 3, 'padRight');
  final str = args[0]?.toString() ?? '';
  final length = getArgAsInt(args, 1, 'padRight');
  final padChar =
      args.length > 2 ? (args[2]?.toString() ?? ' ').substring(0, 1) : ' ';
  return str.padRight(length, padChar);
}

Object? _nativeRepeat(List<Object?> args) {
  requireArgs(args, 2, 'repeat');
  final str = args[0]?.toString() ?? '';
  final count = getArgAsInt(args, 1, 'repeat').clamp(0, 1000000);
  return str * count;
}
