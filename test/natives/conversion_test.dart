
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/natives/natives.dart';
import 'package:test/test.dart';

void main() {
  group('Conversion Natives', () {
    late NativeFunctions natives;

    setUp(() {
      natives = NativeFunctions.withBuiltins();
    });

    test('toInt converts various types correctly', () {
      final toInt = natives.get('toInt')!;
      
      expect(toInt([10]), equals(10.0));
      expect(toInt([10.5]), equals(10.0));
      expect(toInt(["123"]), equals(123.0));
      expect(toInt(["12.9"]), equals(12.0)); // Truncates via toInt()
      expect(toInt([true]), equals(1.0));
      expect(toInt([false]), equals(0.0));
      expect(toInt([]), equals(0.0));
      expect(toInt([null]), equals(0.0));
      expect(toInt(["not a number"]), equals(0.0)); // Should log error and return 0
      expect(toInt([[1, 2]]), equals(0.0)); // Invalid type returns 0
    });

    test('toDouble converts various types correctly', () {
      final toDouble = natives.get('toDouble')!;
      
      expect(toDouble([10]), equals(10.0));
      expect(toDouble([10.5]), equals(10.5));
      expect(toDouble(["123"]), equals(123.0));
      expect(toDouble(["12.5"]), equals(12.5));
      expect(toDouble([true]), equals(1.0));
      expect(toDouble([false]), equals(0.0));
      expect(toDouble([]), equals(0.0));
      expect(toDouble([null]), equals(0.0));
      expect(toDouble(["not a number"]), equals(0.0)); // Should log error and return 0
    });
  });
}
