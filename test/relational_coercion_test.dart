import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

/// Ordering (`<`, `>`, `<=`, `>=`) is defined only over numbers and strings
/// that parse as numbers. Any other operand — null, bool, map, list, function,
/// non-numeric string — makes the comparison undefined, and an undefined
/// comparison is false, on either side, for all four operators.
///
/// Regression tests for issue #15: those operands used to coerce to 0.0, so
/// `null < 5` answered true.

/// Declares the map / list / function operands used below.
const prelude = 'let obj = {"k": 1}\n'
    'let arr = [1, 2]\n'
    'let fun = fn(x) { return x }\n';

/// Asserts that all four ordering operators are false with [operand] on either
/// side of a number. The mirrored form is checked explicitly because an
/// asymmetric fix is the classic trap here.
void expectNotOrderable(String operand) {
  for (final op in const ['<', '>', '<=', '>=']) {
    expect(KromScript.eval('$prelude$operand $op 5'), isFalse,
        reason: '$operand $op 5 must be false');
    expect(KromScript.eval('$prelude 5 $op $operand'), isFalse,
        reason: '5 $op $operand must be false');
  }
}

void main() {
  group('Ordering with a non-orderable operand', () {
    test('null is not orderable', () {
      expectNotOrderable('null');
    });

    test('a non-numeric string is not orderable', () {
      expectNotOrderable('"abc"');
    });

    test('an empty string is not orderable', () {
      expectNotOrderable('""');
    });

    test('booleans are not orderable', () {
      expectNotOrderable('true');
      expectNotOrderable('false');
    });

    test('a map is not orderable', () {
      expectNotOrderable('obj');
    });

    test('a list is not orderable', () {
      expectNotOrderable('arr');
    });

    test('a function is not orderable', () {
      expectNotOrderable('fun');
    });

    test('two non-orderable operands compare false, including <= and >=', () {
      expect(KromScript.eval('null < null'), isFalse);
      expect(KromScript.eval('null > null'), isFalse);
      expect(KromScript.eval('null <= null'), isFalse);
      expect(KromScript.eval('null >= null'), isFalse);
      expect(KromScript.eval('"abc" <= "abc"'), isFalse);
      expect(KromScript.eval('"abc" >= "abc"'), isFalse);
    });

    test('an unfilled field keeps both sides of a rule dormant', () {
      // The motivating case: `age` is an unfilled form field. Neither the
      // "minor" rule nor the "adult" rule may fire on a value we do not have.
      expect(
          KromScript.run('age < 18', variables: {'age': null}).value, isFalse);
      expect(
          KromScript.run('age >= 18', variables: {'age': null}).value, isFalse);
      // Filled in, the rule works again.
      expect(
          KromScript.run('age < 18', variables: {'age': 12.0}).value, isTrue);
      expect(
          KromScript.run('age >= 18', variables: {'age': 12.0}).value, isFalse);
    });
  });

  group('Ordering with numeric operands', () {
    test('numbers compare numerically', () {
      expect(KromScript.eval('3 < 5'), isTrue);
      expect(KromScript.eval('5 < 3'), isFalse);
      expect(KromScript.eval('5 > 3'), isTrue);
      expect(KromScript.eval('3 > 5'), isFalse);
      expect(KromScript.eval('5 <= 5'), isTrue);
      expect(KromScript.eval('5 >= 5'), isTrue);
      expect(KromScript.eval('4 <= 5'), isTrue);
      expect(KromScript.eval('4 >= 5'), isFalse);
      expect(KromScript.eval('-1 < 0'), isTrue);
      expect(KromScript.eval('2.5 < 2.75'), isTrue);
    });

    test('a numeric string still compares numerically', () {
      expect(KromScript.eval('"10" < 5'), isFalse);
      expect(KromScript.eval('"10" > 5'), isTrue);
      expect(KromScript.eval('5 < "10"'), isTrue);
      expect(KromScript.eval('5 > "10"'), isFalse);
      expect(KromScript.eval('"10" <= 10'), isTrue);
      expect(KromScript.eval('"10" >= 10'), isTrue);
      expect(KromScript.eval('"3.5" < "10"'), isTrue);
      expect(KromScript.eval('"-2" < 0'), isTrue);
    });

    test('a numeric string mixed with a non-orderable operand is false', () {
      expect(KromScript.eval('"10" < null'), isFalse);
      expect(KromScript.eval('null < "10"'), isFalse);
      expect(KromScript.eval('"10" > "abc"'), isFalse);
      expect(KromScript.eval('"abc" > "10"'), isFalse);
    });
  });

  group('Untouched by this fix', () {
    test('equality keeps its semantics', () {
      expect(KromScript.eval('null == null'), isTrue);
      expect(KromScript.eval('null != null'), isFalse);
      expect(KromScript.eval('null == 0'), isFalse);
      expect(KromScript.eval('null != 0'), isTrue);
      expect(KromScript.eval('"abc" == 5'), isFalse);
      expect(KromScript.eval('"abc" != 5'), isTrue);
      expect(KromScript.eval('"10" == 10'), isFalse);
      expect(KromScript.eval('true == true'), isTrue);
    });

    test('arithmetic coercion is unchanged (out of scope for issue #15)', () {
      // Documents today's behaviour so the ordering fix is provably scoped to
      // the ordering operators; not an endorsement of the arithmetic rule.
      expect(KromScript.eval('null + 5'), equals(5.0));
      expect(KromScript.eval('null - 5'), equals(-5.0));
      expect(KromScript.eval('"abc" * 5'), equals(0.0));
    });

    test('sort keeps its own total order', () {
      expect(KromScript.eval('let a = [3, 1, 2]\nsort(a)'),
          equals([1.0, 2.0, 3.0]));
    });
  });
}
