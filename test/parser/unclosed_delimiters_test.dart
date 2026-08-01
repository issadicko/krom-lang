import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

List<String> errorsFor(String source) {
  final parser = Parser(Lexer(source));
  parser.parseProgram();
  return parser.errors();
}

void main() {
  group('Lexer - unterminated string literals', () {
    test('reports a double-quoted string that never closes', () {
      expect(
        errorsFor('let x = "unterminated'),
        ['SyntaxError: unterminated string literal at line 1:9'],
      );
    });

    test('reports a single-quoted string that never closes', () {
      expect(
        errorsFor("let x = 'unterminated"),
        ['SyntaxError: unterminated string literal at line 1:9'],
      );
    });

    test('an escaped quote does not terminate the literal', () {
      // The trailing \" is an escaped quote, not the closing delimiter.
      expect(
        errorsFor(r'let x = "abc\"'),
        ['SyntaxError: unterminated string literal at line 1:9'],
      );
      expect(
        errorsFor(r"let x = 'abc\'"),
        ['SyntaxError: unterminated string literal at line 1:9'],
      );
    });

    test('reports the position of the opening quote, not of the EOF', () {
      final source = '''
let a = 1
let b = "oops
''';
      expect(
        errorsFor(source),
        contains('SyntaxError: unterminated string literal at line 2:9'),
      );
    });

    test('reports an unterminated string inside a block', () {
      expect(
        errorsFor('fn f() { return "oops }'),
        contains('SyntaxError: unterminated string literal at line 1:17'),
      );
    });

    test('reports an unterminated interpolated string', () {
      expect(
        errorsFor(r'let x = "hello ${name}'),
        contains('SyntaxError: unterminated string literal at line 1:9'),
      );
    });

    test('surfaces through the public KromScript entry point', () {
      final result = KromScript.run('let x = "oops');
      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('unterminated string literal'));
    });
  });

  group('Parser - unclosed blocks', () {
    test('reports a top-level block that reaches EOF', () {
      expect(
        errorsFor('if (a) { b'),
        [
          'SyntaxError: expected TokenType.rbrace, got TokenType.eof at line 1:11'
        ],
      );
    });

    test('reports an unclosed function body', () {
      expect(
        errorsFor('fn f() { return 1'),
        [
          'SyntaxError: expected TokenType.rbrace, got TokenType.eof at line 1:18'
        ],
      );
    });

    test('reports an empty block that reaches EOF', () {
      expect(
        errorsFor('while (a) {'),
        [
          'SyntaxError: expected TokenType.rbrace, got TokenType.eof at line 1:12'
        ],
      );
    });

    test('reports the missing brace once when the body ends on a separator',
        () {
      expect(
        errorsFor('if (a) { b;'),
        [
          'SyntaxError: expected TokenType.rbrace, got TokenType.eof at line 1:12'
        ],
      );
    });

    test('reports a nested block left open by its enclosing block', () {
      final source = '''
fn f() {
  if (a) {
    b
  }
''';
      expect(
        errorsFor(source),
        contains('SyntaxError: expected TokenType.rbrace, got TokenType.eof '
            'at line 5:1'),
      );
    });

    test('reports an inner block that reaches EOF', () {
      final source = '''
fn f() {
  if (a) {
    b
''';
      expect(errorsFor(source), isNotEmpty);
      expect(
        errorsFor(source).first,
        contains('expected TokenType.rbrace, got TokenType.eof'),
      );
    });

    test('reports an unclosed else block', () {
      expect(
        errorsFor('if (a) { b } else { c'),
        [
          'SyntaxError: expected TokenType.rbrace, got TokenType.eof at line 1:22'
        ],
      );
    });

    test('surfaces through the public KromScript entry point', () {
      final result = KromScript.run('if (true) { print("hi")');
      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('expected TokenType.rbrace'));
    });
  });

  group('Regression - well-formed sources still parse', () {
    test('closed strings in both quote styles', () {
      expect(errorsFor('let a = "ok"\nlet b = \'ok\''), isEmpty);
    });

    test('strings containing escaped quotes', () {
      expect(errorsFor(r'let a = "he said \"hi\""'), isEmpty);
      expect(errorsFor(r"let a = 'it\'s ok'"), isEmpty);
    });

    test('string interpolation', () {
      expect(
          errorsFor(r'let n = "world"' '\n' r'let a = "hello ${n}"'), isEmpty);
    });

    test('an empty string literal', () {
      expect(errorsFor('let a = ""'), isEmpty);
    });

    test('nested and empty blocks', () {
      final source = '''
fn f(a) {
  if (a) {
    while (a) {
    }
  } else {
    return 0
  }
  return 1
}
''';
      expect(errorsFor(source), isEmpty);
    });

    test('object literals are not mistaken for blocks', () {
      expect(errorsFor('let o = { a: 1, b: { c: 2 } }'), isEmpty);
    });

    test('a string containing braces does not open a block', () {
      expect(errorsFor('let a = "{"\nlet b = "}"'), isEmpty);
    });
  });

  group('Regression - existing delimiter errors are unchanged', () {
    test('unclosed call parenthesis', () {
      expect(
        errorsFor('f(1, 2'),
        [
          'SyntaxError: expected TokenType.rparen, got TokenType.eof at line 1:7'
        ],
      );
    });

    test('unclosed array bracket', () {
      expect(
        errorsFor('[1, 2'),
        [
          'SyntaxError: expected TokenType.rbracket, got TokenType.eof at line 1:6'
        ],
      );
    });
  });
}
