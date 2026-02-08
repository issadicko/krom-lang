import 'package:krom_script/src/ast/ast.dart';
import 'package:krom_script/src/lexer/lexer.dart';
import 'package:krom_script/src/optimizer/tree_shaker.dart';
import 'package:krom_script/src/parser/parser.dart';
import 'package:test/test.dart';

void main() {
  group('TreeShaker - Dynamic Callbacks', () {
    late TreeShaker treeShaker;

    setUp(() {
      treeShaker = TreeShaker();
    });

    Program parse(String source) {
      final lexer = Lexer(source);
      final parser = Parser(lexer);
      final program = parser.parseProgram();
      if (parser.errors().isNotEmpty) {
        throw Exception(parser.errors().join('\n'));
      }
      return program;
    }

    test('should keep function referenced in object literal string value', () {
      final source = '''
        fn build() {
          return Button({ onTap: "handleClick" })
        }

        fn handleClick() {
          print("Clicked")
        }
      ''';

      final program = parse(source);
      final shaken = treeShaker.shake(program);

      final funcNames = shaken.statements
          .whereType<FunctionDeclaration>()
          .map((f) => f.name.value)
          .toSet();

      expect(funcNames, contains('build'));
      expect(funcNames, contains('handleClick'), 
        reason: 'handleClick should be kept because it is referenced in "onTap" string');
    });

    test('should keep function referenced in function argument string', () {
      final source = '''
        fn build() {
          return CustomWidget("handleEvent")
        }

        fn handleEvent() {
          print("Event handled")
        }
      ''';

      final program = parse(source);
      final shaken = treeShaker.shake(program);

      final funcNames = shaken.statements
          .whereType<FunctionDeclaration>()
          .map((f) => f.name.value)
          .toSet();

      expect(funcNames, contains('build'));
      expect(funcNames, contains('handleEvent'),
          reason: 'handleEvent should be kept because it is referenced in function argument string');
    });
  });
}
