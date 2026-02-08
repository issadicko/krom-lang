import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('Parser - Minimal ScrollView reproduction', () {
    test('should parse simple nested function call inside array', () {
      // Simplest case - function call as array element
      final source = '''
let x = [Foo()]
''';
      expect(Parser(Lexer(source)).parseProgram(), isNotNull);
      expect(Parser(Lexer(source)).errors(), isEmpty);
    });

    test('should parse function call with 2 args where second is function call', () {
      // Two args: object and function call
      final source = '''
let x = Outer({a: 1}, Inner())
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();
      print('Errors: ${parser.errors()}');
      expect(parser.errors(), isEmpty);
    });

    test('should parse function call with 2 args inside array', () {
      // ScrollView pattern: function call with 2 args inside array
      final source = '''
let x = [
  Outer({a: 1}, Inner())
]
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();
      print('Errors: ${parser.errors()}');
      expect(parser.errors(), isEmpty);
    });

    test('should parse function call with 2 args inside array followed by comma', () {
      // The ACTUAL failing pattern
      final source = '''
let x = [
  Outer({a: 1}, Inner()),
  Foo()
]
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();
      print('Errors: ${parser.errors()}');
      expect(parser.errors(), isEmpty);
    });

    test('should parse function call where Inner has array arg', () {
      // Adding complexity: Inner has an array argument
      final source = '''
let x = [
  Outer({a: 1}, Inner([1, 2, 3])),
  Foo()
]
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();
      print('Errors: ${parser.errors()}');
      expect(parser.errors(), isEmpty);
    });

    test('should parse multiline function call with array arg inside array', () {
      // Multi-line variant - this is closer to the actual home.ks pattern
      final source = '''
let x = [
  Outer({a: 1}, 
    Inner([
      Item(1),
      Item(2)
    ])
  ),
  Foo()
]
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();
      print('Errors: ${parser.errors()}');
      expect(parser.errors(), isEmpty);
    });

    test('should parse exact ScrollView pattern from home.ks', () {
      // EXACT pattern from home.ks line 39-47
      final source = '''
fn build() {
  return Column([
    Box({ a: 1 }),
    ScrollView({ direction: "horizontal", padding: 0.1 }, 
      Row({ spacing: 16 }, [
        QuickAction("cart"),
        QuickAction("home")
      ])
    ),
    Text("more")
  ])
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();
      print('Errors: ${parser.errors()}');
      expect(parser.errors(), isEmpty);
    });
  });
}
