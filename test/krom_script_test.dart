import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  group('KromScript', () {
    group('Basic Expressions', () {
      test('evaluates number literals', () {
        expect(KromScript.eval('42'), equals(42.0));
        expect(KromScript.eval('3.14'), equals(3.14));
      });

      test('evaluates string literals', () {
        expect(KromScript.eval('"hello"'), equals('hello'));
      });

      test('evaluates boolean literals', () {
        expect(KromScript.eval('true'), equals(true));
        expect(KromScript.eval('false'), equals(false));
      });

      test('evaluates null literal', () {
        expect(KromScript.eval('null'), isNull);
      });

      test('evaluates arithmetic', () {
        expect(KromScript.eval('2 + 3'), equals(5.0));
        expect(KromScript.eval('10 - 4'), equals(6.0));
        expect(KromScript.eval('3 * 4'), equals(12.0));
        expect(KromScript.eval('15 / 3'), equals(5.0));
      });

      test('evaluates comparison', () {
        expect(KromScript.eval('5 > 3'), equals(true));
        expect(KromScript.eval('3 < 5'), equals(true));
        expect(KromScript.eval('5 == 5'), equals(true));
        expect(KromScript.eval('5 != 3'), equals(true));
      });

      test('evaluates logical operators', () {
        expect(KromScript.eval('true && true'), equals(true));
        expect(KromScript.eval('true && false'), equals(false));
        expect(KromScript.eval('false || true'), equals(true));
        expect(KromScript.eval('!true'), equals(false));
      });
    });

    group('Variables', () {
      test('declares and uses variables', () {
        expect(KromScript.eval('let x = 10\nx'), equals(10.0));
      });

      test('reassigns variables', () {
        expect(KromScript.eval('let x = 5\nx = 10\nx'), equals(10.0));
      });

      test('injects host variables', () {
        final result = KromScript.run(
          'name + " World"',
          variables: {'name': 'Hello'},
        );
        expect(result.value, equals('Hello World'));
      });
    });

    group('Control Flow', () {
      test('evaluates if-else', () {
        expect(
          KromScript.eval('''
            let x = 10
            if (x > 5) {
              "big"
            } else {
              "small"
            }
          '''),
          equals('big'),
        );
      });

      test('evaluates for-in loop', () {
        final result = KromScript.run('''
          let sum = 0
          for (n in [1, 2, 3, 4, 5]) {
            sum = sum + n
          }
          sum
        ''');
        expect(result.value, equals(15.0));
      });
    });

    group('Functions', () {
      test('defines and calls functions', () {
        expect(
          KromScript.eval('''
            let add = fn(a, b) {
              return a + b
            }
            add(3, 4)
          '''),
          equals(7.0),
        );
      });

      test('supports closures', () {
        expect(
          KromScript.eval('''
            let makeAdder = fn(x) {
              return fn(y) {
                return x + y
              }
            }
            let add5 = makeAdder(5)
            add5(3)
          '''),
          equals(8.0),
        );
      });
    });

    group('Arrays', () {
      test('creates arrays', () {
        final result = KromScript.eval('[1, 2, 3]') as List;
        expect(result, equals([1.0, 2.0, 3.0]));
      });

      test('accesses array elements', () {
        expect(KromScript.eval('[10, 20, 30][1]'), equals(20.0));
      });
    });

    group('Objects', () {
      test('creates objects', () {
        final result = KromScript.eval('{name: "Alice", age: 30}') as Map;
        expect(result['name'], equals('Alice'));
        expect(result['age'], equals(30.0));
      });

      test('accesses object properties', () {
        expect(
          KromScript.eval('let obj = {x: 10}\nobj.x'),
          equals(10.0),
        );
      });

      test('safe access returns null', () {
        expect(
          KromScript.eval('let obj = null\nobj?.x'),
          isNull,
        );
      });

      test('elvis operator provides default', () {
        expect(
          KromScript.eval('null ?: "default"'),
          equals('default'),
        );
      });
    });

    group('Native Functions', () {
      test('string functions', () {
        expect(KromScript.eval('toUpperCase("hello")'), equals('HELLO'));
        expect(KromScript.eval('toLowerCase("HELLO")'), equals('hello'));
        expect(KromScript.eval('length("hello")'), equals(5.0));
        expect(KromScript.eval('trim("  hi  ")'), equals('hi'));
      });

      test('math functions', () {
        expect(KromScript.eval('abs(-5)'), equals(5.0));
        expect(KromScript.eval('floor(3.7)'), equals(3.0));
        expect(KromScript.eval('ceil(3.2)'), equals(4.0));
        expect(KromScript.eval('pow(2, 3)'), equals(8.0));
      });

      test('type functions', () {
        expect(KromScript.eval('typeOf(42)'), equals('number'));
        expect(KromScript.eval('typeOf("hi")'), equals('string'));
        expect(KromScript.eval('isNull(null)'), equals(true));
        expect(KromScript.eval('isNumber(42)'), equals(true));
      });

      test('array functions', () {
        expect(KromScript.eval('size([1,2,3])'), equals(3.0));
        expect(KromScript.eval('first([1,2,3])'), equals(1.0));
        expect(KromScript.eval('last([1,2,3])'), equals(3.0));
      });
    });

    group('Print Output', () {
      test('captures print output', () {
        final result = KromScript.run('''
          print("Hello")
          print("World")
        ''');
        expect(result.output, equals(['Hello', 'World']));
      });
    });

    group('Custom Functions', () {
      test('registers and calls custom function', () {
        final result = KromScript.builder('double(21)')
            .registerFunction('double', (args) => (args[0] as double) * 2)
            .execute();
        expect(result.value, equals(42.0));
      });
    });

    group('Date/Time Functions', () {
      test('now returns timestamp', () {
        final ts = KromScript.eval('now()') as num;
        expect(ts, greaterThan(1700000000000)); // After Nov 2023
      });

      test('date returns YYYY-MM-DD format', () {
        final dateStr = KromScript.eval('date()') as String;
        expect(dateStr.length, equals(10));
        expect(dateStr[4], equals('-'));
      });

      test('time returns HH:MM:SS format', () {
        final timeStr = KromScript.eval('time()') as String;
        expect(timeStr.length, equals(8));
        expect(timeStr[2], equals(':'));
      });

      test('datetime returns ISO format', () {
        final dtStr = KromScript.eval('datetime()') as String;
        expect(dtStr.contains('T'), isTrue);
      });

      test('year, month, day extract components', () {
        final year = KromScript.eval('year()') as num;
        expect(year, greaterThanOrEqualTo(2024));

        final month = KromScript.eval('month()') as num;
        expect(month, inInclusiveRange(1, 12));

        final day = KromScript.eval('day()') as num;
        expect(day, inInclusiveRange(1, 31));
      });

      test('hour, minute, second extract components', () {
        final hour = KromScript.eval('hour()') as num;
        expect(hour, inInclusiveRange(0, 23));

        final minute = KromScript.eval('minute()') as num;
        expect(minute, inInclusiveRange(0, 59));

        final second = KromScript.eval('second()') as num;
        expect(second, inInclusiveRange(0, 59));
      });

      test('dayOfWeek returns 0-6', () {
        final dow = KromScript.eval('dayOfWeek()') as num;
        expect(dow, inInclusiveRange(0, 6));
      });

      test('timestamp parses date string', () {
        final ts = KromScript.eval('timestamp("2024-12-25")') as num;
        expect(ts, greaterThan(0));
      });

      test('formatDate formats timestamp', () {
        final result = KromScript.eval('''
          let ts = timestamp("2024-12-25")
          formatDate(ts, "DD/MM/YYYY")
        ''');
        expect(result, equals('25/12/2024'));
      });

      test('year, month, day from specific date', () {
        expect(
            KromScript.eval('year(timestamp("2024-12-25"))'), equals(2024.0));
        expect(KromScript.eval('month(timestamp("2024-12-25"))'), equals(12.0));
        expect(KromScript.eval('day(timestamp("2024-12-25"))'), equals(25.0));
      });

      test('addDays adds days to timestamp', () {
        final result = KromScript.eval('''
          let ts = timestamp("2024-01-01")
          let nextWeek = addDays(ts, 7)
          day(nextWeek)
        ''');
        expect(result, equals(8.0));
      });

      test('diffDays calculates difference', () {
        final result = KromScript.eval('''
          let ts1 = timestamp("2024-01-01")
          let ts2 = timestamp("2024-01-08")
          diffDays(ts1, ts2)
        ''');
        expect(result, equals(7.0));
      });

      test('addHours adds hours to timestamp', () {
        final result = KromScript.eval('''
          let ts = now()
          let later = addHours(ts, 24)
          diffDays(ts, later)
        ''');
        expect(result, equals(1.0));
      });
    });
  });
}
