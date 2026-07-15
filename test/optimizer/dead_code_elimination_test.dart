import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/optimizer/dead_code_elimination.dart';

void main() {
  group('DeadCodeElimination', () {
    late Lexer lexer;
    late Parser parser;

    Program parse(String source) {
      lexer = Lexer(source);
      parser = Parser(lexer);
      return parser.parseProgram();
    }

    test('removes unused local variables', () {
      final source = '''
fn main() {
  let unused = 10
  let used = 20
  return used
}
''';
      final program = parse(source);
      final dce = DeadCodeElimination();
      final result = dce.optimize(program);

      final func = result.statements.first as FunctionDeclaration;
      expect(func.body.statements.length, 2); // let used, return
      expect(func.body.statements[0], isA<VarDecl>());
      expect((func.body.statements[0] as VarDecl).name.value, equals('used'));
    });

    test('removes unused global variables', () {
      final source = '''
let unused = "ghost"
let used = "hero"
fn main() {
  return used
}
''';
      final program = parse(source);
      final dce = DeadCodeElimination();
      final result = dce.optimize(program);

      final vars = result.statements.whereType<VarDecl>().toList();
      expect(vars.length, 1);
      expect(vars[0].name.value, equals('used'));
    });

    test('preserves variables used in nested blocks', () {
      final source = '''
fn main() {
  let x = 10
  if (true) {
    return x
  }
}
''';
      final program = parse(source);
      final dce = DeadCodeElimination();
      final result = dce.optimize(program);

      final func = result.statements.first as FunctionDeclaration;
      expect(func.body.statements.length, 2); // let x, if
    });

    test('preserves declarations with side-effects', () {
      final source = '''
fn sideEffect() { return 1 }
fn main() {
  let unused = sideEffect()
  return 0
}
''';
      final program = parse(source);
      final dce = DeadCodeElimination();
      final result = dce.optimize(program);

      final func = result.statements.last as FunctionDeclaration; // main
      // Should behave become ExpressionStatement(CallExpr) instead of VarDecl
      expect(func.body.statements[0], isA<ExpressionStatement>());
      final exprStmt = func.body.statements[0] as ExpressionStatement;
      expect(exprStmt.expression, isA<CallExpr>());
    });

    test('preserves an unused property-access read (reactive subscribe)', () {
      // `let v = tick.value` exists only to subscribe the surrounding Obx; v is
      // unused but the READ must survive DCE (kept as an ExpressionStatement),
      // otherwise the page stops reacting. Regression for property access being
      // treated as side-effect-free.
      final source = '''
fn content() {
  let v = tick.value
  return "ok"
}
''';
      final program = parse(source);
      final result = DeadCodeElimination().optimize(program);

      final func = result.statements.first as FunctionDeclaration;
      expect(func.body.statements[0], isA<ExpressionStatement>());
      expect((func.body.statements[0] as ExpressionStatement).expression,
          isA<PropertyAccessExpr>());
    });

    test('handles complex usage patterns', () {
      final source = '''
fn main() {
  let a = 1
  let b = 2
  let c = a + 1 // a is used
  // b is unused
  // c is unused but depends on a
  // In single pass, c might be marked unused.
  // But a depends on c? No.
  // If c is removed, its value (a+1) is an expression.
  // a+1 has no side effects, so it should be removed clean.
  // BUT: a is used in c's value. 
  // If c's decl is removed, a is still "used" by the collected usages?
  // Current implementation collects ALL usages first.
  // So 'a' is used in 'c's definition.
  // Even if 'c' is removed, 'a' remains 'used'.
  // Ideally DCE should be iterative until fixpoint.
  return 0
}
''';
      // NOTE: Current implementation is single-pass.
      // Multi-pass would remove c, then b, then a.
      // This test expects single-pass behavior for now.

      final program = parse(source);
      final dce = DeadCodeElimination();
      final result = dce.optimize(program);

      final func = result.statements.first as FunctionDeclaration;
      // a is used (by c), b is unused.
      // c is unused. c's value has no side effect.
      // So c removed. b removed.
      // a is kept because it was "used" in c's init expression.

      final varNames = func.body.statements
          .whereType<VarDecl>()
          .map((v) => v.name.value)
          .toSet();

      expect(varNames, contains('a')); // Kept because used in c
      expect(varNames, isNot(contains('b'))); // Removed
      expect(varNames, isNot(contains('c'))); // Removed
    });
  });
}
