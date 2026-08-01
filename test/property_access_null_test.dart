import 'package:krom_script/krom_script.dart';
import 'package:test/test.dart';

/// Property resolution: reading a property that is null or absent yields null
/// instead of throwing (#10), and `?.` resolves exactly like `.` on every
/// receiver type, short-circuiting only on a null receiver (#11).

/// A bindable with one property that is declared but null, one that has a
/// value, and one real method — the three cases the resolver must tell apart.
class Profile implements KromBindable {
  @override
  Object? getProperty(String name) {
    switch (name) {
      case 'code':
        return null; // declared, but no value yet
      case 'label':
        return 'hello';
      default:
        return null;
    }
  }

  @override
  Object? callMethod(String name, List<Object?> args) {
    if (name == 'shout') return 'HELLO';
    return methodNotFound;
  }
}

Map<String, Object?> makeVars() => <String, Object?>{
      'm': <String, Object?>{'n': 3, 'vide': null, 's': 'ok'},
      'l': [1, 2, 3],
      's': 'hey',
      'p': Profile(),
      'obs': Rx<Object?>(null),
      'nul': null,
      'nb': 42,
    };

/// Evaluates [source] and fails the test if the script reported an error.
Object? evalOk(String source) {
  final result = KromScript.builder(source).withVariables(makeVars()).execute();
  expect(result.hasErrors, isFalse, reason: result.errors.join('\n'));
  return result.value;
}

/// Evaluates [source] expecting failure, and returns the reported errors.
List<String> evalErrors(String source) {
  final result = KromScript.builder(source).withVariables(makeVars()).execute();
  expect(result.hasErrors, isTrue,
      reason: 'expected an error, got ${result.value}');
  return result.errors;
}

void main() {
  group('property access on a map (#10)', () {
    test('reads a present value', () {
      expect(evalOk('m.n'), 3);
      expect(evalOk('m.s'), 'ok');
    });

    test('a present value that is null reads as null', () {
      expect(evalOk('m.vide'), isNull);
    });

    test('an absent key reads as null', () {
      expect(evalOk('m.absent'), isNull);
    });

    test('built-in map members still resolve', () {
      expect(evalOk('m.length'), 3.0);
      expect(evalOk('m.isEmpty'), false);
      expect(evalOk('m.keys.length'), 3.0);
    });

    test('a key shadows a built-in member name', () {
      final result =
          KromScript.builder('m.length').withVariables(<String, Object?>{
        'm': <String, Object?>{'length': 'mine'}
      }).execute();
      expect(result.hasErrors, isFalse, reason: result.errors.join('\n'));
      expect(result.value, 'mine');
    });

    test('a null property is falsy and compares equal to null', () {
      expect(evalOk('m.vide == null'), true);
      expect(evalOk('m.absent == null'), true);
      expect(evalOk('if (m.vide) { "truthy" } else { "falsy" }'), 'falsy');
      expect(evalOk('m.absent ?: "default"'), 'default');
    });

    test('a null property does not leak a callable into host data', () {
      final body = evalOk('{ code: p.code, vide: m.vide }') as Map;
      expect(body['code'], isNull);
      expect(body['vide'], isNull);
    });

    test('reading through a null intermediate still throws', () {
      expect(evalErrors('m.vide.x').first, contains('on null'));
      expect(evalErrors('m.absent.x').first, contains('on null'));
    });

    test('?. after a null intermediate short-circuits', () {
      expect(evalOk('m.vide?.x'), isNull);
      expect(evalOk('m.absent?.x'), isNull);
      expect(evalOk('m?.absent?.x?.y'), isNull);
    });
  });

  group('safe access resolves like dot access (#11)', () {
    test('on a map', () {
      expect(evalOk('m?.n'), 3);
      expect(evalOk('m?.vide'), isNull);
      expect(evalOk('m?.absent'), isNull);
      expect(evalOk('m?.length'), 3.0);
    });

    test('on a list', () {
      expect(evalOk('l?.length'), evalOk('l.length'));
      expect(evalOk('l?.length'), 3.0);
      expect(evalOk('l?.isEmpty'), false);
      expect(evalOk('l?.isNotEmpty'), true);
    });

    test('on a string', () {
      expect(evalOk('s?.length'), evalOk('s.length'));
      expect(evalOk('s?.length'), 3.0);
      expect(evalOk('s?.isEmpty'), false);
    });

    test('reaches methods, like dot access', () {
      expect(evalOk('s?.toUpperCase()'), 'HEY');
      expect(evalOk('s?.substring(1)'), 'ey');
    });

    test('short-circuits only when the receiver is null', () {
      expect(evalOk('nul?.x'), isNull);
      expect(evalOk('nul?.x?.y'), isNull);
    });

    test('a null receiver still throws under dot access', () {
      expect(evalErrors('nul.x').first, contains('on null'));
    });

    test('an unknown member reads as null on lists and strings too', () {
      expect(evalOk('l.nope'), isNull);
      expect(evalOk('l?.nope'), isNull);
      expect(evalOk('s.nope'), isNull);
      expect(evalOk('s?.nope'), isNull);
    });

    test('agrees with dot access on a receiver that exposes nothing', () {
      // Parity: `?.` is not a way to silence an unsupported receiver, only a
      // way to survive a null one.
      expect(evalErrors('nb.x').first, contains('KromBindable'));
      expect(evalErrors('nb?.x').first, contains('KromBindable'));
    });
  });

  group('bindable property resolution (#10)', () {
    test('a declared property whose value is null reads as null', () {
      final value = evalOk('p.code');
      expect(value, isNull);
      expect(value, isNot(isA<NativeFunctionValue>()));
    });

    test('an unknown property reads as null', () {
      expect(evalOk('p.inconnu'), isNull);
    });

    test('a property with a value still reads', () {
      expect(evalOk('p.label'), 'hello');
    });

    test('a declared method is still callable', () {
      expect(evalOk('p.shout()'), 'HELLO');
    });

    test('a method is materialized only where it is called', () {
      // A bindable cannot be asked which methods it declares, so the callable
      // wrapper is built at the call site. Read as a plain value, a method
      // name is null rather than an opaque object that would flow into data.
      expect(evalOk('p.shout'), isNull);
    });

    test('an unknown method still reports an error', () {
      expect(evalErrors('p.nope()').first, contains('nope'));
    });

    test('safe access resolves bindables too', () {
      expect(evalOk('p?.label'), 'hello');
      expect(evalOk('p?.code'), isNull);
      expect(evalOk('p?.shout()'), 'HELLO');
    });

    test('a reactive value holding null reads as null', () {
      expect(evalOk('obs.value'), isNull);
      expect(evalOk('obs.value ?: "vide"'), 'vide');
    });
  });
}
