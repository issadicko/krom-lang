import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/optimizer/constant_propagation.dart';

void main() {
  group('ConstantPropagation', () {
    late Lexer lexer;
    late Parser parser;
    
    Program parse(String source) {
      lexer = Lexer(source);
      parser = Parser(lexer);
      return parser.parseProgram();
    }

    test('replaces variable usages with constant values', () {
      final source = '''
fn main() {
  let x = 10
  return x
}
''';
      final program = parse(source);
      final cp = ConstantPropagation();
      final result = cp.optimize(program);
      
      final func = result.statements.first as FunctionDeclaration;
      final ret = func.body.statements[1] as ReturnStatement;
      
      expect(ret.value, isA<NumberLiteral>());
      expect((ret.value as NumberLiteral).value, equals(10));
    });

    test('folds arithmetic expressions', () {
      final source = '''
fn main() {
  let x = 10 + 20
  return x
}
''';
      final program = parse(source);
      final cp = ConstantPropagation();
      final result = cp.optimize(program);
      
      final func = result.statements.first as FunctionDeclaration;
      final decl = func.body.statements[0] as VarDecl;
      
      expect(decl.value, isA<NumberLiteral>());
      expect((decl.value as NumberLiteral).value, equals(30));
    });

    test('stops propagation on reassignment', () {
      final source = '''
fn main() {
  let x = 10
  x = 20
  return x
}
''';
      final program = parse(source);
      final cp = ConstantPropagation();
      final result = cp.optimize(program);
      
      final func = result.statements.first as FunctionDeclaration;
      final ret = func.body.statements[2] as ReturnStatement;
      
      // Should NOT be 10 because it was reassigned.
      // Should NOT be 20 because we don't track reassignment values yet (only invalidation).
      expect(ret.value, isA<Identifier>());
      expect((ret.value as Identifier).value, equals('x'));
    });

    test('does not fold a counter mutated inside a while loop', () {
      // Regression: `i` was treated as the constant 0 and folded into the loop
      // condition (`while (0 < n)` -> infinite loop) and body usages, because
      // the loop did not invalidate variables it reassigns.
      final source = '''
fn main() {
  let i = 0
  while (i < 3) {
    i = i + 1
  }
  return i
}
''';
      final program = parse(source);
      final result = ConstantPropagation().optimize(program);

      final func = result.statements.first as FunctionDeclaration;
      final whileStmt = func.body.statements[1] as WhileStatement;

      // The condition must still reference `i`, not a folded `0 < 3`.
      final cond = whileStmt.condition as BinaryExpr;
      expect(cond.left, isA<Identifier>());
      expect((cond.left as Identifier).value, equals('i'));
    });

    test('does not fold a variable mutated inside a closure', () {
      // Regression: `total` was folded to the constant 0 because CP did not
      // descend into the forEach callback that mutates it, turning
      // `return total` into `return 0` (broke sumByType / category lookups).
      final source = '''
fn sumByType(items, type) {
  let total = 0
  items.forEach(fn(t, i) { total = total + t.amount })
  return total
}
''';
      final program = parse(source);
      final result = ConstantPropagation().optimize(program);

      final func = result.statements.first as FunctionDeclaration;
      final ret = func.body.statements.last as ReturnStatement;
      expect(ret.value, isA<Identifier>());
      expect((ret.value as Identifier).value, equals('total'));
    });

    test('propagates strings', () {
      final source = '''
fn main() {
  let s = "hello" + " world"
  return s
}
''';
      final program = parse(source);
      final cp = ConstantPropagation();
      final result = cp.optimize(program);
      
      final func = result.statements.first as FunctionDeclaration;
      final decl = func.body.statements[0] as VarDecl;
      
      expect(decl.value, isA<StringLiteral>());
      expect((decl.value as StringLiteral).value, equals('hello world'));
    });
  });
}
