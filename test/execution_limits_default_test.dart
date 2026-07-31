import 'package:krom_script/krom_script.dart';
import 'package:test/test.dart';

/// The guard documented on [ExecutionLimits] ("safe by default") must apply to
/// every `KromScript` entry point, not only to `KSEngine`. Each runaway test
/// carries its own timeout so a regression fails the suite instead of hanging
/// CI.
void main() {
  group('KromScript execution guard (safe by default)', () {
    test('builder().execute() stops a runaway loop', () {
      final result =
          KromScript.builder('let i = 0\nwhile (true) { i = i + 1 }').execute();

      expect(result.hasErrors, isTrue);
      expect(result.errors.first.toLowerCase(),
          anyOf(contains('operations'), contains('timeout')));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('run() stops a runaway loop', () {
      final result = KromScript.run('let i = 0\nwhile (true) { i = i + 1 }');

      expect(result.hasErrors, isTrue);
      expect(result.errors.first.toLowerCase(),
          anyOf(contains('operations'), contains('timeout')));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('eval() throws on a runaway loop', () {
      expect(
        () => KromScript.eval('let i = 0\nwhile (true) { i = i + 1 }'),
        throwsA(isA<KromScriptException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('the default guard is reported by ExecutionLimits()', () {
      const limits = ExecutionLimits();
      expect(limits.enabled, isTrue);
      expect(limits.maxOperations, greaterThan(0));
      expect(limits.deadline, greaterThan(Duration.zero));
    });
  });

  group('KromScript execution guard leaves ordinary scripts alone', () {
    test('an ordinary script fits comfortably in the default budget', () {
      final result = KromScript.builder('''
        let sum = 0
        for (i in range(0, 1000)) {
          sum = sum + i
        }
        sum
      ''').execute();

      expect(result.hasErrors, isFalse, reason: result.errors.join('\n'));
      expect(result.value, equals(499500.0));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('run() and eval() are unaffected by the default budget', () {
      final result = KromScript.run(
        'let total = 0\nfor (i in items) { total = total + i }\ntotal',
        variables: {'items': List<double>.generate(5000, (i) => i.toDouble())},
      );

      expect(result.hasErrors, isFalse, reason: result.errors.join('\n'));
      expect(result.value, equals(12497500.0));
      expect(KromScript.eval('2 + 3'), equals(5.0));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('string and native heavy work stays within the default budget', () {
      final result = KromScript.builder('''
        let parts = []
        for (i in range(0, 500)) {
          parts.add("item-" + i)
        }
        join(parts, ",")
      ''').execute();

      expect(result.hasErrors, isFalse, reason: result.errors.join('\n'));
      expect(result.value, contains('item-499'));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('KromScript execution guard is explicitly opt-out', () {
    test('withLimits(ExecutionLimits.unlimited) runs work a tight budget kills',
        () {
      const source = 'let i = 0\nwhile (i < 300000) { i = i + 1 }\ni';

      final bounded = KromScript.builder(source)
          .withLimits(const ExecutionLimits(maxOperations: 1000))
          .execute();
      expect(bounded.hasErrors, isTrue);
      expect(bounded.errors.first, contains('max operations exceeded'));

      final unbounded = KromScript.builder(source)
          .withLimits(ExecutionLimits.unlimited)
          .execute();
      expect(unbounded.hasErrors, isFalse, reason: unbounded.errors.join('\n'));
      expect(unbounded.value, equals(300000.0));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('run() accepts explicit limits', () {
      final bounded = KromScript.run(
        'let i = 0\nwhile (true) { i = i + 1 }',
        limits: const ExecutionLimits(maxOperations: 1000),
      );
      expect(bounded.hasErrors, isTrue);
      expect(bounded.errors.first, contains('max operations exceeded'));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('withLimits() then withMaxOperations() re-arms the guard', () {
      final result = KromScript.builder('let i = 0\nwhile (true) { i = i + 1 }')
          .withLimits(ExecutionLimits.unlimited)
          .withMaxOperations(1000)
          .execute();

      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('max operations exceeded'));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('withMaxOperations() overrides the default budget, both ways', () {
      const source =
          'let sum = 0\nfor (i in range(0, 100)) { sum = sum + i }\nsum';

      final tooTight =
          KromScript.builder(source).withMaxOperations(10).execute();
      expect(tooTight.hasErrors, isTrue);

      final generous =
          KromScript.builder(source).withMaxOperations(1000000).execute();
      expect(generous.hasErrors, isFalse, reason: generous.errors.join('\n'));
      expect(generous.value, equals(4950.0));
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('withTimeout() overrides the default deadline', () {
      final stopwatch = Stopwatch()..start();
      final result = KromScript.builder('let i = 0\nwhile (true) { i = i + 1 }')
          .withTimeout(const Duration(milliseconds: 100))
          .execute();
      stopwatch.stop();

      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('execution timeout'));
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
