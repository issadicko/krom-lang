import 'package:krom_script/krom_script.dart';

void main() {
  // Minimal failing case
  final source = '''
fn test() {
  return Parent([
    FuncA({ a: 1 }, FuncB({ b: 2 }, [Item1(), Item2()])),
    Other()
  ])
}
''';

  print('=== Parsing minimal failing case ===');
  print('Source:');
  print(source);
  print('\n--- Tokens ---');
  
  final lexer = Lexer(source);
  while (true) {
    final token = lexer.nextToken();
    print('${token.type.name.padRight(15)} ${token.literal.padRight(20)} (${token.line}:${token.column})');
    if (token.type == TokenType.eof) break;
  }
  
  print('\n--- Parsing ---');
  final parser = Parser(Lexer(source));
  final program = parser.parseProgram();
  
  if (parser.errors().isEmpty) {
    print('SUCCESS!');
  } else {
    print('FAILED:');
    for (final e in parser.errors()) {
      print('  - $e');
    }
  }
}
