import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('Parser - Exact ]), pattern reproduction', () {
    test('should parse ScrollView with Row containing array, followed by comma',
        () {
      // This is the EXACT pattern that fails - note the ]), at the end!
      final source = '''
fn build() {
  return Column({ spacing: 16 }, [
    Box({ a: 1 }),
    ScrollView({ direction: "horizontal" }, 
      Row({ spacing: 16 }, [
        QuickAction("cart", "Achats"),
        QuickAction("home", "Maison")
      ])
    ),
    Text("done")
  ])
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();

      if (parser.errors().isNotEmpty) {
        print('ERRORS: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });

    test('should parse simpler version with ]), pattern', () {
      // Simpler reproduction
      final source = '''
fn test() {
  return Outer([
    Inner(Child([A(), B()])),
    Other()
  ])
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();

      if (parser.errors().isNotEmpty) {
        print('ERRORS: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });

    test(
        'should parse function call with object and function as args, inside array',
        () {
      // Pattern: FuncA(obj, FuncB(obj, [items])), another
      final source = '''
fn test() {
  return Parent([
    FuncA({ a: 1 }, FuncB({ b: 2 }, [Item1(), Item2()])),
    FuncC()
  ])
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();

      if (parser.errors().isNotEmpty) {
        print('ERRORS: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });

    test('should parse three-level deep nesting with ]), pattern', () {
      // Pattern: A(B(C([items]))), more
      final source = '''
fn test() {
  return Wrap([
    A({ x: 1 }, 
      B({ y: 2 }, [
        C("a"),
        C("b")
      ])
    ),
    D()
  ])
}
''';
      final parser = Parser(Lexer(source));
      parser.parseProgram();

      if (parser.errors().isNotEmpty) {
        print('ERRORS: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });
  });
}
