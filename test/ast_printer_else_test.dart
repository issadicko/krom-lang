import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/optimizer/optimizer.dart';
import 'package:krom_script/src/ast/ast_printer.dart';

/// Reproduces the bundler's optimize → print round-trip.
String optimizePrint(String src) {
  final program = Parser(Lexer(src)).parseProgram();
  final optimized = Optimizer(
    enableTreeShaking: true,
    enableInlining: false,
    enableConstantPropagation: true,
    enableDeadCodeElimination: true,
  ).optimize(program);
  return ASTPrinter().print(optimized);
}

void main() {
  test('else { if } round-trips: printer never emits un-parseable "else if"',
      () {
    // The KromScript parser does not accept `else if`; the printer must brace
    // the else-branch so its own output re-parses.
    const src = '''
fn build() {
  let out = []
  let xs = [1, 2, 3]
  let mode = "all"
  xs.forEach(fn(x, i) {
    if (mode == "all") {
      out.add(x)
    } else {
      if (x == 2) { out.add(x) }
    }
  })
  return out
}
''';
    final out = optimizePrint(src);
    expect(out.contains('else if'), isFalse,
        reason: 'printer emitted un-parseable "else if":\n$out');

    // The printed output must itself re-parse without a syntax error.
    final reparsed = Parser(Lexer(out));
    reparsed.parseProgram();
    expect(reparsed.errors(), isEmpty,
        reason: 'optimized output failed to re-parse:\n$out');
  });
}
