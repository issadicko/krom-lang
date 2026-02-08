import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/optimizer/tree_shaker.dart';
import 'package:krom_script/src/optimizer/optimizer.dart';

void main() {
  group('TreeShaker', () {
    late Lexer lexer;
    late Parser parser;
    
    Program parse(String source) {
      lexer = Lexer(source);
      parser = Parser(lexer);
      return parser.parseProgram();
    }

    test('removes unused functions', () {
      final source = '''
fn used() { return 42 }
fn unused() { return "never called" }
fn build() { return used() }
''';
      final program = parse(source);
      final shaker = TreeShaker();
      final result = shaker.shake(program);
      
      // Should have 2 functions: used and build (unused removed)
      final functions = result.statements.whereType<FunctionDeclaration>().toList();
      expect(functions.length, 2);
      expect(functions.map((f) => f.name.value).toSet(), {'used', 'build'});
    });

    test('keeps transitively called functions', () {
      final source = '''
fn a() { return 1 }
fn b() { return a() }
fn c() { return b() }
fn unused() { return 999 }
fn build() { return c() }
''';
      final program = parse(source);
      final shaker = TreeShaker();
      final result = shaker.shake(program);
      
      final functions = result.statements.whereType<FunctionDeclaration>().toList();
      expect(functions.length, 4); // a, b, c, build
      expect(functions.map((f) => f.name.value).toSet(), {'a', 'b', 'c', 'build'});
    });

    test('keeps callback functions referenced as strings', () {
      final source = '''
fn myBuilder() { return 42 }
fn unused() { return 0 }
fn build() {
  return Obx({ builder: "myBuilder" })
}
''';
      final program = parse(source);
      final shaker = TreeShaker();
      final result = shaker.shake(program);
      
      final functions = result.statements.whereType<FunctionDeclaration>().toList();
      expect(functions.length, 2); // myBuilder, build
      expect(functions.map((f) => f.name.value).toSet(), {'myBuilder', 'build'});
    });

    test('keeps all entry points', () {
      final source = '''
fn build() { return 1 }
fn main() { return 2 }
fn init() { return 3 }
fn dispose() { return 4 }
fn unused() { return 5 }
''';
      final program = parse(source);
      final shaker = TreeShaker();
      final result = shaker.shake(program);
      
      final functions = result.statements.whereType<FunctionDeclaration>().toList();
      expect(functions.length, 4);
      expect(functions.map((f) => f.name.value).toSet(), {'build', 'main', 'init', 'dispose'});
    });

    test('preserves non-function statements', () {
      final source = '''
let x = 10
fn unused() { return x }
fn build() { return x + 1 }
''';
      final program = parse(source);
      final shaker = TreeShaker();
      final result = shaker.shake(program);
      
      expect(result.statements.length, 2); // VarDecl + build
      expect(result.statements[0], isA<VarDecl>());
      expect(result.statements[1], isA<FunctionDeclaration>());
    });
  });

  group('Optimizer with TreeShaking', () {
    test('integrates tree shaking with constant folding', () {
      final source = '''
fn unused() { return 1 + 2 }
fn used() { return 3 + 4 }
fn build() { return used() + 10 + 20 }
''';
      final lexer = Lexer(source);
      final parser = Parser(lexer);
      final program = parser.parseProgram();
      
      final optimizer = Optimizer(enableTreeShaking: true);
      final result = optimizer.optimize(program);
      
      // unused should be removed, expressions should be folded
      final functions = result.statements.whereType<FunctionDeclaration>().toList();
      expect(functions.length, 2);
      expect(functions.map((f) => f.name.value).toSet(), {'used', 'build'});
    });

    test('can disable tree shaking', () {
      final source = '''
fn unused() { return 42 }
fn build() { return 1 }
''';
      final lexer = Lexer(source);
      final parser = Parser(lexer);
      final program = parser.parseProgram();
      
      final optimizer = Optimizer(enableTreeShaking: false);
      final result = optimizer.optimize(program);
      
      // Both functions should be kept
      final functions = result.statements.whereType<FunctionDeclaration>().toList();
      expect(functions.length, 2);
    });
  });
}
