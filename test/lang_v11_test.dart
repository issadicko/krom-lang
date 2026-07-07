import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

/// Language ergonomics wave 1: else-if chains, compound assignment,
/// block comments (and their ASI behavior).
void main() {
  Future<Object?> run(String source, [String fn = 'test']) async {
    final engine = KSEngine();
    await engine.load(source);
    final result = await engine.invoke(fn);
    expect(result.success, isTrue, reason: result.errors.join('\n'));
    return result.value;
  }

  group('else if chains', () {
    test('picks the right branch across a 4-way chain', () async {
      const source = '''
fn classe(x) {
  if (x > 100) { return "grand" } else if (x > 10) {
    return "moyen"
  } else if (x > 0) { return "petit" } else {
    return "negatif"
  }
}
fn test() {
  return classe(200) + "," + classe(50) + "," + classe(5) + "," + classe(-1)
}
''';
      expect(await run(source), 'grand,moyen,petit,negatif');
    });

    test('else if without a final else', () async {
      const source = '''
fn test() {
  let r = "aucun"
  if (false) { r = "a" } else if (true) { r = "b" }
  return r
}
''';
      expect(await run(source), 'b');
    });

    test('still parses the legacy nested form', () async {
      const source = '''
fn test() {
  if (false) { return "a" } else {
    if (true) { return "b" }
  }
  return "c"
}
''';
      expect(await run(source), 'b');
    });
  });

  group('compound assignment', () {
    test('+= -= *= /= on a variable', () async {
      const source = '''
fn test() {
  let x = 10
  x += 5
  x -= 3
  x *= 4
  x /= 2
  return x
}
''';
      expect(await run(source), 24.0);
    });

    test('+= concatenates strings', () async {
      const source = '''
fn test() {
  let s = "a"
  s += "b"
  return s
}
''';
      expect(await run(source), 'ab');
    });

    test('works on index and property targets', () async {
      const source = '''
fn test() {
  let liste = [1, 2, 3]
  liste[1] += 10
  let obj = { total: 5 }
  obj.total *= 3
  return liste[1] + obj.total
}
''';
      expect(await run(source), 27.0);
    });

    test('mutates a global from inside a function', () async {
      const source = '''
let compteur = 0
fn incr() { compteur += 1 }
fn test() {
  incr()
  incr()
  return compteur
}
''';
      expect(await run(source), 2.0);
    });
  });

  group('integer display', () {
    test('toString renders whole numbers without .0', () async {
      const source = '''
fn test() {
  return toString(3) + "|" + toString(3.5) + "|" + toString(-2) + "|" + toString(0)
}
''';
      expect(await run(source), '3|3.5|-2|0');
    });

    test('interpolation and + concatenation follow the display rule', () async {
      const source = '''
fn test() {
  let n = 7
  return "n=\${n} demi=\${n / 2}" + " brut=" + n
}
''';
      expect(await run(source), 'n=7 demi=3.5 brut=7');
    });

    test('join and print render whole numbers cleanly', () async {
      const source = '''
fn test() {
  return join([1, 2.5, 3], "-")
}
''';
      expect(await run(source), '1-2.5-3');
    });

    test('lists and maps display recursively', () async {
      const source = '''
fn test() {
  return toString([1, 2]) + " " + toString({ a: 1.5, b: 2 })
}
''';
      expect(await run(source), '[1, 2] {a: 1.5, b: 2}');
    });

    test('numeric map keys are coherent between write and read', () async {
      const source = '''
fn test() {
  let m = {}
  m[3] = "x"
  return m["3"] + toString(m[3] == "x")
}
''';
      expect(await run(source), 'xtrue');
    });

    test('jsonStringify keeps the wire format untouched', () async {
      const source = '''
fn test() {
  return jsonStringify({ n: 3 })
}
''';
      expect(await run(source), '{"n":3.0}');
    });
  });

  group('block comments', () {
    test('inline comment inside an expression', () async {
      const source = '''
fn test() {
  return 1 + /* deux */ 2
}
''';
      expect(await run(source), 3.0);
    });

    test('multi-line comment between statements keeps them separated', () async {
      const source = '''
fn test() {
  let a = 1 /* commentaire
  sur plusieurs
  lignes */ let b = 2
  return a + b
}
''';
      expect(await run(source), 3.0);
    });

    test('comment spanning whole lines', () async {
      const source = '''
/*
 * En-tête de fichier.
 */
fn test() {
  /* corps */ return 42
}
''';
      expect(await run(source), 42.0);
    });

    test('unterminated comment reaches EOF without crashing', () async {
      final engine = KSEngine();
      final result = await engine.load('fn test() { return 1 } /* jamais fermé');
      expect(result.success, isTrue);
    });

    test('comment does not hide a division', () async {
      const source = '''
fn test() {
  let a = 10
  a /= 2
  return a / 5
}
''';
      expect(await run(source), 1.0);
    });
  });
}
