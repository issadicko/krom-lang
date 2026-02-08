/// KromScript Native Functions - Built-in functions for the language.
library;

import 'math_natives.dart';
import 'string_natives.dart';
import 'date_natives.dart';
import 'io_natives.dart';
import 'misc_natives.dart';

/// Native function signature.
typedef NativeFunc = Object? Function(List<Object?> args);

/// Native function wrapper.
class NativeFunctionValue {
  final NativeFunc fn;
  NativeFunctionValue(this.fn);
}

/// Registry of native functions for KromScript.
class NativeFunctions {
  final Map<String, NativeFunc> _functions = {};

  NativeFunctions._();

  /// Shared singleton instance for built-in functions.
  static final shared = NativeFunctions._().._registerBuiltins();

  /// Create a new instance with built-in functions (for custom functions).
  factory NativeFunctions.withBuiltins() {
    final instance = NativeFunctions._();
    instance._functions.addAll(shared._functions);
    return instance;
  }

  NativeFunc? get(String name) => _functions[name];

  void register(String name, NativeFunc fn) {
    _functions[name] = fn;
  }

  void _registerBuiltins() {
    registerMiscNatives(this);
    registerStringNatives(this);
    registerMathNatives(this);
    registerDateNatives(this);
    registerIONatives(this);
  }
}
