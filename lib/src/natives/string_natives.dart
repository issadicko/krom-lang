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
  registry.register('parseInt', _nativeParseInt);
  registry.register('parseFloat', _nativeParseFloat);
  registry.register('regexMatch', _nativeRegexMatch);
  registry.register('regexReplace', _nativeRegexReplace);
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

/// A number, or a number written in text (surrounding spaces ignored).
double _parseNumber(String name, Object? value, String what) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
    throw ArgumentError("cannot parse '$value' as $what");
  }
  throw ArgumentError('$name requires a string or number');
}

/// Truncated toward zero: `parseInt("3.9")` is `3`, `parseInt("-3.9")` is `-3`.
Object? _nativeParseInt(List<Object?> args) {
  requireArgs(args, 1, 'parseInt');
  final n = _parseNumber('parseInt', args[0], 'integer');
  return n.isFinite ? n.truncateToDouble() : n;
}

Object? _nativeParseFloat(List<Object?> args) {
  requireArgs(args, 1, 'parseFloat');
  return _parseNumber('parseFloat', args[0], 'number');
}

RegExp _pattern(String name, Object? pattern) {
  if (pattern is! String) {
    throw ArgumentError('$name requires a string pattern');
  }
  try {
    return RegExp(pattern);
  } on FormatException catch (e) {
    throw ArgumentError('invalid regex: ${e.message}');
  }
}

/// True when [pattern] matches anywhere in the text; anchor it with `^…$` to
/// test the whole text.
Object? _nativeRegexMatch(List<Object?> args) {
  requireArgs(args, 2, 'regexMatch');
  final text = args[0];
  if (text is! String) {
    throw ArgumentError('regexMatch requires a string as first argument');
  }
  return _pattern('regexMatch', args[1]).hasMatch(text);
}

/// Replaces every match. The replacement reads `$1` as a group, `$<name>` as
/// a named group, `$&` as the whole match and `$$` as a dollar sign — the
/// JavaScript spelling, since `${…}` is string interpolation in the language.
Object? _nativeRegexReplace(List<Object?> args) {
  requireArgs(args, 3, 'regexReplace');
  final text = args[0];
  if (text is! String) {
    throw ArgumentError('regexReplace requires a string as first argument');
  }
  final replacement = args[2];
  if (replacement is! String) {
    throw ArgumentError('regexReplace requires a string replacement');
  }
  final reference = RegExp(r'\$(\$|&|\d+|<(\w+)>)');
  return text.replaceAllMapped(_pattern('regexReplace', args[1]), (match) {
    return replacement.replaceAllMapped(reference, (ref) {
      final token = ref[1]!;
      if (token == r'$') return r'$';
      if (token == '&') return match[0]!;
      final name = ref[2];
      if (name != null) {
        return match is RegExpMatch && match.groupNames.contains(name)
            ? (match.namedGroup(name) ?? '')
            : ref[0]!;
      }
      final index = int.parse(token);
      return index <= match.groupCount ? (match.group(index) ?? '') : ref[0]!;
    });
  });
}
