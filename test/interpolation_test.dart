import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('Advanced String Interpolation', () {
    test('Basic Expression', () {
      expect(KromScript.run('return "Value: \${5 + 5}"').value, 'Value: 10');
    });

    test('Variable Access', () {
      final script = '''
        let name = "Krom"
        return "Hello \${name}"
      ''';
      expect(KromScript.run(script).value, 'Hello Krom');
    });

    test('Function Call', () {
      final script = '''
        let doubleNum = (x) => x * 2
        return "Result: \${doubleNum(5)}"
      ''';
      expect(KromScript.run(script).value, 'Result: 10');
    });

    test('Nested Braces not in Strings', () {
      // should work because parser counts braces
      expect(KromScript.run('return "Obj: \${ {a:1} }"').value, contains('{a: 1}')); 
      // or whatever toString returns for ObjectLiteral (Map)
    });

    test('String inside Interpolation containing brace', () {
      // Fails if parser naive count
      final script = "return 'Quoted: \${ \"}\" }'";
      // Expect: Quoted: }
      expect(KromScript.run(script).value, 'Quoted: }');
    });

    test('Complex nested interpolation', () {
      final script = "return 'Nested: \${ \"Inner: \${1+1}\" }'";
      expect(KromScript.run(script).value, 'Nested: Inner: 2');
    });
  });
}
