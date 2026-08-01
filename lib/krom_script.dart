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
import 'src/runtime/numbers.dart'; // kromCanonicalValue: THE RULE

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
export 'src/runtime/display.dart'; // kromDisplay: shared number/value display rule
export 'src/runtime/numbers.dart'; // THE RULE: one numeric type at the boundary

// Mini-App Engine exports
export 'src/engine/krom_engine.dart';
export 'src/engine/krom_engine_result.dart';
export 'src/engine/execution_limits.dart'; // Guard applied to every execution
export 'src/reactive/rx.dart';
export 'src/reactive/rx_notifier.dart';

import 'src/lexer/lexer.dart';
import 'src/parser/parser.dart';
import 'src/interpreter/interpreter.dart';
import 'src/natives/natives.dart';
import 'src/cache/ast_cache.dart';
import 'src/errors/krom_exception.dart'; // Add this import
import 'src/engine/execution_limits.dart';

/// Result of script execution.
class ScriptResult {
  /// The script's value, with every number in canonical form: an integral
  /// number is an `int`, a fractional one a `double`, however the script
  /// reached it. See `kromCanonicalValue` for THE RULE.
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
  final ExecutionLimits _limits;

  KromScript._({
    required String source,
    Map<String, Object?>? variables,
    Map<String, NativeFunc>? customFunctions,
    bool useCache = true,
    ExecutionLimits limits = const ExecutionLimits(),
  })  : _source = source,
        _variables = variables ?? {},
        _customFunctions = customFunctions ?? {},
        _useCache = useCache,
        _limits = limits;

  /// Builder for KromScript execution.
  static KromScriptBuilder builder(String source) => KromScriptBuilder(source);

  /// Run a script with optional variables.
  ///
  /// Runs under the safe-by-default [ExecutionLimits] unless [limits] says
  /// otherwise; pass [ExecutionLimits.unlimited] to run unguarded.
  static ScriptResult run(
    String source, {
    Map<String, Object?>? variables,
    ExecutionLimits? limits,
  }) {
    final builder =
        KromScriptBuilder(source).withVariables(variables ?? const {});
    if (limits != null) builder.withLimits(limits);
    return builder.execute();
  }

  /// Simple evaluation function.
  ///
  /// Runs under the safe-by-default [ExecutionLimits] unless [limits] says
  /// otherwise; a script that trips the guard throws [KromScriptException].
  static Object? eval(String source, {ExecutionLimits? limits}) {
    final result = run(source, limits: limits);
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

    // Interpreter with environment and natives. Host variables enter through
    // THE RULE — see `src/runtime/numbers.dart`.
    final env = Environment();
    _variables.forEach((k, v) => env.set(k, kromCanonicalValue(v)));
    final interpreter = Interpreter(env: env, natives: natives);

    // Arm the execution guard (safe by default).
    _limits.applyTo(interpreter);

    try {
      final value = interpreter.eval(program);
      // ... and leave through it, so the type does not depend on the path.
      return ScriptResult(
          value: kromCanonicalValue(value), output: interpreter.getOutput());
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

  /// The op-budget / deadline guard applied to the execution. Safe by default;
  /// see [withLimits].
  ExecutionLimits _limits = const ExecutionLimits();

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

  /// Replace the execution guard wholesale.
  ///
  /// Executions are guarded by [ExecutionLimits] by default. Pass
  /// [ExecutionLimits.unlimited] to run trusted code with no operation budget
  /// and no deadline — the only way to opt out, so it stays greppable.
  ///
  /// ```dart
  /// KromScript.builder(source)
  ///     .withLimits(const ExecutionLimits(deadline: Duration(seconds: 5)))
  ///     .execute();
  /// ```
  KromScriptBuilder withLimits(ExecutionLimits limits) {
    _limits = limits;
    return this;
  }

  /// Set the maximum number of operations allowed, overriding the default
  /// budget. `0` = unlimited operations (the deadline still applies).
  ///
  /// Re-arms the guard if it was disabled by [withLimits].
  KromScriptBuilder withMaxOperations(int maxOps) {
    _limits = _limits.copyWith(enabled: true, maxOperations: maxOps);
    return this;
  }

  /// Set the execution timeout, overriding the default deadline.
  /// [Duration.zero] = no deadline (the operation budget still applies).
  ///
  /// Re-arms the guard if it was disabled by [withLimits].
  KromScriptBuilder withTimeout(Duration timeout) {
    _limits = _limits.copyWith(enabled: true, deadline: timeout);
    return this;
  }

  /// Execute the script.
  ScriptResult execute() {
    return KromScript._(
      source: _source,
      variables: _variables,
      customFunctions: _customFunctions,
      useCache: _useCache,
      limits: _limits,
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
