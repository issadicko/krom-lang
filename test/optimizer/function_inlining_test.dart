import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/optimizer/function_inlining.dart';

void main() {
  group('FunctionInliner', () {
    late Lexer lexer;
    late Parser parser;

    Program parse(String source) {
      lexer = Lexer(source);
      parser = Parser(lexer);
      return parser.parseProgram();
    }

    test('inlines simple function calls', () {
      final source = '''
fn add(a, b) {
  return a + b
}
fn main() {
  let x = add(1, 2)
  return x
}
''';
      final program = parse(source);
      final optimizer = FunctionInliner();
      final result = optimizer.optimize(program);

      final mainFunc = result.statements[1] as FunctionDeclaration;
      final decl = mainFunc.body.statements[0] as VarDecl;

      // Should be BinaryExpr(Num(1), +, Num(2))
      expect(decl.value, isA<BinaryExpr>());
      final bin = decl.value as BinaryExpr;
      expect(bin.operator, equals('+'));
      expect((bin.left as NumberLiteral).value, equals(1));
      expect((bin.right as NumberLiteral).value, equals(2));
    });

    test('inlines nested function calls', () {
      final source = '''
fn id(x) { return x } // 1 statement
fn main() {
  let y = id(id(5))
}
''';
      // id(5) -> 5
      // id(id(5)) -> id(5) -> 5

      final program = parse(source);
      final optimizer = FunctionInliner();
      final result = optimizer.optimize(program);

      final mainFunc = result.statements[1] as FunctionDeclaration;
      final decl = mainFunc.body.statements[0] as VarDecl;

      expect(decl.value, isA<NumberLiteral>());
      expect((decl.value as NumberLiteral).value, equals(5));
    });

    test('does not inline large functions', () {
      final source = '''
fn large() {
  let x = 1
  return x
}
fn main() {
  large()
}
''';
      // 'large' has 2 statements (VarDecl, Return), so it's not small (limit 1).
      final program = parse(source);
      final optimizer = FunctionInliner();
      final result = optimizer.optimize(program);

      final mainFunc = result.statements[1] as FunctionDeclaration;
      final stmt = mainFunc.body.statements[0] as ExpressionStatement;

      // Should still be CallExpr
      expect(stmt.expression, isA<CallExpr>());
    });

    test('does not inline a function whose return closes over a parameter', () {
      // Regression: inlining used to substitute the body but skip nested
      // function literals, leaving `kind` dangling (-> "undefined variable: kind"
      // at runtime). Such a function must be left as a call instead.
      final source = '''
fn categoriesFor(kind) {
  return xs.filter(fn(c) { return c.kind == kind })
}
fn main() {
  let r = categoriesFor("expense")
  return r
}
''';
      final program = parse(source);
      final result = FunctionInliner().optimize(program);

      final mainFunc = result.statements[1] as FunctionDeclaration;
      final decl = mainFunc.body.statements[0] as VarDecl;

      // Must remain a call to categoriesFor — not inlined.
      expect(decl.value, isA<CallExpr>());
      expect(((decl.value as CallExpr).function as Identifier).value,
          equals('categoriesFor'));
    });

    test('does not inline when a side-effecting arg would be duplicated', () {
      // double(x) uses x twice; inlining double(makeVal()) would run makeVal()
      // twice instead of once. makeVal is multi-statement so it is itself not
      // inlinable (stays a real call). The double() call must be left intact.
      final source = '''
fn makeVal() { let v = 1 return v }
fn double(x) { return x + x }
fn main() {
  let r = double(makeVal())
  return r
}
''';
      final program = parse(source);
      final result = FunctionInliner().optimize(program);

      final mainFunc = result.statements[2] as FunctionDeclaration;
      final decl = mainFunc.body.statements[0] as VarDecl;
      expect(decl.value, isA<CallExpr>());
      expect(((decl.value as CallExpr).function as Identifier).value,
          equals('double'));
    });
  });
}
