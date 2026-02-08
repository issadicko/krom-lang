import '../ast/ast.dart';
import '../token/token.dart';

/// ASTPrinter converts an AST back into KromScript source code.
class ASTPrinter {
  final StringBuffer _buffer = StringBuffer();
  int _indentation = 0;

  // Operator precedence levels mirroring Parser
  static const int _lowest = 1;
  static const int _assign = 2;
  static const int _elvis = 3;
  static const int _or = 4;
  static const int _and = 5;
  static const int _equals = 6;
  static const int _lessGreater = 7;
  static const int _sum = 8;
  static const int _product = 9;
  static const int _prefix = 10;
  static const int _call = 11;
  static const int _access = 12;

  static int _getPrecedence(String operator) {
    switch (operator) {
      case '=': return _assign;
      case '?:': return _elvis;
      case '||': return _or;
      case '&&': return _and;
      case '==': 
      case '!=': return _equals;
      case '<':
      case '>':
      case '<=':
      case '>=': return _lessGreater;
      case '+':
      case '-': return _sum;
      case '*':
      case '/':
      case '%': return _product;
      case '.':
      case '?.': return _access;
      default: return _lowest;
    }
  }

  String print(Program program) {
    _buffer.clear();
    for (final stmt in program.statements) {
      _printStatement(stmt);
      _buffer.writeln(); // Newline after each top-level statement
    }
    return _buffer.toString().trim() + '\n';
  }

  void _printStatement(Statement stmt) {
    if (stmt is FunctionDeclaration) {
      _write('fn ${stmt.name.value}(');
      _write(stmt.parameters.map((p) => p.value).join(', '));
      _write(') ');
      _printBlock(stmt.body);
    } else if (stmt is VarDecl) {
      _write('let ${stmt.name.value} = ');
      _printExpression(stmt.value);
    } else if (stmt is ExpressionStatement) {
      _printExpression(stmt.expression);
    } else if (stmt is BlockStatement) {
      _printBlock(stmt);
    } else if (stmt is ReturnStatement) {
      _write('return');
      if (stmt.value != null) {
        _write(' ');
        _printExpression(stmt.value!);
      }
    } else if (stmt is IfStatement) {
      _write('if (');
      _printExpression(stmt.condition);
      _write(') ');
      _printBlock(stmt.consequence);
      if (stmt.alternative != null) {
        _write(' else ');
        if (stmt.alternative!.statements.length == 1 && 
            stmt.alternative!.statements.first is IfStatement) {
          // Else if
          _printStatement(stmt.alternative!.statements.first);
        } else {
          _printBlock(stmt.alternative!);
        }
      }
    } else if (stmt is WhileStatement) {
      _write('while (');
      _printExpression(stmt.condition);
      _write(') ');
      _printBlock(stmt.body);
    } else if (stmt is ForStatement) {
      _write('for (${stmt.variable.value} in ');
      _printExpression(stmt.iterable);
      _write(') ');
      _printBlock(stmt.body);
    }
  }

  void _printBlock(BlockStatement block) {
    _writeln('{');
    _indent();
    for (final stmt in block.statements) {
      _writeIndent();
      _printStatement(stmt);
      _writeln('');
    }
    _outdent();
    _writeIndent();
    _write('}');
  }

  void _printExpression(Expression expr) {
    if (expr is BinaryExpr) {
      final parentPrec = _getPrecedence(expr.operator);
      
      // Handle Left Child
      bool leftParens = false;
      if (expr.left is BinaryExpr) {
        final leftPrec = _getPrecedence((expr.left as BinaryExpr).operator);
        if (leftPrec < parentPrec) {
          leftParens = true;
        }
      }
      
      if (leftParens) _write('(');
      _printExpression(expr.left);
      if (leftParens) _write(')');

      _write(' ${expr.operator} ');

      // Handle Right Child
      bool rightParens = false;
      if (expr.right is BinaryExpr) {
        final rightPrec = _getPrecedence((expr.right as BinaryExpr).operator);
        // If precedence is lower, OR EQUAL (to handle left-associativity), wrap in parens
        // e.g. 10 / (2 * 5) -> / is same prec as *, but needs parens
        if (rightPrec <= parentPrec) {
          rightParens = true;
        }
      }
      
      if (rightParens) _write('(');
      _printExpression(expr.right);
      if (rightParens) _write(')');

    } else if (expr is UnaryExpr) {
      _write(expr.operator);
      // If the operand is a binary expression, it might need parens
      // e.g. -(a + b)
      bool needsParens = false;
      if (expr.right is BinaryExpr) {
        needsParens = true;
      }
      
      if (needsParens) _write('(');
      _printExpression(expr.right);
      if (needsParens) _write(')');
      
    } else if (expr is Identifier) {
      _write(expr.value);
    } else if (expr is NumberLiteral) {
      // Print as integer if it's a whole number for cleaner output
      if (expr.value == expr.value.toInt()) {
         _write(expr.value.toInt().toString());
      } else {
         _write(expr.value.toString());
      }
    } else if (expr is StringLiteral) {
      _write('"${expr.value.replaceAll('"', r'\"')}"');
    } else if (expr is BooleanLiteral) {
      _write(expr.value.toString());
    } else if (expr is NullLiteral) {
      _write('nil');
    } else if (expr is ArrayLiteral) {
      _write('[');
      for (var i = 0; i < expr.elements.length; i++) {
        if (i > 0) _write(', ');
        _printExpression(expr.elements[i]);
      }
      _write(']');
    } else if (expr is ObjectLiteral) {
      _write('{');
      if (expr.pairs.isNotEmpty) {
        final entries = expr.pairs.entries.toList();
        // Check if object is simple enough to print on one line
        bool simple = entries.length <= 3 && entries.every((e) => e.value is! ObjectLiteral && e.value is! FunctionLiteral);
        
        if (!simple) {
            _writeln('');
            _indent();
            for (var i = 0; i < entries.length; i++) {
                if (i > 0) _writeln(',');
                _writeIndent();
                _write(entries[i].key);
                _write(': ');
                _printExpression(entries[i].value);
            }
            _writeln('');
            _outdent();
            _writeIndent();
        } else {
             _write(' ');
             for (var i = 0; i < entries.length; i++) {
                if (i > 0) _write(', ');
                _write('${entries[i].key}: ');
                _printExpression(entries[i].value);
             }
             _write(' ');
        }
      }
      _write('}');
    } else if (expr is FunctionLiteral) {
      _write('fn(');
      _write(expr.parameters.map((p) => p.value).join(', '));
      _write(') ');
      _printBlock(expr.body);
    } else if (expr is CallExpr) {
      _printExpression(expr.function);
      _write('(');
      for (var i = 0; i < expr.arguments.length; i++) {
        if (i > 0) _write(', ');
        _printExpression(expr.arguments[i]);
      }
      _write(')');
    } else if (expr is IndexExpr) {
      _printExpression(expr.left);
      _write('[');
      _printExpression(expr.index);
      _write(']');
    } else if (expr is PropertyAccessExpr) {
      _printExpression(expr.obj);
      _write('.');
      _write(expr.property.value);
    } else if (expr is SafeAccessExpr) {
      _printExpression(expr.obj);
      _write('?.');
      _write(expr.property.value);
    } else if (expr is ElvisExpr) {
      _printExpression(expr.left);
      _write(' ?: ');
      _printExpression(expr.defaultValue);
    } else if (expr is Assignment) {
      _printExpression(expr.left);
      _write(' = ');
      _printExpression(expr.value);
    } else if (expr is StringTemplate) {
        _write('"'); // Reconstructing simplified template (could be complex)
        for (var part in expr.parts) {
            if (part is StringLiteral) {
                _write(part.value);
            } else {
                _write('\${');
                _printExpression(part);
                _write('}');
            }
        }
        _write('"');
    }
  }

  void _write(String text) {
    _buffer.write(text);
  }

  void _writeln(String text) {
    _buffer.writeln(text);
  }

  void _writeIndent() {
    _buffer.write('  ' * _indentation);
  }

  void _indent() {
    _indentation++;
  }

  void _outdent() {
    _indentation--;
  }
}
