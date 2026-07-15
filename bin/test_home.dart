import 'dart:io';
import 'package:krom_script/krom_script.dart';

void main() {
  final source =
      File('../krom_bundler/example/pages/home.ks').readAsStringSync();
  print('Lines: ${source.split('\n').length}');

  final parser = Parser(Lexer(source));
  parser.parseProgram();

  final errors = parser.errors();
  if (errors.isEmpty) {
    print('SUCCESS: home.ks parsed without errors');
  } else {
    print('FAILED: ${errors.length} errors:');
    for (final e in errors) {
      print('  - $e');
    }
  }
}
