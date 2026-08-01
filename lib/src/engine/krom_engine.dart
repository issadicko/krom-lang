/// KSEngine - Persistent script engine for mini-app execution.
///
/// This engine maintains script context between invocations,
/// allowing state persistence and reactive updates.
library;

import '../lexer/lexer.dart';
import '../parser/parser.dart';
import '../ast/ast.dart';
import '../interpreter/interpreter.dart';
import '../interpreter/environment.dart';
import '../interpreter/values.dart';
import '../natives/natives.dart';
import '../reactive/rx.dart';
import '../runtime/numbers.dart';
import '../errors/krom_exception.dart';
import '../optimizer/optimizer.dart';
import 'krom_engine_result.dart';
import 'execution_limits.dart';

export 'krom_engine_result.dart';
export 'execution_limits.dart';

/// Persistent script engine for mini-app execution.
///
/// Usage:
/// ```dart
/// final engine = KSEngine();
///
/// // Load and initialize the script
/// await engine.load('''
///   var counter = Obs(0)
///
///   function increment() {
///     counter.set(counter.value + 1)
///   }
///
///   function build() {
///     return { "type": "Text", "props": { "content": counter.value } }
///   }
/// ''');
///
/// // Get initial UI
/// final ui = await engine.invoke('build');
///
/// // Handle user action
/// await engine.invoke('increment');
///
/// // Get updated UI
/// final updatedUi = await engine.invoke('build');
/// ```
class KSEngine {
  /// The parsed program AST.
  Program? _program;

  /// The persistent environment holding variables and functions.
  Environment? _env;

  /// The interpreter for evaluating expressions.
  Interpreter? _interpreter;

  /// Native functions available to the script.
  NativeFunctions? _natives;

  /// Whether the engine has been loaded.
  bool _loaded = false;

  /// The bindings to apply when loading a script.
  final Map<String, KromBindable> _bindings = {};

  /// The op-budget / deadline guard applied to every execution. Safe by
  /// default (enabled, generous bounds); set [ExecutionLimits.unlimited] to
  /// disable for trusted code.
  ExecutionLimits _limits = const ExecutionLimits();

  ExecutionLimits get executionLimits => _limits;
  set executionLimits(ExecutionLimits limits) => _limits = limits;

  /// Operations consumed by the most recent execution — for host instrumentation
  /// (e.g. a dev preview's execution-budget meter). 0 before the first run.
  int get lastOpsUsed => _interpreter?.lastOpsUsed ?? 0;

  /// The current operation budget (0 = unlimited).
  int get maxOperations => _interpreter?.maxOperations ?? 0;

  /// Snapshot of the mini-app's reactive variables (`Obs`/`List`) keyed by name,
  /// with their current values — for host inspection (e.g. a state inspector).
  Map<String, Object?> reactiveState() {
    final env = _env;
    if (env == null) return const {};
    final out = <String, Object?>{};
    env.toMap().forEach((name, value) {
      if (value is Rx) out[name] = kromCanonicalValue(value.value);
    });
    return out;
  }

  /// Sets a reactive variable's value (triggering listeners/rebuild). Returns
  /// false if [name] is unknown, not reactive, or [value] is the wrong type.
  bool setReactiveValue(String name, Object? value) {
    final env = _env;
    if (env == null) return false;
    final (current, found) = env.get(name);
    if (!found || current is! Rx) return false;
    try {
      current.value = value;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Applies [executionLimits] to the interpreter before each run: resets the
  /// per-execution operation counter and sets a fresh wall-clock deadline, so a
  /// runaway `build()`/callback/loop throws instead of hanging the caller.
  void _applyLimits() {
    final i = _interpreter;
    if (i == null) return;
    _limits.applyTo(i);
  }

  /// Creates a new KSEngine instance.
  KSEngine() {
    _initNatives();
  }

  // ... (existing code)

  // ...

  /// Whether the engine is loaded and ready for invocation.
  bool get isLoaded => _loaded;

  /// Initializes native functions including reactive primitives.
  void _initNatives() {
    _natives = NativeFunctions.withBuiltins();
    // Register Obs function for creating reactive variables
    _natives!.register('Obs', createObs);

    // Register Computed for derived values (registered later when interpreter is available)
    // The actual Computed registration happens in load() after interpreter is created
  }

  /// Loads and initializes a script.
  ///
  /// This parses the source code and executes the global scope
  /// to initialize variables and function definitions.
  ///
  /// [enableOptimizer] - If true, applies constant folding optimization.
  ///
  /// Call this once before using [invoke].
  Future<KSEngineResult> load(String source,
      {bool enableOptimizer = false}) async {
    // Reset state
    _loaded = false;
    _program = null;

    final lexer = Lexer(source);
    final parser = Parser(lexer);
    var program = parser.parseProgram();

    // Check for parse errors
    if (parser.errors().isNotEmpty) {
      return KSEngineResult.error(parser.errors());
    }

    // Apply constant folding optimization if enabled
    if (enableOptimizer) {
      program = Optimizer().optimize(program);
    }

    _program = program;

    // Create fresh environment and interpreter
    _env = Environment();
    _interpreter = Interpreter(env: _env!, natives: _natives!);

    // Register Computed - needs interpreter reference
    _env!.set('Computed', NativeFunctionValue((args) {
      if (args.isEmpty || args[0] is! FunctionValue) {
        throw Exception('Computed requires a function argument');
      }
      final fn = args[0] as FunctionValue;
      return Computed(() => _interpreter!.callFunction(fn, []));
    }));

    // Register watch - observes an Rx and calls callback on change
    _env!.set('watch', NativeFunctionValue((args) {
      if (args.length < 2) {
        throw Exception('watch requires 2 arguments: observable and callback');
      }
      final rx = args[0];
      final callback = args[1];

      if (rx is! Rx) {
        throw Exception('First argument to watch must be an Obs or Computed');
      }
      if (callback is! FunctionValue) {
        throw Exception('Second argument to watch must be a function');
      }

      Object? previousValue = rx.value;

      rx.addListener(() {
        final newValue = rx.value;
        _interpreter!.callFunction(callback, [newValue, previousValue]);
        previousValue = newValue;
      });

      return null;
    }));

    // Apply bindings
    _bindings.forEach((name, value) {
      _env!.set(name, value);
    });

    // Apply variables. Host variables enter through THE RULE — see
    // `runtime/numbers.dart`.
    _variables.forEach((name, value) {
      _env!.set(name, kromCanonicalValue(value));
    });

    // Resolve static scopes for optimized variable lookup
    // final resolver = Resolver(_interpreter!);
    // resolver.resolve(_program!);

    // Execute global scope to initialize state
    try {
      _applyLimits();
      _interpreter!.eval(_program!);
      _loaded = true;
      return KSEngineResult.success(output: _interpreter!.getOutput());
    } catch (e) {
      return KSEngineResult.error([e.toString()]);
    }
  }

  /// Invokes a function defined in the loaded script.
  ///
  /// The function is executed with the current context,
  /// preserving all state from previous invocations.
  ///
  /// [funcName] - The name of the function to call.
  /// [args] - Optional arguments to pass to the function.
  ///
  /// Returns a [KSEngineResult] with the function's return value.
  Future<KSEngineResult> invoke(String funcName,
      [List<Object?> args = const []]) async {
    return invokeSynchronized(funcName, args);
  }

  /// Invokes a function synchronously.
  ///
  /// Throws if the engine is not loaded or the function doesn't exist.
  Object? invokeSync(String funcName, [List<Object?> args = const []]) {
    if (!_loaded) {
      throw KromRuntimeError('Engine not loaded. Call load() first.');
    }

    final (funcValue, found) = _env!.get(funcName);

    if (!found) {
      throw KromRuntimeError('Function "$funcName" not found');
    }

    if (funcValue is! FunctionValue) {
      throw KromRuntimeError('"$funcName" is not a function');
    }

    // callFunction can throw KromRuntimeError, which is what we want to propagate
    _applyLimits();
    return kromCanonicalValue(_interpreter!
        .callFunction(funcValue, args.map(kromCanonicalValue).toList()));
  }

  KSEngineResult invokeSynchronized(String funcName,
      [List<Object?> args = const []]) {
    if (!_loaded) {
      return KSEngineResult.error(['Engine not loaded. Call load() first.']);
    }

    // Look up the function in the environment
    final (funcValue, found) = _env!.get(funcName);

    if (!found) {
      return KSEngineResult.error(['Function "$funcName" not found']);
    }

    if (funcValue is! FunctionValue) {
      return KSEngineResult.error(['"$funcName" is not a function']);
    }

    try {
      _applyLimits();
      // Host arguments in, result out: both cross THE RULE — see
      // `runtime/numbers.dart`.
      final result = _interpreter!
          .callFunction(funcValue, args.map(kromCanonicalValue).toList());
      return KSEngineResult.success(
        value: kromCanonicalValue(result),
        output: _interpreter!.getOutput(),
      );
    } on KromException catch (e) {
      return KSEngineResult.error([e.toString()]);
    } catch (e) {
      return KSEngineResult.error(['Unexpected error: $e']);
    }
  }

  /// Gets a variable from the script context.
  ///
  /// Returns null if the variable doesn't exist or engine isn't loaded.
  Object? getVariable(String name) {
    if (_env == null) return null;
    final (value, found) = _env!.get(name);
    return found ? kromCanonicalValue(value) : null;
  }

  /// The variable values to apply when loading a script.
  final Map<String, Object?> _variables = {};

  /// ...

  /// Sets a variable in the script context.
  ///
  /// This can be used to inject values from the host application.
  void setVariable(String name, Object? value) {
    // Host variables enter through THE RULE — see `runtime/numbers.dart`.
    final canonical = kromCanonicalValue(value);
    _variables[name] = canonical;
    _env?.set(name, canonical);
  }

  /// Binds a Dart object to the script context.
  ///
  /// The object must implement [KromBindable].
  void bind(String name, KromBindable value) {
    _bindings[name] = value;
    _env?.set(name, value);
  }

  /// Returns a snapshot of the current state.
  ///
  /// Useful for debugging or serialization.
  Map<String, Object?> getState() {
    return _env?.toMap() ?? {};
  }

  /// Returns all output produced during script execution.
  List<String> getOutput() {
    return _interpreter?.getOutput() ?? [];
  }

  /// Clears the output buffer.
  void clearOutput() {
    _interpreter?.clearOutput();
  }

  /// Resets the engine to its initial state.
  ///
  /// After calling this, you must call [load] again.
  void reset() {
    _program = null;
    _env = null;
    _interpreter = null;
    _loaded = false;
    _initNatives();
  }

  /// Disposes all resources held by the engine.
  void dispose() {
    _program = null;
    _env = null;
    _interpreter = null;
    _natives = null;
    _loaded = false;
  }
}
