import 'dart:convert';
import 'dart:io';

void main() {
  final content = File(
          '/Users/issahamadoudicko/IdeaProjects/krom/kmini_program/example/assets/bundle.json')
      .readAsStringSync();
  final data = jsonDecode(content) as Map<String, dynamic>;

  // Get the home script which is causing the error at line 379
  final pages = data['pages'] as Map<String, dynamic>;
  final home = pages['home'] as Map<String, dynamic>;
  final script = home['script'] as String;
  final lines = script.split('\n');

  stdout.writeln('Total lines in home script: ${lines.length}');
  stdout.writeln('');

  // Count brackets in whole script
  var openBracket = 0, closeBracket = 0, openParen = 0, closeParen = 0;
  for (final c in script.split('')) {
    if (c == '[') openBracket++;
    if (c == ']') closeBracket++;
    if (c == '(') openParen++;
    if (c == ')') closeParen++;
  }
  stdout.writeln(
      'Bracket count: [ = $openBracket, ] = $closeBracket, match: ${openBracket == closeBracket}');
  stdout.writeln(
      'Paren count: ( = $openParen, ) = $closeParen, match: ${openParen == closeParen}');
  stdout.writeln('');

  // If error is at line 379, show lines around it
  if (lines.length >= 379) {
    stdout.writeln('Lines 375-385:');
    for (var i = 374; i < lines.length && i < 385; i++) {
      stdout.writeln('${i + 1}: ${lines[i]}');
    }
  } else {
    stdout.writeln(
        'Script only has ${lines.length} lines, error is not in home.script');

    // Check other pages
    for (final entry in pages.entries) {
      final pageName = entry.key;
      final pageData = entry.value as Map<String, dynamic>;
      final pageScript = pageData['script'] as String;
      final pageLines = pageScript.split('\n');

      openBracket = 0;
      closeBracket = 0;
      openParen = 0;
      closeParen = 0;
      for (final c in pageScript.split('')) {
        if (c == '[') openBracket++;
        if (c == ']') closeBracket++;
        if (c == '(') openParen++;
        if (c == ')') closeParen++;
      }

      final match = openBracket == closeBracket && openParen == closeParen;
      stdout.writeln(
          'Page "$pageName": ${pageLines.length} lines, brackets: ${match ? "OK" : "MISMATCH"} ([ $openBracket/$closeBracket, ( $openParen/$closeParen)');
    }
  }
}
