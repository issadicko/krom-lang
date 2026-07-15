import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('Arrow Functions', () {
    test('Basic arrow function (param) => expr', () {
      final script = '''
        let doubleNum = (x) => x * 2
        return doubleNum(5)
      ''';
      final result = KromScript.run(script);
      expect(result.errors, isEmpty);
      expect(result.value, 10.0);
    });

    test('Arrow function with multiple params (a, b) => expr', () {
      final script = '''
        let add = (a, b) => a + b
        return add(3, 4)
      ''';
      final result = KromScript.run(script);
      expect(result.errors, isEmpty);
      expect(result.value, 7.0);
    });

    test('Arrow function with no params () => expr', () {
      final script = '''
        let getNum = () => 42
        return getNum()
      ''';
      final result = KromScript.run(script);
      expect(result.errors, isEmpty);
      expect(result.value, 42.0);
    });

    test('Arrow function as callback in map()', () {
      final script = '''
        let list = [1, 2, 3]
        let doubled = list.map((x) => x * 2)
        return doubled
      ''';
      final result = KromScript.run(script);
      expect(result.errors, isEmpty);
      expect(result.value, [2.0, 4.0, 6.0]);
    });

    test('Nested arrow functions', () {
      final script = '''
        let addCurry = (a) => (b) => a + b
        return addCurry(3)(4)
      ''';
      final result = KromScript.run(script);
      expect(result.errors, isEmpty);
      expect(result.value, 7.0);
    });

    test('Arrow function with object literal needs grouping or handling?', () {
      // In JS, x => ({a:1}) requires parens.
      // In Krom, {a:1} starts block?
      // Let's check Parser: function body is Expression.
      // Parser parses expression.
      // Object literal {a:1} is Expression.
      // BlockStatement { return 1; } is NOT Expression.

      // Krom allows object literal as expression.
      // But block statement starts with {.
      // Does parser distinguish?
      // Token lbrace triggers ObjectLiteral in prefix position.
      // So (x) => {a:1} parses {a:1} as ObjectLiteral and returns it.
      // BlockStatement is parsed via Statement parsing logic, NOT expression.
      // So arrow body IS expression. If it starts with {, it is object literal!
      // So (x) => { ... } is always object literal in expression context?
      // Wait, `_parseExpression` parses ObjectLiteral.
      // BlockStatement is NOT an expression in Krom (it's a statement).
      // So curly braces for block body are NOT supported with `=>` syntax in this implementation?
      // My implementation: `_parseArrowFunctionBody` calls `_parseExpression`.
      // So `=> { ... }` will be parsed as ObjectLiteral.
      // If user wants block body for arrow function, they should use `fn(...) { ... }` or support block in arrow?
      // Arrow functions usually support block if `{` follows.
      // But here I implemented `Expression` body only.
      // If I want block, I need to check if `{` follows and if it's block or object.
      // Ambiguity in JS: `x => { return x; }` vs `x => { key: val }`.
      // JS defaults to Block.
      // If I want object literal, I must wrap in parens `x => ({key: val})`.

      // In Krom:
      // `_parseExpression` sees `{`. It calls `_parseObjectLiteral`.
      // So `=> { return 1; }` fails because `return` is not valid key in object literal.
      // So currently my implementation supports EXPRESSION ONLY.

      final script = '''
         let getObj = (x) => { x: x * 2 }
         return getObj(5).x
       ''';
      final result = KromScript.run(script);
      expect(result.errors, isEmpty);
      expect(result.value, 10.0);
    });
  });
}
