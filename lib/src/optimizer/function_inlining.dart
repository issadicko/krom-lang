import '../ast/ast.dart';
import '../token/token.dart';

/// FunctionInliner replaces calls to small functions with their bodies.
/// 
/// Example:
/// fn add(a, b) { return a + b }
/// let x = add(1, 2)
/// 
/// Becomes (simplified):
/// let x = 1 + 2
/// 
/// Constraints:
/// - Only inlines functions with a single return statement (for now).
/// - Only inlines functions smaller than a certain threshold (e.g. 1 statement).
/// - Handles argument substitution.
class FunctionInliner {
  final Map<String, FunctionDeclaration> _inlinableFunctions = {};
  
  Program optimize(Program program) {
    _inlinableFunctions.clear();
    
    // Pass 1: Identify inlinable functions
    for (final stmt in program.statements) {
      if (stmt is FunctionDeclaration) {
        if (_isSmall(stmt)) {
          _inlinableFunctions[stmt.name.value] = stmt;
        }
      }
    }
    
    // Pass 2: Inline calls
    final optimizedStatements = <Statement>[];
    for (final stmt in program.statements) {
      optimizedStatements.add(_optimizeStatement(stmt));
    }
    return Program(optimizedStatements);
  }
  
  bool _isSmall(FunctionDeclaration func) {
    // Only inline if body has 1 statement and it is a ReturnStatement
    if (func.body.statements.length != 1) return false;
    final stmt = func.body.statements.first;
    if (stmt is! ReturnStatement || stmt.value == null) return false;
    // And only if the whole return expression is something [_substitute] can
    // fully rewrite. _substitute does NOT recurse into nested function literals,
    // object/array literals, property access or index expressions, so a
    // parameter used inside any of those would be left dangling after inlining
    // (e.g. `fn f(k){ return xs.filter(fn(c){ return c == k }) }` would inline
    // to a body where `k` is undefined). Bailing out keeps the call intact —
    // always correct, just unoptimised.
    return _isSafelyInlinable(stmt.value!);
  }

  /// True only if every node in [expr] is one that [_substitute] traverses and
  /// rewrites correctly. Conservative on purpose: unknown node types make a
  /// function non-inlinable rather than risk dropping a parameter substitution.
  bool _isSafelyInlinable(Expression expr) {
    if (expr is NumberLiteral ||
        expr is StringLiteral ||
        expr is BooleanLiteral ||
        expr is NullLiteral ||
        expr is Identifier) {
      return true;
    }
    if (expr is UnaryExpr) {
      return _isSafelyInlinable(expr.right);
    }
    if (expr is BinaryExpr) {
      return _isSafelyInlinable(expr.left) && _isSafelyInlinable(expr.right);
    }
    if (expr is CallExpr) {
      return _isSafelyInlinable(expr.function) &&
          expr.arguments.every(_isSafelyInlinable);
    }
    if (expr is Assignment) {
      return _isSafelyInlinable(expr.left) && _isSafelyInlinable(expr.value);
    }
    // FunctionLiteral, object/array literals, property access, index, string
    // templates, etc. — not handled by _substitute → not safe to inline.
    return false;
  }
  
  Statement _optimizeStatement(Statement stmt) {
    if (stmt is VarDecl) {
      return VarDecl(stmt.token, stmt.name, _optimizeExpression(stmt.value));
    } else if (stmt is ExpressionStatement) {
      return ExpressionStatement(stmt.token, _optimizeExpression(stmt.expression));
    } else if (stmt is ReturnStatement) {
      return ReturnStatement(stmt.token, stmt.value != null ? _optimizeExpression(stmt.value!) : null);
    } else if (stmt is BlockStatement) {
      return BlockStatement(stmt.token, stmt.statements.map(_optimizeStatement).toList());
    } else if (stmt is FunctionDeclaration) {
        // Optimize body of functions too
        return FunctionDeclaration(
            stmt.token, 
            stmt.name, 
            stmt.parameters, 
            _optimizeStatement(stmt.body) as BlockStatement
        );
    } else if (stmt is IfStatement) {
        return IfStatement(
            stmt.token,
            _optimizeExpression(stmt.condition),
            _optimizeStatement(stmt.consequence) as BlockStatement,
            stmt.alternative != null ? (_optimizeStatement(stmt.alternative!) as BlockStatement) : null
        );
    } else if (stmt is WhileStatement) {
        return WhileStatement(
            stmt.token,
            _optimizeExpression(stmt.condition),
            _optimizeStatement(stmt.body) as BlockStatement
        );
    }
    // ... other statements
    return stmt;
  }
  
  Expression _optimizeExpression(Expression expr) {
    if (expr is CallExpr) {
      // First, optimize the arguments directly
      final optimizedArgs = expr.arguments.map(_optimizeExpression).toList();
      
      // Update usage of arguments for inlining check
      Expression function = _optimizeExpression(expr.function);
      
      if (function is Identifier) {
        final name = function.value;
        if (_inlinableFunctions.containsKey(name)) {
             // Create a temporary CallExpr with optimized args to pass to inline
             // We can't modify 'expr' in place safely if it's reused (unlikely here but handled by creating new CallExpr)
             final callWithOptimizedArgs = CallExpr(expr.token, function, optimizedArgs);
             final inlined = _inlineCall(callWithOptimizedArgs, _inlinableFunctions[name]!);

             if (inlined != null) {
               // Recursively optimize the result of inlining!
               // This handles nested calls: id(id(5)) -> id(5) -> 5
               return _optimizeExpression(inlined);
             }
             // Could not inline (arg-count mismatch, or would duplicate a
             // side-effecting argument): keep the optimized call as-is.
             return callWithOptimizedArgs;
        }
      }
      
      return CallExpr(
          expr.token, 
          function, 
          optimizedArgs
      );
    } else if (expr is BinaryExpr) {
      return BinaryExpr(
          expr.token, 
          _optimizeExpression(expr.left), 
          expr.operator, 
          _optimizeExpression(expr.right)
      );
    } else if (expr is NumberLiteral || expr is StringLiteral || expr is BooleanLiteral || expr is NullLiteral) {
      return expr;
    } else if (expr is Identifier) {
        return expr;
    } else if (expr is UnaryExpr) {
        return UnaryExpr(expr.token, expr.operator, _optimizeExpression(expr.right));
    }
    // ... propagate
    return expr;
  }
  
  /// Inlines [call] to [func]'s body, or returns null if it cannot be inlined
  /// safely. Returning null (rather than the original call) is important: the
  /// caller re-optimizes a non-null result, which would loop forever on a call
  /// that keeps failing to inline.
  Expression? _inlineCall(CallExpr call, FunctionDeclaration func) {
    // 1. Map parameters to arguments
    if (call.arguments.length != func.parameters.length) {
      // Argument count mismatch, cannot inline safely without complex handling
      return null;
    }

    // 2. Get the return statement
    final returnStmt = func.body.statements.first as ReturnStatement;
    var returnExpr = returnStmt.value!;

    // 2b. Preserve argument evaluation semantics. _substitute copies the
    // argument expression into every occurrence of the parameter, so a
    // non-trivial (possibly side-effecting) argument would be evaluated once
    // per use — including zero times if the parameter is unused. Only literals
    // and identifiers are safe to duplicate/drop; for anything else, require
    // the parameter to be used exactly once.
    for (var i = 0; i < func.parameters.length; i++) {
      final arg = call.arguments[i];
      final pure = arg is NumberLiteral ||
          arg is StringLiteral ||
          arg is BooleanLiteral ||
          arg is NullLiteral ||
          arg is Identifier;
      if (!pure && _countUses(returnExpr, func.parameters[i].value) != 1) {
        return null; // not inlining would change evaluation count
      }
    }

    // 3. Substitute parameters with arguments in the return expression
    return _substitute(returnExpr, func.parameters, call.arguments);
  }

  /// Counts how many times [name] is referenced in [expr]. Only traverses the
  /// node kinds [_isSafelyInlinable] permits in an inlinable body.
  int _countUses(Expression expr, String name) {
    if (expr is Identifier) return expr.value == name ? 1 : 0;
    if (expr is UnaryExpr) return _countUses(expr.right, name);
    if (expr is BinaryExpr) {
      return _countUses(expr.left, name) + _countUses(expr.right, name);
    }
    if (expr is CallExpr) {
      var n = _countUses(expr.function, name);
      for (final a in expr.arguments) {
        n += _countUses(a, name);
      }
      return n;
    }
    if (expr is Assignment) {
      return _countUses(expr.left, name) + _countUses(expr.value, name);
    }
    return 0;
  }
  
  Expression _substitute(Expression expr, List<Identifier> params, List<Expression> args) {
       // Helper to map parameter name to argument expression
       Expression? resolveParam(String name) {
           for (var i = 0; i < params.length; i++) {
               if (params[i].value == name) {
                   return args[i];
               }
           }
           return null;
       }
       
       if (expr is Identifier) {
           final replacement = resolveParam(expr.value);
           if (replacement != null) {
               // Clone replacement? Since AST is immutable-ish (final fields), reusing nodes is mostly fine
               // UNLESS we modify parent pointers (which we don't have here).
               return replacement; 
           }
           return expr;
       } else if (expr is BinaryExpr) {
           return BinaryExpr(
               expr.token,
               _substitute(expr.left, params, args),
               expr.operator,
               _substitute(expr.right, params, args)
           );
       } else if (expr is UnaryExpr) {
           return UnaryExpr(
               expr.token,
               expr.operator,
               _substitute(expr.right, params, args)
           );
       } else if (expr is CallExpr) {
           return CallExpr(
               expr.token,
               _substitute(expr.function, params, args),
               expr.arguments.map((arg) => _substitute(arg, params, args)).toList()
           );
       } else if (expr is Assignment) {
           return Assignment(
               expr.token,
               _substitute(expr.left, params, args),
               _substitute(expr.value, params, args)
           );
       }
       // Literals return as is
       return expr;
  }
}
