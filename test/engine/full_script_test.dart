import 'package:test/test.dart';
import 'dart:io';
import 'package:krom_script/krom_script.dart';

void main() {
  // Debug harness for a locally-bundled script: only meaningful on a machine
  // that has one at /tmp/full_combined.ks. Skipped everywhere else so the
  // suite stays green.
  final fixture = File('/tmp/full_combined.ks');

  test(
    'should parse the full combined script',
    () {
      final source = fixture.readAsStringSync();
      print('Script length: ${source.length} characters');
      print('Script lines: ${source.split('\n').length}');

      final engine = KSEngine();

      // This should not throw
      expect(() => engine.load(source), returnsNormally);

      // Try to invoke build
      final result = engine.invoke('build');
      print('Build result: $result');
    },
    skip: fixture.existsSync()
        ? null
        : 'fixture /tmp/full_combined.ks not present on this machine',
  );
}
