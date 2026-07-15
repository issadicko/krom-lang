import '../ast/ast.dart';
import '../interpreter/interpreter.dart';
import '../token/token.dart';

/// Scope types for static analysis.
enum ScopeType {
  global,
  function,
  loop,
}

/// Resolver performs static analysis to resolve variable scopes.
class Resolver {
  final Interpreter interpreter;
  final List<Map<String, bool>> _scopes = [];
  ScopeType _currentFnScope = ScopeType.global;

  // Tracking if we are inside a loop (for break/continue validation - future)
  // Tracking function type (to validate return statements)

  Resolver(this.interpreter);

  void resolve(Program program) {
    _beginScope(); // Global scope
    for (final stmt in program.statements) {
      _resolveStatement(stmt);
    }
    _endScope();
  }

  void _resolveStatement(Statement stmt) {
    if (stmt is BlockStatement) {
      _beginScope();
      _resolveBlockStatement(stmt);
      _endScope();
    } else if (stmt is VarDecl) {
      _declare(stmt.name.token);
      _resolveExpression(stmt.value);
      _define(stmt.name.token);
    } else if (stmt is FunctionDeclaration) {
      _declare(stmt.name.token);
      _define(stmt.name.token);
      _resolveFunction(stmt, ScopeType.function);
    } else if (stmt is ExpressionStatement) {
      _resolveExpression(stmt.expression);
    } else if (stmt is IfStatement) {
      _resolveExpression(stmt.condition);
      _resolveStatement(stmt.consequence);
      if (stmt.alternative != null) _resolveStatement(stmt.alternative!);
    } else if (stmt is ReturnStatement) {
      if (_currentFnScope == ScopeType.global) {
        // Error: return outside function?
        // Interpreter allows it for script exit.
      }
      if (stmt.value != null) {
        _resolveExpression(stmt.value!);
      }
    } else if (stmt is WhileStatement) {
      _resolveExpression(stmt.condition);
      _resolveStatement(stmt.body);
    } else if (stmt is ForStatement) {
      _beginScope(); // For loop has its own scope for variable
      _declare(stmt.variable.token);
      _define(stmt.variable.token);
      _resolveExpression(stmt.iterable);
      _resolveStatement(stmt.body);
      _endScope();
    }
  }

  void _resolveExpression(Expression expr) {
    if (expr is Identifier) {
      if (_scopes.isNotEmpty && _scopes.last[expr.value] == false) {
        // Error: Cannot read local variable in its own initializer
      }
      _resolveLocal(expr, expr.token);
    } else if (expr is BinaryExpr) {
      _resolveExpression(expr.left);
      _resolveExpression(expr.right);
    } else if (expr is CallExpr) {
      _resolveExpression(expr.function);
      for (final arg in expr.arguments) {
        _resolveExpression(arg);
      }
    } else if (expr is FunctionLiteral) {
      _resolveFunctionLiteral(expr, ScopeType.function);
    } else if (expr is Assignment) {
      // Resolve the value being assigned
      _resolveExpression(expr.value);
      // Resolve the target (left side)
      if (expr.left is Identifier) {
        _resolveLocal(expr.left, (expr.left as Identifier).token);
      } else {
        // For IndexExpr or PropertyAccessExpr, resolve sub-expressions
        _resolveExpression(expr.left);
      }
    } else if (expr is UnaryExpr) {
      _resolveExpression(expr.right);
    } else if (expr is ArrayLiteral) {
      for (final elem in expr.elements) {
        _resolveExpression(elem);
      }
    } else if (expr is ObjectLiteral) {
      for (final value in expr.pairs.values) {
        _resolveExpression(value);
      }
    } else if (expr is IndexExpr) {
      _resolveExpression(expr.left);
      _resolveExpression(expr.index);
    } else if (expr is PropertyAccessExpr) {
      _resolveExpression(expr.obj);
    } else if (expr is SafeAccessExpr) {
      _resolveExpression(expr.obj);
    } else if (expr is ElvisExpr) {
      _resolveExpression(expr.left);
      _resolveExpression(expr.defaultValue);
    } else if (expr is TernaryExpr) {
      _resolveExpression(expr.condition);
      _resolveExpression(expr.consequent);
      _resolveExpression(expr.alternate);
    } else if (expr is StringTemplate) {
      for (final part in expr.parts) {
        _resolveExpression(part);
      }
    }
    // Literals (NumberLiteral, StringLiteral, BooleanLiteral, NullLiteral) need no resolution
  }

  void _resolveFunction(FunctionDeclaration function, ScopeType type) {
    final enclosingFn = _currentFnScope;
    _currentFnScope = type;
    _beginScope();
    for (final param in function.parameters) {
      _declare(param.token);
      _define(param.token);
    }
    _resolveBlockStatement(function.body);
    _endScope();
    _currentFnScope = enclosingFn;
  }

  void _resolveFunctionLiteral(FunctionLiteral function, ScopeType type) {
    final enclosingFn = _currentFnScope;
    _currentFnScope = type;
    _beginScope();
    for (final param in function.parameters) {
      _declare(param.token);
      _define(param.token);
    }
    _resolveBlockStatement(function.body);
    _endScope();
    _currentFnScope = enclosingFn;
  }

  void _resolveBlockStatement(BlockStatement block) {
    for (final stmt in block.statements) {
      _resolveStatement(stmt);
    }
  }

  void _beginScope() {
    _scopes.add({});
  }

  void _endScope() {
    _scopes.removeLast();
  }

  void _declare(Token name) {
    if (_scopes.isEmpty) return;
    final scope = _scopes.last;
    if (scope.containsKey(name.literal)) {
      // Error: Variable with this name already declared in this scope
    }
    scope[name.literal] = false; // Declared but not defined/initialized
  }

  void _define(Token name) {
    if (_scopes.isEmpty) return;
    _scopes.last[name.literal] = true;
  }

  void _resolveLocal(Expression expr, Token name) {
    for (var i = _scopes.length - 1; i >= 0; i--) {
      if (_scopes[i].containsKey(name.literal)) {
        interpreter.resolve(expr, _scopes.length - 1 - i);
        return;
      }
    }
  }
}
