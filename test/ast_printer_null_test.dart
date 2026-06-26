import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/optimizer/optimizer.dart';
import 'package:krom_script/src/ast/ast_printer.dart';

/// Reproduces the bundler's optimize → print round-trip.
String optimizePrint(String src) {
  final program = Parser(Lexer(src)).parseProgram();
  final optimized = Optimizer(
    enableTreeShaking: true,
    enableInlining: true,
    enableConstantPropagation: true,
    enableDeadCodeElimination: true,
  ).optimize(program);
  return ASTPrinter().print(optimized);
}

void main() {
  test('null literal is printed as "null", never "nil"', () {
    final out = optimizePrint(
      'fn build() {\n  let x = null\n  if (x == null) { return 1 }\n  return 0\n}',
    );
    expect(out.contains('null'), isTrue);
    expect(out.contains('nil'), isFalse,
        reason: 'ASTPrinter must emit null, not nil:\n$out');
  });

  test('optimized output using null re-loads without "undefined variable: nil"',
      () async {
    final out = optimizePrint('fn build() {\n  let x = null\n  return x\n}');
    final engine = KSEngine();
    final res = await engine.load(out, enableOptimizer: false);
    expect(res.success, isTrue, reason: res.errors.join('\n'));
  });
}
