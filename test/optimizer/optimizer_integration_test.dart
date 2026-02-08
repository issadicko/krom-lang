import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/optimizer/optimizer.dart';

void main() {
  group('Optimizer Integration', () {
    late Lexer lexer;
    late Parser parser;
    
    Program parse(String source) {
      lexer = Lexer(source);
      parser = Parser(lexer);
      return parser.parseProgram();
    }

    test('performs constant folding, inlining, and dead code elimination', () {
      final source = '''
fn add(a, b) {
  return a + b
}
fn unused() {
  return 100
}
fn main() {
  let x = add(10, 20)
  let y = 50 + 50
  let unused_var = 999
  
  if (true) {
    return x + y
  }
}
''';
      // Expected chain:
      // 1. Tree Shaking: Removes 'unused()'.
      // 2. Inlining: 'add(10, 20)' -> '10 + 20'.
      // 3. Constant Propagation: '10+20' -> '30'. '50+50' -> '100'. 'x' -> 30. 'y' -> 100.
      //    'x + y' -> '30 + 100' -> '130'.
      //    'unused_var' is unused.
      // 4. Dead Code Elimination: Removes 'unused_var'.
      
      // Resulting body of main:
      // return 130
      // (VarDecls might be removed if their values are folded into usage).
      // Wait, 'x' is used in 'return x + y'. But 'x' is constant propagated. 
      // So 'return 30 + 100'. 
      // Then 'x' declaration becomes unused!
      // So DCE should remove 'let x = ...' and 'let y = ...'.
      
      final program = parse(source);
      final optimizer = Optimizer();
      final result = optimizer.optimize(program);
      
      // Check Tree Shaking
      // Expect: 'add', 'main'. 'unused' removed?
      // Wait, 'add' is called, so it stays... UNLESS it was fully inlined?
      // Tree Shaking runs FIRST. 'add' is used. So it stays.
      // IF we ran Tree Shaking LAST, 'add' might be removed if all calls were inlined.
      // But we run it FIRST.
      
      // We should check that final main body is optimized.
      
      final mainFunc = result.statements.firstWhere((s) => s is FunctionDeclaration && s.name.value == 'main') as FunctionDeclaration;
      
      // Body should ideally be just 'return 130' inside the if?
      // Or 'if (true) return 130'.
      // Constant Propagation NOW folds 'if(true)' to just its consequence block. 
      // So no IfStatement anymore, just the statements from its consequence.
      
      // After if-folding, the main body should contain the statements from the if's consequence.
      // Look for the ReturnStatement directly in main's body (it might be nested).
      ReturnStatement? findReturn(List<Statement> stmts) {
        for (final s in stmts) {
          if (s is ReturnStatement) return s;
          if (s is BlockStatement) {
            final found = findReturn(s.statements);
            if (found != null) return found;
          }
        }
        return null;
      }
      
      final ret = findReturn(mainFunc.body.statements);
      expect(ret, isNotNull);
      expect(ret!.value, isA<NumberLiteral>());
      expect((ret.value as NumberLiteral).value, equals(130));
      
      // Check DCE
      // 'unused_var' should be gone.
      final varDecls = mainFunc.body.statements.whereType<VarDecl>();
      expect(varDecls.any((v) => v.name.value == 'unused_var'), isFalse);
      
      // 'x' and 'y' might typically be gone if CP propagated everything.
      expect(varDecls.any((v) => v.name.value == 'x'), isFalse);
      expect(varDecls.any((v) => v.name.value == 'y'), isFalse);
    });
  });
}
