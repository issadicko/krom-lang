/// KromScript - A lightweight, embeddable scripting language for Dart.
///
/// Usage:
/// ```dart
/// import 'package:krom_script/krom_script.dart';
///
/// final result = KromScript.run('''
///   let name = "Krom"
///   print("Hello " + name)
/// ''');
///
/// print(result.output); // ["Hello Krom"]
/// ```
library krom_script;

import 'src/interpreter/environment.dart';
import 'src/interpreter/values.dart'; // import KromBindable

// Exports
export 'src/token/token.dart';
export 'src/lexer/lexer.dart';
export 'src/ast/ast.dart';
export 'src/ast/ast_printer.dart';
export 'src/parser/parser.dart';
export 'src/interpreter/interpreter.dart';
export 'src/interpreter/environment.dart'; // Export for custom execution environments
export 'src/interpreter/values.dart'; // Export KromBindable, ExecutionResult
export 'src/natives/natives.dart';
export 'src/errors/krom_exception.dart';

// Mini-App Engine exports
export 'src/engine/krom_engine.dart';
export 'src/engine/krom_engine_result.dart';
export 'src/reactive/rx.dart';
export 'src/reactive/rx_notifier.dart';

import 'src/lexer/lexer.dart';
import 'src/parser/parser.dart';
import 'src/interpreter/interpreter.dart';
import 'src/natives/natives.dart';
import 'src/cache/ast_cache.dart';
import 'src/errors/krom_exception.dart'; // Add this import

/// Result of script execution.
class ScriptResult {
  final Object? value;
  final List<String> output;
  final List<String> errors;

  const ScriptResult({
    this.value,
    this.output = const [],
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// KromScript is the main entry point for the KromScript SDK.
class KromScript {
  final String _source;
  final Map<String, Object?> _variables;
  final Map<String, NativeFunc> _customFunctions;
  final bool _useCache;
  final int _maxOps;
  final Duration _timeout;

  KromScript._({
    required String source,
    Map<String, Object?>? variables,
    Map<String, NativeFunc>? customFunctions,
    bool useCache = true,
    int maxOps = 0,
    Duration timeout = Duration.zero,
  })  : _source = source,
        _variables = variables ?? {},
        _customFunctions = customFunctions ?? {},
        _useCache = useCache,
        _maxOps = maxOps,
        _timeout = timeout;

  /// Builder for KromScript execution.
  static KromScriptBuilder builder(String source) => KromScriptBuilder(source);

  /// Run a script with optional variables.
  static ScriptResult run(String source, {Map<String, Object?>? variables}) {
    return KromScriptBuilder(source)
        .withVariables(variables ?? {})
        .execute();
  }

  /// Simple evaluation function.
  static Object? eval(String source) {
    final result = run(source);
    if (result.hasErrors) {
      throw KromScriptException(result.errors);
    }
    return result.value;
  }

  ScriptResult _execute() {
    // Try cache first
    var program = _useCache ? ASTCache.defaultCache.get(_source) : null;

    if (program == null) {
      // Lexer
      final lexer = Lexer(_source);

      // Parser
      final parser = Parser(lexer);
      program = parser.parseProgram();

      if (parser.errors().isNotEmpty) {
        return ScriptResult(errors: parser.errors());
      }

      // Store in cache
      if (_useCache) {
        ASTCache.defaultCache.set(_source, program);
      }
    }

    // Use singleton for built-ins, create copy only if custom functions registered
    NativeFunctions natives;
    if (_customFunctions.isEmpty) {
      natives = NativeFunctions.shared;
    } else {
      natives = NativeFunctions.withBuiltins();
      _customFunctions.forEach((name, fn) => natives.register(name, fn));
    }

    // Interpreter with environment and natives
    final env = Environment();
    _variables.forEach((k, v) => env.set(k, v));
    final interpreter = Interpreter(env: env, natives: natives);

    // Apply operation limit if set
    if (_maxOps > 0) {
      interpreter.setMaxOperations(_maxOps);
    }

    // Apply timeout if set
    if (_timeout > Duration.zero) {
      interpreter.setDeadline(
          DateTime.now().millisecondsSinceEpoch + _timeout.inMilliseconds);
    }

    try {
      final value = interpreter.eval(program);
      return ScriptResult(value: value, output: interpreter.getOutput());
    } on KromException catch (e) {
      return ScriptResult(errors: [e.toString()]);
    } catch (e) {
      return ScriptResult(errors: ['Unexpected error: $e']);
    }
  }
}

/// Builder for KromScript execution.
class KromScriptBuilder {
  final String _source;
  final Map<String, Object?> _variables = {};
  final Map<String, NativeFunc> _customFunctions = {};
  bool _useCache = true;
  int _maxOps = 0; // 0 = unlimited
  Duration _timeout = Duration.zero; // zero = no timeout

  KromScriptBuilder(this._source);

  /// Inject host variables into the script context.
  KromScriptBuilder withVariables(Map<String, Object?> vars) {
    _variables.addAll(vars);
    return this;
  }

  /// Inject a single variable.
  KromScriptBuilder withVariable(String name, Object? value) {
    _variables[name] = value;
    return this;
  }

  /// Register a custom native function.
  KromScriptBuilder registerFunction(String name, NativeFunc fn) {
    _customFunctions[name] = fn;
    return this;
  }

  /// Bind a Dart object to the script context.
  ///
  /// The object must implement [KromBindable] to expose properties and methods
  /// to KromScript. This allows the script to access the object's properties
  /// and call its methods.
  ///
  /// Example:
  /// ```dart
  /// class User implements KromBindable {
  ///   final String name;
  ///   User(this.name);
  ///
  ///   @override
  ///   Object? getProperty(String name) => name == 'name' ? this.name : null;
  ///
  ///   @override
  ///   Object? callMethod(String name, List<Object?> args) {
  ///     if (name == 'greet') return 'Hello, ${this.name}!';
  ///     return null;
  ///   }
  /// }
  ///
  /// final result = KromScript.builder('user.greet()')
  ///     .bind('user', User('Alice'))
  ///     .execute();
  /// ```
  KromScriptBuilder bind(String name, KromBindable obj) {
    _variables[name] = obj;
    return this;
  }

  /// Enable or disable AST caching.
  KromScriptBuilder withCache(bool enabled) {
    _useCache = enabled;
    return this;
  }

  /// Set the maximum number of operations allowed.
  /// Use this to protect against infinite loops.
  KromScriptBuilder withMaxOperations(int maxOps) {
    _maxOps = maxOps;
    return this;
  }

  /// Set the execution timeout.
  KromScriptBuilder withTimeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  /// Execute the script.
  ScriptResult execute() {
    return KromScript._(
      source: _source,
      variables: _variables,
      customFunctions: _customFunctions,
      useCache: _useCache,
      maxOps: _maxOps,
      timeout: _timeout,
    )._execute();
  }
}

/// Exception thrown when script execution fails.
class KromScriptException implements Exception {
  final List<String> errors;

  KromScriptException(this.errors);

  @override
  String toString() => errors.isNotEmpty ? errors.first : 'Unknown error';
}
