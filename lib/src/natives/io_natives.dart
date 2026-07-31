import 'dart:convert';
import '../runtime/numbers.dart';
import 'natives.dart';
import 'native_helpers.dart';

void registerIONatives(NativeFunctions registry) {
  registry.register('jsonParse', _nativeJsonParse);
  registry.register('jsonStringify', _nativeJsonStringify);
  registry.register('base64Encode', _nativeBase64Encode);
  registry.register('base64Decode', _nativeBase64Decode);
  registry.register('urlEncode', _nativeUrlEncode);
  registry.register('urlDecode', _nativeUrlDecode);
}

// ============ JSON functions ============

Object? _nativeJsonParse(List<Object?> args) {
  requireArgs(args, 1, 'jsonParse');
  // `jsonDecode` already yields `int` for an integral literal and `double` for
  // a fractional one — the canonical form. Nothing to convert.
  return jsonDecode(getArgAsString(args, 0, 'jsonParse'));
}

Object? _nativeJsonStringify(List<Object?> args) {
  requireArgs(args, 1, 'jsonStringify');
  // The wire format is a boundary like any other: encode through THE RULE (see
  // `runtime/numbers.dart`) so a whole number serialises as `2`, not `2.0`, and
  // a body built here is byte-identical to the Go and TypeScript twins'.
  // `kromCanonicalValue` recurses into lists and maps, so nested numbers are
  // covered too, and `jsonStringify(jsonParse(s))` round-trips stably.
  return jsonEncode(kromCanonicalValue(args[0]));
}

// ============ Base64 functions ============

Object? _nativeBase64Encode(List<Object?> args) {
  requireArgs(args, 1, 'base64Encode');
  return base64Encode(utf8.encode(getArgAsString(args, 0, 'base64Encode')));
}

Object? _nativeBase64Decode(List<Object?> args) {
  requireArgs(args, 1, 'base64Decode');
  return utf8.decode(base64Decode(getArgAsString(args, 0, 'base64Decode')));
}

// ============ URL functions ============

Object? _nativeUrlEncode(List<Object?> args) {
  requireArgs(args, 1, 'urlEncode');
  return Uri.encodeComponent(getArgAsString(args, 0, 'urlEncode'));
}

Object? _nativeUrlDecode(List<Object?> args) {
  requireArgs(args, 1, 'urlDecode');
  return Uri.decodeComponent(getArgAsString(args, 0, 'urlDecode'));
}
