import 'package:test/test.dart';
import 'package:krom_script/src/parser/parser.dart';
import 'package:krom_script/src/lexer/lexer.dart';
import 'package:krom_script/src/optimizer/optimizer.dart';
import 'package:krom_script/src/ast/ast.dart';

Program parse(String input) {
  final l = Lexer(input);
  final p = Parser(l);
  return p.parseProgram();
}

void main() {
  group('Optimizer', () {
    test('Arithmetic folding', () {
      final prog = parse('return 2 + 3 * 2;');
      final optimizer = Optimizer();
      final optimized = optimizer.optimize(prog);
      
      final stmt = optimized.statements[0] as ReturnStatement;
      expect(stmt.value, isA<NumberLiteral>());
      expect((stmt.value as NumberLiteral).value, 8.0);
    });

    test('String folding', () {
      final prog = parse('return "Hel" + "lo";');
      final optimizer = Optimizer();
      final optimized = optimizer.optimize(prog);
      
      final stmt = optimized.statements[0] as ReturnStatement;
      expect(stmt.value, isA<StringLiteral>());
      expect((stmt.value as StringLiteral).value, "Hello");
    });

    test('Boolean folding', () {
      final prog = parse('return true && false || true;');
      final optimizer = Optimizer();
      final optimized = optimizer.optimize(prog);
      // ((true && false) || true) -> (false || true) -> true
      
      final stmt = optimized.statements[0] as ReturnStatement;
      expect(stmt.value, isA<BooleanLiteral>());
      expect((stmt.value as BooleanLiteral).value, true);
    });

    test('Template folding', () {
      final prog = parse('return "Val: \${"ue"}";'); 
      final optimizer = Optimizer();
      final optimized = optimizer.optimize(prog);
      
      final stmtResult = optimized.statements[0] as ReturnStatement;
      expect(stmtResult.value, isA<StringLiteral>());
      expect((stmtResult.value as StringLiteral).value, "Val: ue");
    });

    test('If Statement True folding', () {
      final prog = parse('if (true) { return 1; } else { return 2; }');
      final optimizer = Optimizer();
      final optimized = optimizer.optimize(prog);
      
      // Should become just BlockStatement with Return 1
      expect(optimized.statements[0], isA<BlockStatement>());
      final block = optimized.statements[0] as BlockStatement;
      expect(block.statements[0], isA<ReturnStatement>());
      expect(((block.statements[0] as ReturnStatement).value as NumberLiteral).value, 1.0);
    });

    test('If Statement False folding', () {
      final prog = parse('if (false) { return 1; } else { return 2; }');
      final optimizer = Optimizer();
      final optimized = optimizer.optimize(prog);
      
      expect(optimized.statements[0], isA<BlockStatement>());
      final block = optimized.statements[0] as BlockStatement;
      expect(block.statements[0], isA<ReturnStatement>());
      expect(((block.statements[0] as ReturnStatement).value as NumberLiteral).value, 2.0);
    });
    
    test('Recursive folding inside call args', () {
       final prog = parse('print(1+1)');
       final optimizer = Optimizer();
       final optimized = optimizer.optimize(prog);
       
       final stmt = optimized.statements[0] as ExpressionStatement;
       final call = stmt.expression as CallExpr;
       expect(call.arguments[0], isA<NumberLiteral>());
       expect((call.arguments[0] as NumberLiteral).value, 2.0);
    });
  });
}
