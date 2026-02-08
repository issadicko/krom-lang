import '../ast/ast.dart';

/// NameMangler shortens variable names to reduce code size.
/// 
/// It renames local variables to 'a', 'b', 'c', etc.
/// It preserves:
/// - Global variables (entry points)
/// - Property names (object keys)
/// - String literals
class NameMangler {
  final _nameGenerator = _NameGenerator();
  
  // Stack of scopes, each mapping original name -> mangled name
  final List<Map<String, String>> _scopeStack = [{}];
  
  Program optimize(Program program) {
    _scopeStack.clear();
    _scopeStack.add({}); // Global scope
    _nameGenerator.reset();
    
    // We don't mangle top-level declarations (globals) by default 
    // to preserve public API / entry points.
    // So we just map them continuously to themselves or skip them.
    // For now, let's skip mangling globals but record them to avoid collisions.
    
    for (final stmt in program.statements) {
       if (stmt is VarDecl) {
         _scopeStack.last[stmt.name.value] = stmt.name.value;
       } else if (stmt is FunctionDeclaration) {
         _scopeStack.last[stmt.name.value] = stmt.name.value;
       }
    }
    
    final optimizedStatements = <Statement>[];
    for (final stmt in program.statements) {
      optimizedStatements.add(_mangleStatement(stmt));
    }
    return Program(optimizedStatements);
  }
  
  void _enterScope() {
    _scopeStack.add({});
  }
  
  void _exitScope() {
    _scopeStack.removeLast();
  }
  
  String _mangleName(String original, {bool isDecl = false}) {
    if (isDecl) {
      // New declaration: Don't check parent scopes, always generate new or check current scope only.
      // If we support re-declaration in same scope (e.g. var x; var x), we might verify.
      // But for mangling, we just want a new name.
      // Actually, we should check if we already mangled it IN THIS SCOPE (e.g. multiple VarDecl in same block?)
      // Krom/JS allows 'var x' multiple times, but 'let' only once. 
      // Assuming clean AST, we should probably generate a new name for the shadowing variable.
      
      final newName = _nameGenerator.next();
      _scopeStack.last[original] = newName;
      return newName;
    }

    // Usage: Check if mangled in current or parent scope
    for (var i = _scopeStack.length - 1; i >= 0; i--) {
      if (_scopeStack[i].containsKey(original)) {
        return _scopeStack[i][original]!;
      }
    }
    
    // Usage of unknown variable (maybe global or import), keep as is
    return original;
  }
  
  Statement _mangleStatement(Statement stmt) {
    if (stmt is FunctionDeclaration) {
      // Function name is already handled in scope (global usually)
      final name = _mangleIdentifier(stmt.name); // Usually keeps original for global
      
      _enterScope();
      // Mangle parameters
      final newParams = <Identifier>[];
      for (final param in stmt.parameters) {
        final newParamName = _mangleName(param.value, isDecl: true);
        newParams.add(Identifier(param.token, newParamName));
      }
      
      final newBody = _mangleStatement(stmt.body) as BlockStatement;
      _exitScope();
      
      return FunctionDeclaration(stmt.token, name, newParams, newBody);
      
    } else if (stmt is VarDecl) {
      // Check scope depth. If > 1, it's local.
      bool isLocal = _scopeStack.length > 1;
      
      String newName;
      if (isLocal) {
        newName = _mangleName(stmt.name.value, isDecl: true);
      } else {
        // Global, keep original
        newName = stmt.name.value;
      }
      
      final newValue = _mangleExpression(stmt.value);
      return VarDecl(stmt.token, Identifier(stmt.name.token, newName), newValue);
      
    } else if (stmt is BlockStatement) {
      // Blocks don't always create new variable scope in JS/Krom 
      // depending on implementation (let is block scoped).
      // Assuming 'let' semantics (block scoped).
      _enterScope();
      final newStmts = stmt.statements.map(_mangleStatement).toList();
      _exitScope();
      return BlockStatement(stmt.token, newStmts);
      
    } else if (stmt is ExpressionStatement) {
      return ExpressionStatement(stmt.token, _mangleExpression(stmt.expression));
    } else if (stmt is ReturnStatement) {
      return ReturnStatement(stmt.token, stmt.value != null ? _mangleExpression(stmt.value!) : null);
    } else if (stmt is IfStatement) {
      return IfStatement(
        stmt.token,
        _mangleExpression(stmt.condition),
        _mangleStatement(stmt.consequence) as BlockStatement,
        stmt.alternative != null ? (_mangleStatement(stmt.alternative!) as BlockStatement) : null
      );
    } else if (stmt is WhileStatement) {
      return WhileStatement(
        stmt.token,
        _mangleExpression(stmt.condition),
        _mangleStatement(stmt.body) as BlockStatement
      );
    } else if (stmt is ForStatement) {
      _enterScope();
      final newVarName = _mangleName(stmt.variable.value, isDecl: true);
      final newIterable = _mangleExpression(stmt.iterable);
      final newBody = _mangleStatement(stmt.body) as BlockStatement;
      _exitScope();
      return ForStatement(stmt.token, Identifier(stmt.variable.token, newVarName), newIterable, newBody);
    }
    
    return stmt;
  }
  
  Expression _mangleExpression(Expression expr) {
    if (expr is Identifier) {
      return _mangleIdentifier(expr);
    } else if (expr is BinaryExpr) {
      return BinaryExpr(expr.token, _mangleExpression(expr.left), expr.operator, _mangleExpression(expr.right));
    } else if (expr is UnaryExpr) {
      return UnaryExpr(expr.token, expr.operator, _mangleExpression(expr.right));
    } else if (expr is CallExpr) {
      return CallExpr(
        expr.token, 
        _mangleExpression(expr.function), 
        expr.arguments.map(_mangleExpression).toList()
      );
    } else if (expr is Assignment) {
      return Assignment(expr.token, _mangleExpression(expr.left), _mangleExpression(expr.value));
    } else if (expr is ArrayLiteral) {
      return ArrayLiteral(expr.token, expr.elements.map(_mangleExpression).toList());
    } else if (expr is ObjectLiteral) {
      // Keys are NOT mangled, values are.
      final newPairs = <String, Expression>{};
      expr.pairs.forEach((key, val) {
        newPairs[key] = _mangleExpression(val);
      });
      return ObjectLiteral(expr.token, newPairs);
    } else if (expr is IndexExpr) {
      return IndexExpr(expr.token, _mangleExpression(expr.left), _mangleExpression(expr.index));
    } else if (expr is PropertyAccessExpr) {
      return PropertyAccessExpr(expr.token, _mangleExpression(expr.obj), expr.property);
    } else if (expr is SafeAccessExpr) {
      return SafeAccessExpr(expr.token, _mangleExpression(expr.obj), expr.property);
    } else if (expr is ElvisExpr) {
      return ElvisExpr(expr.token, _mangleExpression(expr.left), _mangleExpression(expr.defaultValue));
    } else if (expr is StringTemplate) {
      return StringTemplate(expr.token, expr.parts.map(_mangleExpression).toList());
    } else if (expr is FunctionLiteral) {
      _enterScope();
      final newParams = expr.parameters.map((p) => Identifier(p.token, _mangleName(p.value, isDecl: true))).toList();
      final newBody = _mangleStatement(expr.body) as BlockStatement;
      _exitScope();
      return FunctionLiteral(expr.token, newParams, newBody);
    }
    
    return expr;
  }
  
  Identifier _mangleIdentifier(Identifier id) {
     final newName = _mangleName(id.value);
     return Identifier(id.token, newName);
  }
}

class _NameGenerator {
  final String _chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  int _counter = 0;
  
  void reset() => _counter = 0;
  
  String next() {
    var name = '';
    var n = _counter;
    
    do {
      name = _chars[n % _chars.length] + name;
      n = (n / _chars.length).floor() - 1;
    } while (n >= 0);
    
    _counter++;
    return name;
  }
}
