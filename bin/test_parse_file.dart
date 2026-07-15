import 'dart:io';
import 'package:krom_script/krom_script.dart';

void main() {
  final source =
      File('../krom_bundler/example/output_raw.ks').readAsStringSync();
  print(
      'Source length: ${source.length} chars, ${source.split('\n').length} lines');

  final parser = Parser(Lexer(source));
  parser.parseProgram();

  final errors = parser.errors();
  if (errors.isEmpty) {
    print('SUCCESS: Parsed without errors!');
  } else {
    print('FAILED: ${errors.length} errors:');
    for (final e in errors) {
      print('  - $e');
    }

    // Print lines around first error
    final lines = source.split('\n');
    print('\n--- Lines around error (115-130) ---');
    for (int i = 114; i < 130 && i < lines.length; i++) {
      print('${i + 1}: ${lines[i]}');
    }
  }
}
