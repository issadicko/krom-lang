import '../ast/ast.dart';

/// TreeShaker performs dead code elimination by removing unused functions.
/// 
/// It analyzes the AST to build a call graph, then removes functions that
/// are not reachable from entry points (like `build` or callback references).
class TreeShaker {
  final Set<String> _declaredFunctions = {};
  final Set<String> _calledFunctions = {};
  final Set<String> _referencedCallbacks = {};
  final Map<String, FunctionDeclaration> _functionMap = {};
  
  /// Entry point function names that should always be kept.
  ///
  /// Includes the page lifecycle hooks (onInit/onShow/onHide/onDispose): the
  /// host runtime invokes these by name, never KromScript code, so without
  /// listing them here the tree-shaker would consider them unreachable and drop
  /// them from optimized bundles — making pages never run their refresh logic.
  static const entryPoints = {
    'build',
    'main',
    'onInit',
    'onShow',
    'onHide',
    'onDispose',
    // Legacy aliases kept for backward compatibility.
    'init',
    'dispose',
  };
  
  /// Common callback pattern suffixes
  static const callbackPatterns = ['Builder', 'Callback', 'Handler', 'Listener'];

  /// Functions called or referenced from top-level (module-init) statements.
  /// These run unconditionally when the script loads, so they are roots even
  /// though no function calls them.
  final Set<String> _topLevelRoots = {};

  /// Shake the program tree - remove unused functions
  Program shake(Program program) {
    // Phase 1: Collect all declared functions
    _collectDeclaredFunctions(program);

    // Phase 2: Collect all function calls and callback references
    _collectCalls(program);

    // Phase 2b: Collect functions reached from top-level statements (e.g.
    // `let items = makeDefaults()`). Without this they'd be dropped while their
    // call site at module scope survives → runtime "undefined function".
    _collectTopLevelRoots(program);

    // Phase 3: Mark reachable functions starting from entry points
    final reachable = _markReachable();

    // Phase 4: Filter out unreachable functions
    return _filterProgram(program, reachable);
  }

  /// Phase 2b: function names called/referenced from top-level statements.
  void _collectTopLevelRoots(Program program) {
    for (final stmt in program.statements) {
      // Function *bodies* are explored lazily by the BFS once the function is
      // proven reachable; here we only want module-level (always-run) code.
      if (stmt is FunctionDeclaration) continue;
      _collectCallsInNode(stmt, _topLevelRoots);
    }
  }

  /// Phase 1: Collect all declared function names
  void _collectDeclaredFunctions(Program program) {
    for (final stmt in program.statements) {
      if (stmt is FunctionDeclaration) {
        final name = stmt.name.value;
        _declaredFunctions.add(name);
        _functionMap[name] = stmt;
      }
    }
  }

  /// Phase 2: Collect all function calls and callback references
  void _collectCalls(Program program) {
    for (final stmt in program.statements) {
      _collectCallsFromStatement(stmt);
    }
  }

  void _collectCallsFromStatement(Statement stmt) {
    if (stmt is ExpressionStatement) {
      _collectCallsFromExpression(stmt.expression);
    } else if (stmt is BlockStatement) {
      for (final s in stmt.statements) {
        _collectCallsFromStatement(s);
      }
    } else if (stmt is ReturnStatement) {
      if (stmt.value != null) {
        _collectCallsFromExpression(stmt.value!);
      }
    } else if (stmt is VarDecl) {
      _collectCallsFromExpression(stmt.value);
    } else if (stmt is IfStatement) {
      _collectCallsFromExpression(stmt.condition);
      _collectCallsFromStatement(stmt.consequence);
      if (stmt.alternative != null) {
        _collectCallsFromStatement(stmt.alternative!);
      }
    } else if (stmt is WhileStatement) {
      _collectCallsFromExpression(stmt.condition);
      _collectCallsFromStatement(stmt.body);
    } else if (stmt is ForStatement) {
      _collectCallsFromExpression(stmt.iterable);
      _collectCallsFromStatement(stmt.body);
    } else if (stmt is FunctionDeclaration) {
      // Collect calls inside function bodies
      _collectCallsFromStatement(stmt.body);
    }
  }

  void _collectCallsFromExpression(Expression expr) {
    if (expr is CallExpr) {
      // Direct function call: funcName(...)
      if (expr.function is Identifier) {
        _calledFunctions.add((expr.function as Identifier).value);
      }
      // Method call or nested call
      _collectCallsFromExpression(expr.function);
      for (final arg in expr.arguments) {
        _collectCallsFromExpression(arg);
        // NEW: Check if argument is a string literal that matches a function name
        if (arg is StringLiteral) {
          if (_declaredFunctions.contains(arg.value)) {
            _referencedCallbacks.add(arg.value);
          }
        }
      }
    } else if (expr is Identifier) {
      // Check if this identifier is a function reference (callback)
      if (_declaredFunctions.contains(expr.value)) {
        _referencedCallbacks.add(expr.value);
      }
    } else if (expr is BinaryExpr) {
      _collectCallsFromExpression(expr.left);
      _collectCallsFromExpression(expr.right);
    } else if (expr is UnaryExpr) {
      _collectCallsFromExpression(expr.right);
    } else if (expr is ArrayLiteral) {
      for (final elem in expr.elements) {
        _collectCallsFromExpression(elem);
      }
    } else if (expr is ObjectLiteral) {
      for (final entry in expr.pairs.entries) {
        _collectCallsFromExpression(entry.value);
        // Check for callback string references like: { onTap: "handleTap" }
        if (entry.value is StringLiteral) {
          final strValue = (entry.value as StringLiteral).value;
          if (_declaredFunctions.contains(strValue)) {
            _referencedCallbacks.add(strValue);
          }
        }
      }
    } else if (expr is FunctionLiteral) {
      _collectCallsFromStatement(expr.body);
    } else if (expr is IndexExpr) {
      _collectCallsFromExpression(expr.left);
      _collectCallsFromExpression(expr.index);
    } else if (expr is PropertyAccessExpr) {
      _collectCallsFromExpression(expr.obj);
    } else if (expr is SafeAccessExpr) {
      _collectCallsFromExpression(expr.obj);
    } else if (expr is ElvisExpr) {
      _collectCallsFromExpression(expr.left);
      _collectCallsFromExpression(expr.defaultValue);
    } else if (expr is StringTemplate) {
      for (final part in expr.parts) {
        _collectCallsFromExpression(part);
      }
    } else if (expr is Assignment) {
      _collectCallsFromExpression(expr.left);
      _collectCallsFromExpression(expr.value);
    }
  }

  /// Phase 3: Mark reachable functions using BFS from entry points
  Set<String> _markReachable() {
    final reachable = <String>{};
    final queue = <String>[];
    
    // Start with entry points
    for (final entry in entryPoints) {
      if (_declaredFunctions.contains(entry)) {
        queue.add(entry);
      }
    }
    
    // Add builder pattern functions (e.g., myBuilder referenced as string)
    for (final callback in _referencedCallbacks) {
      if (!reachable.contains(callback)) {
        queue.add(callback);
      }
    }

    // Add functions reached from top-level (module-init) statements.
    for (final root in _topLevelRoots) {
      if (_declaredFunctions.contains(root)) {
        queue.add(root);
      }
    }
    
    // BFS to find all reachable functions
    while (queue.isNotEmpty) {
      final funcName = queue.removeAt(0);
      if (reachable.contains(funcName)) continue;
      reachable.add(funcName);
      
      // Find calls within this function
      final func = _functionMap[funcName];
      if (func != null) {
        final callsInFunc = _getCallsInFunction(func);
        for (final call in callsInFunc) {
          if (_declaredFunctions.contains(call) && !reachable.contains(call)) {
            queue.add(call);
          }
        }
      }
    }
    
    return reachable;
  }

  /// Get all function calls within a function
  Set<String> _getCallsInFunction(FunctionDeclaration func) {
    final calls = <String>{};
    _collectCallsInNode(func.body, calls);
    return calls;
  }

  void _collectCallsInNode(Statement stmt, Set<String> calls) {
    if (stmt is ExpressionStatement) {
      _collectCallsInExpr(stmt.expression, calls);
    } else if (stmt is BlockStatement) {
      for (final s in stmt.statements) {
        _collectCallsInNode(s, calls);
      }
    } else if (stmt is ReturnStatement && stmt.value != null) {
      _collectCallsInExpr(stmt.value!, calls);
    } else if (stmt is VarDecl) {
      _collectCallsInExpr(stmt.value, calls);
    } else if (stmt is IfStatement) {
      _collectCallsInExpr(stmt.condition, calls);
      _collectCallsInNode(stmt.consequence, calls);
      if (stmt.alternative != null) {
        _collectCallsInNode(stmt.alternative!, calls);
      }
    } else if (stmt is WhileStatement) {
      _collectCallsInExpr(stmt.condition, calls);
      _collectCallsInNode(stmt.body, calls);
    } else if (stmt is ForStatement) {
      _collectCallsInExpr(stmt.iterable, calls);
      _collectCallsInNode(stmt.body, calls);
    }
  }

  void _collectCallsInExpr(Expression expr, Set<String> calls) {
    if (expr is CallExpr) {
      if (expr.function is Identifier) {
        calls.add((expr.function as Identifier).value);
      }
      _collectCallsInExpr(expr.function, calls);
      for (final arg in expr.arguments) {
        _collectCallsInExpr(arg, calls);
      }
    } else if (expr is Identifier) {
      if (_declaredFunctions.contains(expr.value)) {
        calls.add(expr.value);
      }
    } else if (expr is BinaryExpr) {
      _collectCallsInExpr(expr.left, calls);
      _collectCallsInExpr(expr.right, calls);
    } else if (expr is UnaryExpr) {
      _collectCallsInExpr(expr.right, calls);
    } else if (expr is ArrayLiteral) {
      for (final elem in expr.elements) {
        _collectCallsInExpr(elem, calls);
      }
    } else if (expr is ObjectLiteral) {
      for (final entry in expr.pairs.entries) {
        _collectCallsInExpr(entry.value, calls);
        if (entry.value is StringLiteral) {
          final strValue = (entry.value as StringLiteral).value;
          if (_declaredFunctions.contains(strValue)) {
            calls.add(strValue);
          }
        }
      }
    } else if (expr is FunctionLiteral) {
      _collectCallsInNode(expr.body, calls);
    } else if (expr is IndexExpr) {
      _collectCallsInExpr(expr.left, calls);
      _collectCallsInExpr(expr.index, calls);
    } else if (expr is PropertyAccessExpr) {
      _collectCallsInExpr(expr.obj, calls);
    } else if (expr is SafeAccessExpr) {
      _collectCallsInExpr(expr.obj, calls);
    } else if (expr is ElvisExpr) {
      _collectCallsInExpr(expr.left, calls);
      _collectCallsInExpr(expr.defaultValue, calls);
    } else if (expr is StringTemplate) {
      for (final part in expr.parts) {
        _collectCallsInExpr(part, calls);
      }
    } else if (expr is Assignment) {
      _collectCallsInExpr(expr.left, calls);
      _collectCallsInExpr(expr.value, calls);
    }
  }

  /// Phase 4: Filter the program to keep only reachable functions
  Program _filterProgram(Program program, Set<String> reachable) {
    final filteredStatements = <Statement>[];
    
    for (final stmt in program.statements) {
      if (stmt is FunctionDeclaration) {
        final name = stmt.name.value;
        if (reachable.contains(name)) {
          filteredStatements.add(stmt);
        }
        // Silently remove unreachable functions
      } else {
        // Keep all non-function statements (variables, expressions, etc.)
        filteredStatements.add(stmt);
      }
    }
    
    return Program(filteredStatements);
  }
  
  /// Get statistics about the shaking
  Map<String, dynamic> getStats() {
    return {
      'totalFunctions': _declaredFunctions.length,
      'calledFunctions': _calledFunctions.length,
      'referencedCallbacks': _referencedCallbacks.length,
    };
  }
}
