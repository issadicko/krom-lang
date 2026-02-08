import '../ast/ast.dart';

/// DeadCodeElimination removes variable declarations that are never used.
/// 
/// It performs a two-pass analysis:
/// 1. Collects all variable usages.
/// 2. Removes variable declarations that are not in the usage set.
class DeadCodeElimination {
  final Set<String> _usedVariables = {};
  
  Program optimize(Program program) {
    _usedVariables.clear();
    
    // Pass 1: Collect usages
    _collectUsages(program);
    
    // Pass 2: Remove unused declarations
    return _filterProgram(program);
  }

  void _collectUsages(Node node) {
    if (node is Identifier) {
      _usedVariables.add(node.value);
    } else if (node is Program) {
      for (final stmt in node.statements) {
        if (stmt is VarDecl) {
          _collectUsages(stmt.value);
        } else {
          _collectUsages(stmt);
        }
      }
    } else if (node is BlockStatement) {
      for (final stmt in node.statements) {
        if (stmt is VarDecl) {
          _collectUsages(stmt.value);
        } else {
          _collectUsages(stmt);
        }
      }
    } else if (node is ExpressionStatement) {
      _collectUsages(node.expression);
    } else if (node is ReturnStatement) {
      if (node.value != null) _collectUsages(node.value!);
    } else if (node is IfStatement) {
      _collectUsages(node.condition);
      _collectUsages(node.consequence);
      if (node.alternative != null) _collectUsages(node.alternative!);
    } else if (node is WhileStatement) {
      _collectUsages(node.condition);
      _collectUsages(node.body);
    } else if (node is ForStatement) {
      _collectUsages(node.iterable);
      _collectUsages(node.body);
    } else if (node is FunctionDeclaration) {
      _collectUsages(node.body);
    } else if (node is Assignment) {
      _collectUsages(node.left);
      _collectUsages(node.value);
    } else if (node is BinaryExpr) {
      _collectUsages(node.left);
      _collectUsages(node.right);
    } else if (node is UnaryExpr) {
      _collectUsages(node.right);
    } else if (node is CallExpr) {
      _collectUsages(node.function);
      for (final arg in node.arguments) _collectUsages(arg);
    } else if (node is ArrayLiteral) {
      for (final elem in node.elements) _collectUsages(elem);
    } else if (node is ObjectLiteral) {
      for (final val in node.pairs.values) _collectUsages(val);
    } else if (node is IndexExpr) {
      _collectUsages(node.left);
      _collectUsages(node.index);
    } else if (node is PropertyAccessExpr) {
      _collectUsages(node.obj);
    } else if (node is SafeAccessExpr) {
      _collectUsages(node.obj);
    } else if (node is ElvisExpr) {
      _collectUsages(node.left);
      _collectUsages(node.defaultValue);
    } else if (node is StringTemplate) {
      for (final part in node.parts) _collectUsages(part);
    } else if (node is FunctionLiteral) {
        _collectUsages(node.body);
    }
  }

  Program _filterProgram(Program program) {
    final statements = <Statement>[];
    for (final stmt in program.statements) {
      final filtered = _filterStatement(stmt);
      if (filtered != null) {
        statements.add(filtered);
      }
    }
    return Program(statements);
  }
  
  Statement? _filterStatement(Statement stmt) {
    if (stmt is VarDecl) {
      if (!_usedVariables.contains(stmt.name.value)) {
        // Optimization: If value expression has side effects (function call), 
        // we should keep it as an ExpressionStatement!
        if (_hasSideEffects(stmt.value)) {
           return ExpressionStatement(stmt.token, stmt.value);
        }
        return null; // Remove entirely
      }
      return stmt;
    } else if (stmt is BlockStatement) {
      final statements = <Statement>[];
      for (final s in stmt.statements) {
        final filtered = _filterStatement(s);
        if (filtered != null) statements.add(filtered);
      }
      return BlockStatement(stmt.token, statements);
    } else if (stmt is IfStatement) {
      return IfStatement(
        stmt.token,
        stmt.condition,
        _filterStatement(stmt.consequence) as BlockStatement,
        stmt.alternative != null ? (_filterStatement(stmt.alternative!) as BlockStatement?) : null
      );
    } else if (stmt is WhileStatement) {
        return WhileStatement(
            stmt.token,
            stmt.condition,
            _filterStatement(stmt.body) as BlockStatement
        );
    } else if (stmt is ForStatement) {
        return ForStatement(
            stmt.token,
            stmt.variable,
            stmt.iterable,
            _filterStatement(stmt.body) as BlockStatement
        );
    } else if (stmt is FunctionDeclaration) {
        return FunctionDeclaration(
            stmt.token,
            stmt.name,
            stmt.parameters,
            _filterStatement(stmt.body) as BlockStatement
        );
    }
    
    return stmt;
  }
  
  bool _hasSideEffects(Expression expr) {
    // Returns true if the expression might have side effects (calls, assignments)
    if (expr is CallExpr) return true;
    if (expr is Assignment) return true;
    if (expr is BinaryExpr) return _hasSideEffects(expr.left) || _hasSideEffects(expr.right);
    if (expr is UnaryExpr) return _hasSideEffects(expr.right);
    if (expr is ArrayLiteral) return expr.elements.any(_hasSideEffects);
    if (expr is ObjectLiteral) return expr.pairs.values.any(_hasSideEffects);
    if (expr is IndexExpr) return _hasSideEffects(expr.left) || _hasSideEffects(expr.index);
    if (expr is StringTemplate) return expr.parts.any(_hasSideEffects);
    return false;
  }
}
