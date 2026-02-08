import 'package:test/test.dart';
import 'dart:io';
import 'package:krom_script/krom_script.dart';

void main() {
  test('should parse the full combined script', () {
    final source = File('/tmp/full_combined.ks').readAsStringSync();
    print('Script length: ${source.length} characters');
    print('Script lines: ${source.split('\n').length}');
    
    final engine = KSEngine();
    
    // This should not throw
    expect(() => engine.load(source), returnsNormally);
    
    // Try to invoke build
    final result = engine.invoke('build');
    print('Build result: $result');
  });
}
