import 'package:krom_script/krom_script.dart';
import 'package:test/test.dart';

/// Runtime errors say where they happened.
///
/// The lexer has known each token's line since the start, but the interpreter
/// threw bare `Exception`s: `undefined variable: total` arrived with nothing to
/// go on, and the author had to re-read the whole file. Worse for a mini-app,
/// where the script the engine runs is a concatenation — a position is what
/// lets the host map the failure back to a source file.
///
/// The position comes from two places, both exercised here: the interpreter
/// positions the errors it detects itself, and the statement being executed
/// positions the rest (a native throwing, a case not named explicitly).

/// The error message from running [source], or `null` if it succeeded.
Future<String?> failureOf(String source) async {
  final engine = KSEngine();
  final loaded = await engine.load(source, enableOptimizer: false);
  if (!loaded.success) return loaded.errors.join('\n');
  final ran = await engine.invoke('build');
  return ran.success ? null : ran.errors.join('\n');
}

void main() {
  group('an unknown name says which line', () {
    test('in a function body', () async {
      expect(
        await failureOf('fn build() {\n  let a = inconnue\n  return a\n}'),
        contains('undefined variable: inconnue at line 2'),
      );
    });

    test('at the top level, while loading', () async {
      expect(
        await failureOf('let x = inconnue\nfn build() { return 1 }'),
        contains('undefined variable: inconnue at line 1'),
      );
    });

    test('called as a function', () async {
      expect(
        await failureOf('fn build() {\n  return inconnue()\n}'),
        contains('undefined variable: inconnue at line 2'),
      );
    });
  });

  group('the other runtime faults', () {
    test('a property on null', () async {
      expect(
        await failureOf('fn build() {\n  let m = null\n  return m.x\n}'),
        contains("cannot access property 'x' on null at line 3"),
      );
    });

    test('calling something that is not a function', () async {
      // Positioned by the statement: the interpreter does not detect this
      // case itself, so it has no expression to point at.
      expect(
        await failureOf('fn build() {\n  let n = 3\n  return n()\n}'),
        contains('not a function'),
      );
      expect(await failureOf('fn build() {\n  let n = 3\n  return n()\n}'),
          contains('at line 3'));
    });

    test('a division by zero', () async {
      expect(
        await failureOf('fn build() {\n\n  return 1 / 0\n}'),
        contains('division by zero at line 3'),
      );
    });

    test('iterating something that is neither list nor map', () async {
      expect(
        await failureOf('fn build() {\n  for (x in 42) { }\n  return 1\n}'),
        contains('at line 2'),
      );
    });
  });

  test('the innermost position wins, statements do not overwrite it', () async {
    // The fault is on line 4; the enclosing `if` starts on line 2. Stamping at
    // the statement level only must not swallow the precise line.
    final message = await failureOf('fn build() {\n'
        '  if (true) {\n'
        '    let ok = 1\n'
        '    return inconnue\n'
        '  }\n'
        '  return 0\n'
        '}');
    expect(message, contains('at line 4'));
  });

  test('a resource stop keeps its own kind', () async {
    // The budget guard is not a fault in the script: it must not be rewritten
    // into a plain runtime error, or a host can no longer tell them apart.
    final engine = KSEngine()
      ..executionLimits = const ExecutionLimits(maxOperations: 200);
    await engine.load('fn build() { while (true) { let a = 1 } }',
        enableOptimizer: false);
    final ran = await engine.invoke('build');

    expect(ran.success, isFalse);
    expect(ran.errors.join(), contains('max operations exceeded'));
  });

  test('a syntax error keeps the position it already had', () async {
    expect(
      await failureOf('fn build() {\n  return {\n    a: 1\n    b: 2\n  }\n}'),
      contains('at line 3:9'),
    );
  });
}
