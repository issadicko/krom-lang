import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/optimizer/name_mangler.dart';

void main() {
  group('NameMangler', () {
    late Lexer lexer;
    late Parser parser;
    
    Program parse(String source) {
      lexer = Lexer(source);
      parser = Parser(lexer);
      return parser.parseProgram();
    }

    test('renames local variables', () {
      final source = '''
fn main() {
  let veryLongName = 10
  return veryLongName
}
''';
      final program = parse(source);
      final mangler = NameMangler();
      final result = mangler.optimize(program);
      
      final func = result.statements.first as FunctionDeclaration;
      final varDecl = func.body.statements[0] as VarDecl;
      expect(varDecl.name.value, isNot(equals('veryLongName')));
      expect(varDecl.name.value.length, lessThan(4));
      
      final ret = func.body.statements[1] as ReturnStatement;
      expect((ret.value as Identifier).value, equals(varDecl.name.value));
    });

    test('preserves global variables', () {
      final source = '''
let globalVar = 100
fn main() {
  return globalVar
}
''';
      final program = parse(source);
      final mangler = NameMangler();
      final result = mangler.optimize(program);
      
      final globalDecl = result.statements.first as VarDecl;
      expect(globalDecl.name.value, equals('globalVar'));
      
      final func = result.statements.last as FunctionDeclaration;
      final ret = func.body.statements.first as ReturnStatement;
      expect((ret.value as Identifier).value, equals('globalVar'));
    });

    test('handles shadowing correctly', () {
      final source = '''
fn main() {
  let x = 10
  if (true) {
    let x = 20
    return x
  }
  return x
}
''';
      final program = parse(source);
      final mangler = NameMangler();
      final result = mangler.optimize(program);
      
      final func = result.statements.first as FunctionDeclaration;
      final outerX = (func.body.statements[0] as VarDecl).name.value;
      
      final ifStmt = func.body.statements[1] as IfStatement;
      final block = ifStmt.consequence;
      final innerX = (block.statements[0] as VarDecl).name.value;
      
      // They should be different or handled by scoping rules
      // Mangler generates new names per declaration. 
      // If scopes are nested, they might get same name if counter resets?
      // No, counter is global to mangler instance (or class).
      // Wait, _NameGenerator is per optimize call.
      
      // In this impl, each declaration gets unique name from generator.
      expect(outerX, isNot(equals(innerX)));
    });
    
    test('does not mangle object keys', () {
      final source = '''
fn main() {
  let obj = { "key": 1, sensitive: 2 }
  return obj
}
''';
      final program = parse(source);
      final mangler = NameMangler();
      final result = mangler.optimize(program);
      
      final func = result.statements.first as FunctionDeclaration;
      final varDecl = func.body.statements[0] as VarDecl;
      final obj = varDecl.value as ObjectLiteral;
      
      expect(obj.pairs.keys, contains('key'));
      expect(obj.pairs.keys, contains('sensitive'));
    });
  });
}
