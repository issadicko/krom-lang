import 'dart:convert';

import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

/// A bound object that exposes numbers of every Dart spelling and records the
/// arguments the script hands to it.
class Meter implements KromBindable {
  final List<Object?> received = [];

  @override
  Object? getProperty(String name) {
    switch (name) {
      case 'count': // Dart int
        return 3;
      case 'total': // Dart double, integral
        return 3.0;
      case 'ratio': // Dart double, fractional
        return 2.5;
      default:
        return null;
    }
  }

  @override
  Object? callMethod(String name, List<Object?> args) {
    switch (name) {
      case 'read':
        return 42; // Dart int
      case 'average':
        return 4.0; // Dart double, integral
      case 'take':
        received.addAll(args);
        return null;
      default:
        return methodNotFound;
    }
  }
}

void main() {
  group('Canonical numeric representation at the host boundary', () {
    // The exact repro from issue #14.
    Map<String, Object?> hostData() => {
          'm': {'n': 3},
          'l': [1, 2, 3],
        };

    group('every access path yields the same Dart type', () {
      test('property access on a host map', () {
        final result = KromScript.run('m.n', variables: hostData());
        expect(result.hasErrors, isFalse);
        expect(result.value, isA<int>());
        expect(result.value, 3);
      });

      test('index access on a host map', () {
        final result = KromScript.run('m["n"]', variables: hostData());
        expect(result.hasErrors, isFalse);
        expect(result.value, isA<int>());
        expect(result.value, 3);
      });

      test('arithmetic', () {
        final result = KromScript.run('1 + 1');
        expect(result.hasErrors, isFalse);
        expect(result.value, isA<int>());
        expect(result.value, 2);
      });

      test('length through the reflective path', () {
        final result = KromScript.run('l.length', variables: hostData());
        expect(result.hasErrors, isFalse);
        expect(result.value, isA<int>());
        expect(result.value, 3);
      });

      test('the same field serialises identically whatever touched it', () {
        final encoded = <String>[];
        for (final source in ['m.n', 'm["n"]', 'l.length', '1 + 2']) {
          final result = KromScript.run(source, variables: hostData());
          expect(result.hasErrors, isFalse, reason: source);
          encoded.add(jsonEncode({'qty': result.value}));
        }
        expect(encoded, everyElement('{"qty":3}'));
      });
    });

    group('host variables', () {
      test('an int goes in and comes back unchanged', () {
        final result = KromScript.run('qty', variables: {'qty': 3});
        expect(result.value, isA<int>());
        expect(result.value, 3);
      });

      test('an int wider than a double survives the round trip', () {
        const big = 9007199254740993; // 2^53 + 1, not representable as double
        final result = KromScript.run('id', variables: {'id': big});
        expect(result.value, isA<int>());
        expect(result.value, big);
      });

      test('an integral double comes back as an int', () {
        final result = KromScript.run('qty', variables: {'qty': 3.0});
        expect(result.value, isA<int>());
        expect(result.value, 3);
      });

      test('a fractional double stays a double', () {
        final result = KromScript.run('price', variables: {'price': 2.5});
        expect(result.value, isA<double>());
        expect(result.value, 2.5);
      });

      test('arithmetic on a host int yields an int', () {
        final result = KromScript.run('qty * 2', variables: {'qty': 3});
        expect(result.value, isA<int>());
        expect(result.value, 6);
      });

      test('arithmetic on a host int keeps a fractional result fractional', () {
        final result = KromScript.run('qty / 2', variables: {'qty': 3});
        expect(result.value, isA<double>());
        expect(result.value, 1.5);
      });

      test('numbers nested in the returned value are canonical too', () {
        final result = KromScript.run(
          '{ qty: 1 + 1, price: 2.5, tags: [l.length, 0.5] }',
          variables: hostData(),
        );
        expect(result.hasErrors, isFalse);
        expect(
          jsonEncode(result.value),
          '{"qty":2,"price":2.5,"tags":[3,0.5]}',
        );
      });
    });

    group('KromBindable', () {
      test('an int property crosses as an int', () {
        final result =
            KromScript.builder('m.count').bind('m', Meter()).execute();
        expect(result.hasErrors, isFalse);
        expect(result.value, isA<int>());
        expect(result.value, 3);
      });

      test('an integral double property crosses as an int', () {
        final result =
            KromScript.builder('m.total').bind('m', Meter()).execute();
        expect(result.value, isA<int>());
        expect(result.value, 3);
      });

      test('a fractional property stays a double', () {
        final result =
            KromScript.builder('m.ratio').bind('m', Meter()).execute();
        expect(result.value, isA<double>());
        expect(result.value, 2.5);
      });

      test('a method returning an int crosses as an int', () {
        final result =
            KromScript.builder('m.read()').bind('m', Meter()).execute();
        expect(result.value, isA<int>());
        expect(result.value, 42);
      });

      test('a method returning an integral double crosses as an int', () {
        final result =
            KromScript.builder('m.average()').bind('m', Meter()).execute();
        expect(result.value, isA<int>());
        expect(result.value, 4);
      });

      test('a bound property survives arithmetic and stays canonical', () {
        final result = KromScript.builder('m.count + m.total')
            .bind('m', Meter())
            .execute();
        expect(result.value, isA<int>());
        expect(result.value, 6);
      });

      test('arguments reach the bound object canonical', () {
        final meter = Meter();
        final result = KromScript.builder('m.take(1 + 1, 2.5, m.count)')
            .bind('m', meter)
            .execute();
        expect(result.hasErrors, isFalse, reason: result.errors.join(', '));
        expect(meter.received, [2, 2.5, 3]);
        expect(meter.received[0], isA<int>());
        expect(meter.received[1], isA<double>());
        expect(meter.received[2], isA<int>());
      });
    });

    group('KSEngine', () {
      late KSEngine engine;

      setUp(() => engine = KSEngine());
      tearDown(() => engine.dispose());

      test('an invoke() result is canonical', () async {
        await engine.load('fn total() { return 2 + 2 }');
        final result = await engine.invoke('total');
        expect(result.success, isTrue);
        expect(result.value, isA<int>());
        expect(result.value, 4);
      });

      test('numbers nested in a returned tree are canonical', () async {
        final loaded = await engine.load('''
          let counter = Obs(0)
          fn build() {
            return { type: "Text", props: { count: counter.value + 1, gap: 0.5 } }
          }
        ''');
        expect(loaded.success, isTrue, reason: loaded.errors.join(', '));
        final result = await engine.invoke('build');
        expect(result.success, isTrue, reason: result.errors.join(', '));
        expect(
          jsonEncode(result.value),
          '{"type":"Text","props":{"count":1,"gap":0.5}}',
        );
      });

      test('getVariable returns canonical numbers', () async {
        await engine.load('let count = 1 + 1\nlet ratio = 0.5');
        expect(engine.getVariable('count'), isA<int>());
        expect(engine.getVariable('count'), 2);
        expect(engine.getVariable('ratio'), isA<double>());
      });

      test('a host int set with setVariable is read back unchanged', () async {
        engine.setVariable('qty', 3);
        await engine.load('fn read() { return qty }');
        final result = await engine.invoke('read');
        expect(result.value, isA<int>());
        expect(result.value, 3);
      });
    });

    group('jsonStringify, the wire format', () {
      test('encodes a whole number without a trailing .0', () {
        expect(KromScript.eval('jsonStringify(1 + 1)'), '2');
        expect(KromScript.eval('jsonStringify({ n: 3 })'), '{"n":3}');
      });

      test('leaves a fractional number alone', () {
        expect(KromScript.eval('jsonStringify({ n: 2.5 })'), '{"n":2.5}');
      });

      test('recurses into nested lists and maps', () {
        expect(
          KromScript.eval(
              'jsonStringify({ a: [1, 2.5, [3]], b: { c: 4 / 2 } })'),
          '{"a":[1,2.5,[3]],"b":{"c":2}}',
        );
      });

      test('encodes host data the same however the script reached it', () {
        final vars = {
          'm': {'n': 3},
          'l': [1, 2, 3],
        };
        for (final source in [
          'jsonStringify(m.n)',
          'jsonStringify(l.length)'
        ]) {
          expect(KromScript.run(source, variables: vars).value, '3',
              reason: source);
        }
      });

      test('round-trips stably through jsonParse', () {
        const body = '{"items":[1,2],"qty":3,"rate":2.5,"name":"x,y"}';
        // The property a twin engine depends on: parse then re-encode must
        // give back the same bytes, and stay stable when re-applied.
        expect(
            KromScript.eval('jsonStringify(jsonParse("${body.replaceAll(
              '"',
              '\\"',
            )}"))'),
            body);
      });

      test('a computed number re-encodes to what it parsed from', () {
        expect(
          KromScript.eval(
              'jsonStringify({ n: jsonParse("{\\"n\\":2}").n + 0 })'),
          '{"n":2}',
        );
      });
    });

    group('display is unaffected', () {
      test('print() renders an integral result without a trailing .0', () {
        expect(KromScript.run('print(1 + 1)').output, ['2']);
        expect(KromScript.run('print(4.0)').output, ['4']);
        expect(
          KromScript.run('print(qty)', variables: {'qty': 3}).output,
          ['3'],
        );
      });

      test('print() renders a fractional result unchanged', () {
        expect(KromScript.run('print(1.5)').output, ['1.5']);
        expect(KromScript.run('print(3 / 2)').output, ['1.5']);
        expect(
          KromScript.run('print(price)', variables: {'price': 2.5}).output,
          ['2.5'],
        );
      });

      test('kromDisplay renders both spellings of a whole number alike', () {
        expect(kromDisplay(2), '2');
        expect(kromDisplay(2.0), '2');
        expect(kromDisplay(2.5), '2.5');
        expect(kromDisplay([1, 2.0, 2.5]), '[1, 2, 2.5]');
      });

      test('interpolation and concatenation are unchanged', () {
        expect(KromScript.eval('"n=" + (1 + 1)'), 'n=2');
        expect(KromScript.eval('let x = 1 + 1\n"n=\${x}"'), 'n=2');
      });
    });

    group('edge cases', () {
      test('a double too large to be an exact int stays a double', () {
        final result = KromScript.run('big', variables: {'big': 1e20});
        expect(result.value, isA<double>());
        expect(result.value, 1e20);
      });

      test('a host collection is only rebuilt when it holds a stale number',
          () {
        final canonical = {'n': 3};
        expect(
          KromScript.run('m', variables: {'m': canonical}).value,
          same(canonical),
          reason: 'already canonical: must not be copied',
        );

        // Non-string keys are unreachable from script syntax but must still
        // survive the walk.
        final result = KromScript.run('m', variables: <String, Object?>{
          'm': <int, Object?>{1: 3.0, 2: 2.5}
        }).value;
        expect(result, {1: 3, 2: 2.5});
        expect((result as Map)[1], isA<int>());
      });

      test('a non-finite double stays a double', () {
        final result = KromScript.run('x', variables: {'x': double.infinity});
        expect(result.value, isA<double>());
        expect(result.value, double.infinity);
      });
    });
  });
}
