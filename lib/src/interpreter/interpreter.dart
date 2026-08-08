/// KromScript Interpreter - Evaluates AST nodes.
library;

import 'dart:developer';

import '../ast/ast.dart';
import '../natives/natives.dart';
import '../errors/krom_exception.dart';
import '../token/token.dart';
import '../runtime/display.dart';
import '../runtime/numbers.dart';
import '../runtime/krom_runtime_type.dart';
import '../runtime/krom_types.dart';
import 'environment.dart';
import 'values.dart';

// Removed extracted classes (Environment, Values, etc.)

/// Interpreter evaluates AST nodes.
class Interpreter implements KromFunctionInvoker {
  Environment _env;
  final NativeFunctions _natives;
  int _opCount = 0;
  int _maxOps = 0; // 0 = unlimited
  int _deadline = 0; // 0 = no timeout

  Interpreter({Environment? env, NativeFunctions? natives})
      : _env = env ?? Environment(),
        _natives = natives ?? NativeFunctions.shared {
    _registerTypes();
  }

  void _registerTypes() {
    final registry = TypeRegistry.instance;
    // Only register if not already there to avoid dupes if singleton shared?
    // Registry is singleton, so we should register once.
    // But since keys are types, overwriting is fine or checking.
    // Let's just register.
    registry.register<List>(KromListType());
    registry.register<Map>(KromMapType());
    registry.register<String>(KromStringType());
  }

  final Map<Expression, int> _locals = {};

  void resolve(Expression expr, int depth) {
    _locals[expr] = depth;
  }

  // ignore: unused_element - Infrastructure for future optimized variable lookup
  Object? _lookupVariable(String name, Expression expr) {
    final distance = _locals[expr];
    if (distance != null) {
      return _env.getAt(distance, name);
    } else {
      // If not resolved, use standard lookup (walks scope chain)
      // This handles globals, natives, and any unresolved variables
      final (value, found) = _env.get(name);
      if (found) return value;
      return null; // Let caller handle undefined
    }
  }

  @override
  Object? applyFunction(Object? fn, List<Object?> args) {
    return _applyFunction(fn, args);
  }

  Object? _evalPropertyAccess(PropertyAccessExpr expr, {bool forCall = false}) {
    final obj = _evalExpression(expr.obj);
    if (obj == null) {
      _fail("cannot access property '${expr.property.value}' on null",
          expr.token);
    }

    return _resolveProperty(obj, expr.property.value, forCall: forCall);
  }

  /// Resolves `obj.prop` on a non-null receiver.
  ///
  /// Presence, not truthiness, decides: a member that exists and holds null
  /// reads as null instead of being mistaken for a resolution failure. On a
  /// container (map, list, string) an unknown member also reads as null, the
  /// way a missing property is `undefined` in JavaScript.
  ///
  /// [forCall] is true when this access is the callee of a call expression —
  /// the only position where a bindable's method may be materialized.
  Object? _resolveProperty(Object obj, String prop, {required bool forCall}) {
    final handler = TypeRegistry.instance.getHandler(obj);
    if (handler != null) {
      final value = handler.getProperty(obj, prop, this);
      // Only a null answer is ambiguous — no such member, or a member holding
      // null — so only then is the presence check worth its dispatch.
      if (value != null || handler.hasProperty(obj, prop, this)) return value;
      // Handled type, unknown member: null, unless the object also exposes a
      // binding surface of its own.
      if (obj is! KromBindable) return null;
    }

    if (obj is KromBindable) {
      return _bindablePropertyAccess(obj, prop, forCall: forCall);
    }

    throw Exception("cannot access property '$prop' on ${obj.runtimeType}: "
        "object must implement KromBindable");
  }

  factory Interpreter.withVariables(Map<String, Object?> variables) {
    final env = Environment();
    // Host variables enter through THE RULE — see `runtime/numbers.dart`.
    variables.forEach((k, v) => env.set(k, kromCanonicalValue(v)));
    return Interpreter(env: env);
  }

  /// Sets the maximum number of operations allowed.
  /// If maxOps is 0, there is no limit (default).
  void setMaxOperations(int maxOps) {
    _maxOps = maxOps;
    _opCount = 0;
  }

  /// Sets the execution deadline (milliseconds since epoch).
  void setDeadline(int deadline) {
    _deadline = deadline;
  }

  /// Operations consumed by the most recent execution — for host instrumentation
  /// (e.g. a dev preview's execution-budget meter). Reset at the start of each run.
  int get lastOpsUsed => _opCount;

  /// The current operation budget (0 = unlimited).
  int get maxOperations => _maxOps;

  /// Checks the operation limit and throws if exceeded.
  void _checkOperationLimit() {
    if (_maxOps > 0) {
      _opCount++;
      if (_opCount > _maxOps) {
        throw KromResourceError('max operations exceeded');
      }
    }
  }

  /// Checks if the deadline has been exceeded.
  void _checkDeadline() {
    if (_deadline > 0) {
      if (DateTime.now().millisecondsSinceEpoch > _deadline) {
        throw KromResourceError('execution timeout');
      }
    }
  }

  Object? eval(Program program) {
    Object? result;
    for (final stmt in program.statements) {
      result = _evalStatement(stmt);
      if (result is ReturnValue) {
        return result.value;
      }
    }
    return result;
  }

  /// Returns the current environment.
  ///
  /// Used by KSEngine to access the script context.
  Environment get environment => _env;

  /// Calls a user-defined function with the given arguments.
  ///
  /// This is a public wrapper around [_applyFunction] for use by KSEngine.
  Object? callFunction(FunctionValue fn, List<Object?> args) {
    return _applyFunction(fn, args);
  }

  List<String> getOutput() => _env.getOutput();

  /// Clears the output buffer.
  void clearOutput() {
    _env.clearOutput();
  }

  /// A runtime failure that says where it happened.
  ///
  /// The faulty token has known its line since the lexer; not carrying it into
  /// the message is what left `undefined variable: total` sending the author
  /// back to re-read the whole file.
  Never _fail(String message, Token at) =>
      throw KromRuntimeError(message, line: at.line, column: at.column);

  /// [error] with the position of [at], unless it already carries one.
  ///
  /// The message survives, so an error raised by a native or by a corner the
  /// interpreter does not name explicitly still gains a line.
  KromRuntimeError _positioned(Object error, Token at) {
    final message = error is KromException
        ? error.message
        : error.toString().replaceFirst(RegExp(r'^\w*(Exception|Error):\s*'), '');
    return KromRuntimeError(message, line: at.line, column: at.column);
  }

  /// Statements are the net: whatever an expression failed to name gets at
  /// least the line of the statement that was running. Nesting is harmless —
  /// the innermost frame stamps first, the outer ones see a positioned error
  /// and let it pass.
  Object? _evalStatement(Statement stmt) {
    try {
      return _evalStatementBody(stmt);
    } catch (error, stack) {
      // A budget/deadline stop is not a fault in the code being run, and an
      // error that already names its position must keep it.
      if (error is KromResourceError) rethrow;
      if (error is KromException && error.line != null) rethrow;
      Error.throwWithStackTrace(_positioned(error, stmt.token), stack);
    }
  }

  Object? _evalStatementBody(Statement stmt) {
    // Check operation limit at each statement
    _checkOperationLimit();
    // Check deadline at each statement
    _checkDeadline();

    switch (stmt) {
      case VarDecl():
        final value = _evalExpression(stmt.value);
        _env.set(stmt.name.value, value);
        return value;

      case ExpressionStatement():
        return _evalExpression(stmt.expression);
      case IfStatement():
        return _evalIfStatement(stmt);
      case BlockStatement():
        return _evalBlockStatement(stmt);
      case ReturnStatement():
        final value = stmt.value != null ? _evalExpression(stmt.value!) : null;
        return ReturnValue(value);
      case ForStatement():
        return _evalForStatement(stmt);
      case WhileStatement():
        return _evalWhileStatement(stmt);
      case FunctionDeclaration():
        final fn = FunctionValue(stmt.parameters, stmt.body, _env);
        _env.set(stmt.name.value, fn);
        return null; // Function declaration statement returns null
    }
  }

  Object? _evalIfStatement(IfStatement stmt) {
    final condition = _evalExpression(stmt.condition);
    if (_isTruthy(condition)) {
      return _evalBlockStatement(stmt.consequence);
    } else if (stmt.alternative != null) {
      return _evalBlockStatement(stmt.alternative!);
    }
    return null;
  }

  Object? _evalForStatement(ForStatement stmt) {
    final iterableVal = _evalExpression(stmt.iterable);

    // `for (k in map)` iterates the KEYS (values via map[k]). Keys are
    // snapshotted so the body may add/remove entries safely.
    final List<Object?> items;
    if (iterableVal is List) {
      items = iterableVal;
    } else if (iterableVal is Map) {
      items = iterableVal.keys.toList();
    } else {
      _fail('for-in requires an array or a map, got ${iterableVal?.runtimeType}',
          stmt.iterable.token);
    }

    Object? result;
    final varName = stmt.variable.value;

    for (final item in items) {
      // Check operation limit at each iteration
      _checkOperationLimit();
      // Check deadline at each iteration
      _checkDeadline();

      _env.set(varName, item);
      final value = _evalBlockStatement(stmt.body);
      if (value is ReturnValue) {
        return value;
      }
      result = value;
    }

    return result;
  }

  Object? _evalWhileStatement(WhileStatement stmt) {
    Object? result;

    while (true) {
      // Check operation limit at each iteration
      _checkOperationLimit();
      // Check deadline at each iteration
      _checkDeadline();

      // Evaluate condition
      final conditionValue = _evalExpression(stmt.condition);

      // Exit if condition is false
      if (!_isTruthy(conditionValue)) {
        break;
      }

      // Execute body
      final value = _evalBlockStatement(stmt.body);
      if (value is ReturnValue) {
        return value;
      }
      result = value;
    }

    return result;
  }

  Object? _evalBlockStatement(BlockStatement block) {
    Object? result;
    for (final stmt in block.statements) {
      result = _evalStatement(stmt);
      if (result is ReturnValue) {
        return result;
      }
    }
    return result;
  }

  String _evalStringTemplate(StringTemplate tmpl) {
    final buffer = StringBuffer();
    for (final part in tmpl.parts) {
      // String parts are written verbatim; interpolated values go through the
      // display rule (whole numbers render without the trailing .0).
      final value = _evalExpression(part);
      buffer
          .write(part is StringLiteral ? value.toString() : kromDisplay(value));
    }
    return buffer.toString();
  }

  Object? _evalExpression(Expression expr) {
    switch (expr) {
      case NumberLiteral():
        return expr.value;
      case StringLiteral():
        return expr.value;
      case StringTemplate():
        return _evalStringTemplate(expr);
      case BooleanLiteral():
        return expr.value;
      case NullLiteral():
        return null;
      case Identifier():
        // Use optimized lookup if resolver has run
        if (_locals.containsKey(expr)) {
          final value = _lookupVariable(expr.value, expr);
          if (value != null) return value;
          // If null, still check natives before erroring
        }
        // Standard lookup (walks scope chain)
        final (value, found) = _env.get(expr.value);
        if (found) return value;

        final native = _natives.get(expr.value);
        if (native != null) return NativeFunctionValue(native);

        _fail('undefined variable: ${expr.value}', expr.token);
      case FunctionLiteral():
        return FunctionValue(expr.parameters, expr.body, _env);
      case BinaryExpr():
        return _evalBinaryExpr(expr);
      case UnaryExpr():
        return _evalUnaryExpr(expr);
      case SafeAccessExpr():
        return _evalSafeAccess(expr);
      case ElvisExpr():
        return _evalElvisExpr(expr);
      case TernaryExpr():
        // Lazy branches: only the taken side is evaluated.
        return _isTruthy(_evalExpression(expr.condition))
            ? _evalExpression(expr.consequent)
            : _evalExpression(expr.alternate);
      case PropertyAccessExpr():
        return _evalPropertyAccess(expr);
      case CallExpr():
        return _evalCallExpr(expr);
      case ArrayLiteral():
        return expr.elements.map((e) => _evalExpression(e)).toList();
      case ObjectLiteral():
        return expr.pairs.map((k, v) => MapEntry(k, _evalExpression(v)));
      case IndexExpr():
        return _evalIndexExpression(expr);
      case Assignment():
        return _evalAssignment(expr.left, expr.value);
    }
  }

  Object? _evalAssignment(Expression left, Expression rightExpr) {
    final right = _evalExpression(rightExpr);

    switch (left) {
      case Identifier():
        _env.update(left.value, right);
        return right;

      case IndexExpr():
        final target = _evalExpression(left.left);
        final index = _evalExpression(left.index);

        if (target is List) {
          final idx = _toNumber(index).toInt();
          // Auto-expand list if assigning directly to length
          if (idx == target.length) {
            target.add(right);
            return right;
          }
          if (idx < 0 || idx > target.length) {
            throw RangeError(
                'Index out of range: $idx (length: ${target.length})');
          }
          target[idx] = right;
          return right;
        } else if (target is Map) {
          // Same coercion as reads: m[3] and m["3"] hit the same slot.
          target[kromDisplay(index)] = right;
          return right;
        }
        _fail("Cannot assign to index of ${target.runtimeType}", left.token);

      case PropertyAccessExpr():
        final target = _evalExpression(left.obj);
        final property = left.property.value;

        if (target is Map) {
          target[property] = right;
          return right;
        }
        _fail("Cannot assign property '$property' on ${target.runtimeType}",
            left.token);

      default:
        _fail("Invalid assignment target: ${left.runtimeType}", left.token);
    }
  }

  Object? _evalIndexExpression(IndexExpr expr) {
    final left = _evalExpression(expr.left);
    final index = _evalExpression(expr.index);

    if (left is List) {
      final idx = _toNumber(index).toInt();
      if (idx < 0 || idx >= left.length) return null;
      return left[idx];
    }

    if (left is Map) {
      final key = kromDisplay(index);
      return left[key];
    }

    _fail('index operator not supported: ${left?.runtimeType}', expr.token);
  }

  Object? _evalBinaryExpr(BinaryExpr expr) {
    if (expr.operator == '=') {
      return _evalAssignment(expr.left, expr.right);
    }

    final left = _evalExpression(expr.left);

    // Short-circuit for && and ||
    switch (expr.operator) {
      case '&&':
        if (!_isTruthy(left)) return false;
        return _isTruthy(_evalExpression(expr.right));
      case '||':
        if (_isTruthy(left)) return true;
        return _isTruthy(_evalExpression(expr.right));
    }

    final right = _evalExpression(expr.right);

    switch (expr.operator) {
      case '+':
        return _evalPlus(left, right);
      case '-':
        return _toNumber(left) - _toNumber(right);
      case '*':
        return _toNumber(left) * _toNumber(right);
      case '/':
        final r = _toNumber(right);
        if (r == 0) _fail('division by zero', expr.token);
        return _toNumber(left) / r;
      case '%':
        final r = _toNumber(right);
        if (r == 0) _fail('modulo by zero', expr.token);
        return _toNumber(left) % r;
      case '==':
        return left == right;
      case '!=':
        return left != right;
      case '<':
      case '>':
      case '<=':
      case '>=':
        return _compareOrdered(left, expr.operator, right);
      default:
        _fail('unknown operator: ${expr.operator}', expr.token);
    }
  }

  Object? _evalPlus(Object? left, Object? right) {
    if (left is String || right is String) {
      return '${kromDisplay(left)}${kromDisplay(right)}';
    }
    return _toNumber(left) + _toNumber(right);
  }

  Object? _evalUnaryExpr(UnaryExpr expr) {
    final right = _evalExpression(expr.right);
    switch (expr.operator) {
      case '-':
        return -_toNumber(right);
      case '!':
        return !_isTruthy(right);
      default:
        _fail('unknown unary operator: ${expr.operator}', expr.token);
    }
  }

  Object? _evalSafeAccess(SafeAccessExpr expr, {bool forCall = false}) {
    final obj = _evalExpression(expr.obj);
    // `?.` resolves exactly like `.`; it differs on one point only — a null
    // receiver yields null instead of throwing.
    if (obj == null) return null;

    return _resolveProperty(obj, expr.property.value, forCall: forCall);
  }

  Object? _evalElvisExpr(ElvisExpr expr) {
    final left = _evalExpression(expr.left);
    return left ?? _evalExpression(expr.defaultValue);
  }

  Object? _evalCallExpr(CallExpr expr) {
    final funcExpr = expr.function;

    // Special print handling
    if (funcExpr is Identifier && funcExpr.value == 'print') {
      final args = expr.arguments.map((a) => _evalExpression(a)).toList();
      for (final arg in args) {
        final output = kromDisplay(arg);
        log(output, name: 'KromScript');
        // Also emit through Dart's print so embedders that capture print()
        // (e.g. the dev preview's console panel, which runs the app in a Zone
        // with a print handler) surface the mini-app's output.
        // ignore: avoid_print
        print(output);
        _env.addOutput(output);
      }
      return null;
    }

    // Special handling for higher-order array functions
    if (funcExpr is Identifier) {
      switch (funcExpr.value) {
        case 'map':
          return _evalMapFunction(expr);
        case 'filter':
          return _evalFilterFunction(expr);
        case 'reduce':
          return _evalReduceFunction(expr);
        case 'find':
          return _evalFindFunction(expr);
        case 'findIndex':
          return _evalFindIndexFunction(expr);
      }
    }

    // Callee position: a property access resolved here knows it is being
    // called, which is what lets a bindable's method be materialized without
    // handing a callable back to a plain read.
    final Object? function;
    if (funcExpr is PropertyAccessExpr) {
      function = _evalPropertyAccess(funcExpr, forCall: true);
    } else if (funcExpr is SafeAccessExpr) {
      function = _evalSafeAccess(funcExpr, forCall: true);
    } else {
      function = _evalExpression(funcExpr);
    }
    final args = expr.arguments.map((a) => _evalExpression(a)).toList();

    return _applyFunction(function, args);
  }

  Object? _evalMapFunction(CallExpr expr) {
    if (expr.arguments.length < 2) {
      _fail('map requires 2 arguments: array and function', expr.token);
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return <Object?>[];
    final fnVal = _evalExpression(expr.arguments[1]);
    return arrVal
        .asMap()
        .entries
        .map((e) => _applyFunction(fnVal, [e.value, e.key.toDouble()]))
        .toList();
  }

  Object? _evalFilterFunction(CallExpr expr) {
    if (expr.arguments.length < 2) {
      _fail('filter requires 2 arguments: array and function', expr.token);
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return <Object?>[];
    final fnVal = _evalExpression(expr.arguments[1]);
    final result = <Object?>[];
    for (var i = 0; i < arrVal.length; i++) {
      if (_isTruthy(_applyFunction(fnVal, [arrVal[i], i.toDouble()]))) {
        result.add(arrVal[i]);
      }
    }
    return result;
  }

  Object? _evalReduceFunction(CallExpr expr) {
    if (expr.arguments.length < 3) {
      _fail('reduce requires 3 arguments: array, function, and initial value',
          expr.token);
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return null;
    final fnVal = _evalExpression(expr.arguments[1]);
    var accumulator = _evalExpression(expr.arguments[2]);
    for (var i = 0; i < arrVal.length; i++) {
      accumulator =
          _applyFunction(fnVal, [accumulator, arrVal[i], i.toDouble()]);
    }
    return accumulator;
  }

  Object? _evalFindFunction(CallExpr expr) {
    if (expr.arguments.length < 2) {
      _fail('find requires 2 arguments: array and function', expr.token);
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return null;
    final fnVal = _evalExpression(expr.arguments[1]);
    for (var i = 0; i < arrVal.length; i++) {
      if (_isTruthy(_applyFunction(fnVal, [arrVal[i], i.toDouble()]))) {
        return arrVal[i];
      }
    }
    return null;
  }

  Object? _evalFindIndexFunction(CallExpr expr) {
    if (expr.arguments.length < 2) {
      _fail('findIndex requires 2 arguments: array and function', expr.token);
    }
    final arrVal = _evalExpression(expr.arguments[0]);
    if (arrVal is! List) return -1.0;
    final fnVal = _evalExpression(expr.arguments[1]);
    for (var i = 0; i < arrVal.length; i++) {
      if (_isTruthy(_applyFunction(fnVal, [arrVal[i], i.toDouble()]))) {
        return i.toDouble();
      }
    }
    return -1.0;
  }

  Object? _applyFunction(Object? fn, List<Object?> args) {
    if (fn is FunctionValue) {
      final extendedEnv = Environment(fn.env);
      for (var i = 0; i < fn.parameters.length; i++) {
        final val = (i < args.length) ? args[i] : null;
        extendedEnv.set(fn.parameters[i].value, val);
      }

      final previousEnv = _env;
      _env = extendedEnv;
      try {
        final result = _evalBlockStatement(fn.body);
        if (result is ReturnValue) return result.value;
        return result;
      } finally {
        _env = previousEnv;
      }
    }

    if (fn is NativeFunctionValue) {
      return fn.fn(args);
    }

    throw KromRuntimeError('not a function: ${fn?.runtimeType}');
  }

  bool _isTruthy(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    return true;
  }

  /// Numeric coercion for arithmetic (`+`, `-`, `*`, `/`, `%`, unary `-`) and
  /// for list indices. Falls back to 0.0.
  ///
  /// Deliberately *not* used by the ordering operators: see [_compareOrdered].
  double _toNumber(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // ============ Ordering ============
  //
  // THE RULE — `<`, `>`, `<=` and `>=` are defined only over numbers and
  // strings that parse as numbers. Any other operand — null, bool, map, list,
  // function, non-numeric string — is not orderable: the comparison is
  // undefined and evaluates to **false**, on either side, for all four
  // operators.
  //
  // Why false and not an answer: an unfilled field is null, and coercing it to
  // 0.0 — the behaviour up to 1.0.1, issue #15 — made `age < 18` true, firing
  // a validation rule that should have stayed dormant. Under this rule
  // `age < 18` and `age >= 18` are *both* false on unknown data, so no
  // ordering rule fires on a value we do not have. That intentionally breaks
  // the identity `!(a < b) == (a >= b)`, exactly as IEEE-754 NaN and
  // JavaScript do.
  //
  // Why not JavaScript's coercion: JS propagates NaN the same way, but its
  // ToNumber is permissive (null -> 0, true -> 1, [] -> 0), so JS itself
  // answers `null < 5 === true`. KromScript has no `undefined`; null is its
  // single absent value — an unfilled field, a missing map key, an
  // out-of-range index, `?.` on null — so it behaves like JS's `undefined`,
  // which is NaN. Equality (`==` / `!=`) is unaffected.

  /// Applies the ordering rule above to one comparison.
  bool _compareOrdered(Object? left, String op, Object? right) {
    final l = _toOrderableNumber(left);
    final r = _toOrderableNumber(right);

    // Stated explicitly rather than left to IEEE-754: an undefined comparison
    // is false for every operator, `<=` and `>=` included.
    if (l.isNaN || r.isNaN) return false;

    switch (op) {
      case '<':
        return l < r;
      case '>':
        return l > r;
      case '<=':
        return l <= r;
      case '>=':
        return l >= r;
      default:
        throw Exception('unknown ordering operator: $op');
    }
  }

  /// The orderable numeric value of [value], or [double.nan] if it has none.
  double _toOrderableNumber(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    // A numeric string keeps comparing numerically ("10" > 5); a string that
    // is not a number does not.
    if (value is String) return double.tryParse(value) ?? double.nan;
    return double.nan;
  }

  // ============ Bindable Object Support ============

  /// Accesses properties on KromBindable objects.
  ///
  /// [KromBindable.getProperty] answers null both for a property that holds
  /// null and for one the object does not know, and the interface offers no
  /// way to ask which methods it declares. So a read resolves to the property
  /// value or to null, and the callable method wrapper is built only where the
  /// access is actually called ([forCall]) — a bare read must never hand host
  /// code an opaque callable that then flows into its data.
  Object? _bindablePropertyAccess(KromBindable obj, String propertyName,
      {required bool forCall}) {
    final propValue = obj.getProperty(propertyName);
    if (propValue != null) {
      return _acrossBindableBoundary(propValue);
    }

    if (!forCall) return null;

    // Callee position: return a callable wrapper for method invocation
    return NativeFunctionValue((args) {
      final result = obj.callMethod(
          propertyName, args.map(_acrossBindableBoundary).toList());
      // Check sentinel by identity or value
      if (result == methodNotFound) {
        throw Exception(
            "method or property '$propertyName' not found on ${obj.runtimeType}");
      }
      return _acrossBindableBoundary(result);
    });
  }

  /// The `KromBindable` boundary, crossed in both directions: property and
  /// method results coming in, call arguments going out.
  ///
  /// Applies THE RULE — see `runtime/numbers.dart` — to the number itself and
  /// leaves everything else by identity, collections included. A bound object
  /// hands back its own live objects (an `Obs`'s list, say); rebuilding one
  /// here would silently break write-through. Numbers nested inside are made
  /// canonical when the value finally leaves through `ScriptResult.value`.
  Object? _acrossBindableBoundary(Object? value) =>
      value is num ? kromCanonicalNumber(value) : value;
}
