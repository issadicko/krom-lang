import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('KSEngine execution guard (safe by default)', () {
    test('infinite loop in build() trips the operation budget', () async {
      final engine = KSEngine();
      await engine.load('fn build() { while (true) { } }');
      // Tight budget so the test is fast; deadline generous.
      engine.executionLimits = const ExecutionLimits(
        maxOperations: 100000,
        deadline: Duration(seconds: 5),
      );
      final res = await engine.invoke('build');
      expect(res.success, isFalse);
      expect(res.errors.join('\n').toLowerCase(), contains('operations'));
    });

    test('long loop trips the wall-clock deadline', () async {
      final engine = KSEngine();
      await engine
          .load('fn build() { let i = 0\n while (i < 100000000) { i = i + 1 } }');
      engine.executionLimits = const ExecutionLimits(
        maxOperations: 0, // unlimited ops; only the deadline bounds it
        deadline: Duration(milliseconds: 200),
      );
      final sw = Stopwatch()..start();
      final res = await engine.invoke('build');
      sw.stop();
      expect(res.success, isFalse);
      expect(res.errors.join('\n').toLowerCase(), contains('timeout'));
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });

    test('legitimate build() runs fine under the default safe limits', () async {
      final engine = KSEngine();
      await engine.load(
        'fn build() { let s = 0\n let i = 0\n while (i < 100) { s = s + i\n i = i + 1 }\n return s }',
      );
      final res = await engine.invoke('build'); // default ExecutionLimits()
      expect(res.success, isTrue);
      expect(res.value, equals(4950.0));
    });

    test('ExecutionLimits.unlimited disables the guard', () async {
      final engine = KSEngine();
      engine.executionLimits = ExecutionLimits.unlimited;
      await engine.load(
        'fn build() { let i = 0\n while (i < 1000000) { i = i + 1 }\n return i }',
      );
      final res = await engine.invoke('build');
      expect(res.success, isTrue);
      expect(res.value, equals(1000000.0));
    });
  });
}
