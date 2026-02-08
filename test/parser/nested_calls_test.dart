import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('Parser - Nested function calls with array arguments', () {
    test('should parse function call with object and function call as args', () {
      final source = '''
let result = Outer({ a: 1 }, Inner({ b: 2 }, [1, 2, 3]))
''';
      final lexer = Lexer(source);
      final parser = Parser(lexer);
      final program = parser.parseProgram();
      
      if (parser.errors().isNotEmpty) {
        print('Errors: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
      expect(program.statements.length, 1);
    });

    test('should parse nested function calls inside an array', () {
      final source = '''
let result = Container([
  Inner({ a: 1 }, [
    Item("one"),
    Item("two")
  ])
])
''';
      final lexer = Lexer(source);
      final parser = Parser(lexer);
      final program = parser.parseProgram();
      
      if (parser.errors().isNotEmpty) {
        print('Errors: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });

    test('should parse ScrollView pattern from home.ks', () {
      final source = '''
fn build() {
  return Column([
    Box({ a: 1 }),
    ScrollView({ direction: "horizontal" }, 
      Row({ spacing: 16 }, [
        Item("one"),
        Item("two")
      ])
    ),
    Box({ b: 2 })
  ])
}
''';
      final lexer = Lexer(source);
      final parser = Parser(lexer);
      final program = parser.parseProgram();
      
      if (parser.errors().isNotEmpty) {
        print('Errors: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
    });

    test('should parse exact problematic pattern', () {
      // This is the exact pattern from home.ks that fails
      final source = '''
fn build() {
  return Scaffold(
    Column({ padding: 16, spacing: 16 }, [
      Box({ padding: 24 }, 
        Column({ spacing: 8 }, [
          Text("title"),
          Text("content")
        ])
      ),
      ScrollView({ direction: "horizontal", padding: 0.1 }, 
        Row({ spacing: 16 }, [
          QuickAction("one"),
          QuickAction("two"),
          QuickAction("three")
        ])
      ),
      Text("more content"),
      Obx({ builder: "test" })
    ])
  )
}
''';
      final lexer = Lexer(source);
      final parser = Parser(lexer);
      final program = parser.parseProgram();
      
      if (parser.errors().isNotEmpty) {
        print('Errors: ${parser.errors()}');
      }
      expect(parser.errors(), isEmpty);
      expect(program.statements.length, 1);
    });
  });
}
