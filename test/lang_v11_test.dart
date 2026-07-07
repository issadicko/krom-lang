import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';
import 'package:krom_script/src/optimizer/optimizer.dart';

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

  group('ternary operator', () {
    test('picks the right branch', () async {
      const source = '''
fn test() {
  let actif = true
  return (actif ? "on" : "off") + (2 > 3 ? "a" : "b")
}
''';
      expect(await run(source), 'onb');
    });

    test('nests to the right and mixes with elvis', () async {
      const source = '''
fn classe(x) {
  return x > 100 ? "grand" : x > 10 ? "moyen" : "petit"
}
fn test() {
  let nom = null
  return classe(200) + classe(50) + classe(5) + (nom ?: "anonyme" ) + (nom != null ? "!" : "?")
}
''';
      expect(await run(source), 'grandmoyenpetitanonyme?');
    });

    test('works inside object literals and call arguments', () async {
      const source = '''
fn test() {
  let actif = false
  let props = { color: actif ? "green" : "grey", size: actif ? 20 : 12 }
  return props.color + toString(props.size) + toString(max(actif ? 1 : 2, 0))
}
''';
      expect(await run(source), 'grey122');
    });

    test('branches are lazy — only the taken side runs', () async {
      const source = '''
let traces = ""
fn gauche() { traces += "G" return "g" }
fn droite() { traces += "D" return "d" }
fn test() {
  let r = true ? gauche() : droite()
  return r + traces
}
''';
      expect(await run(source), 'gG');
    });

    test('multiline with the operator at end of line', () async {
      const source = '''
fn test() {
  let solde = 150
  return solde > 100 ?
    "confortable" :
    "juste"
}
''';
      expect(await run(source), 'confortable');
    });

    test('truthiness: 0 and "" are truthy, null/false are not', () async {
      const source = '''
fn test() {
  return (0 ? "a" : "b") + ("" ? "c" : "d") + (null ? "e" : "f") + (false ? "g" : "h")
}
''';
      expect(await run(source), 'acfh');
    });

    test('interpolation accepts ternaries', () async {
      const source = '''
fn test() {
  let n = 5
  return "\${n > 3 ? "beaucoup" : "peu"}"
}
''';
      expect(await run(source), 'beaucoup');
    });

    test('survives the full optimizer + printer round-trip', () async {
      const source = '''
let seuil = 100
fn etat(x) {
  return x > seuil ? "haut" : "bas"
}
fn build() {
  return { label: etat(150), mode: true ? "a" : "b" }
}
''';
      final program = Parser(Lexer(source)).parseProgram();
      final optimized = Optimizer().optimize(program);
      final printed = ASTPrinter().print(optimized);

      // The printed output must re-parse and behave identically.
      final engine = KSEngine();
      final load = await engine.load(printed);
      expect(load.success, isTrue, reason: 'reprinted source: $printed');
      final r = await engine.invoke('build');
      expect(r.success, isTrue, reason: r.errors.join('\n'));
      expect((r.value as Map)['label'], 'haut');
      // Constant folding: `true ? "a" : "b"` must have been folded to "a".
      expect((r.value as Map)['mode'], 'a');
      expect(printed.contains('true ?'), isFalse,
          reason: 'literal-condition ternary should be folded away');
    });
  });

  group('for over maps + range', () {
    test('for iterates map keys', () async {
      const source = '''
fn test() {
  let m = { a: 1, b: 2, c: 3 }
  let total = 0
  let cles = []
  for (k in m) {
    cles.add(k)
    total += m[k]
  }
  return join(cles, "") + toString(total)
}
''';
      expect(await run(source), 'abc6');
    });

    test('body can mutate the map safely (keys are snapshotted)', () async {
      const source = '''
fn test() {
  let m = { a: 1, b: 2 }
  for (k in m) {
    m[k + "x"] = 9
  }
  return toString(m.ax) + toString(m.bx)
}
''';
      expect(await run(source), '99');
    });

    test('for on a non-iterable still errors', () async {
      final engine = KSEngine();
      await engine.load('fn test() { for (x in 42) { } }');
      final r = await engine.invoke('test');
      expect(r.success, isFalse);
    });

    test('range: one, two and three arguments', () async {
      const source = '''
fn test() {
  return join(range(3), ",") + "|" + join(range(2, 5), ",") + "|" + join(range(10, 0, -3), ",")
}
''';
      expect(await run(source), '0,1,2|2,3,4|10,7,4,1');
    });

    test('range guards: zero step and oversized ranges throw', () async {
      final engine = KSEngine();
      await engine.load('''
fn zeroStep() { return range(0, 10, 0) }
fn tooBig() { return range(2000000) }
''');
      expect((await engine.invoke('zeroStep')).success, isFalse);
      expect((await engine.invoke('tooBig')).success, isFalse);
    });

    test('range powers indexed loops', () async {
      const source = '''
fn test() {
  let liste = ["a", "b", "c"]
  let out = ""
  for (i in range(liste.length)) {
    out += toString(i) + liste[i]
  }
  return out
}
''';
      expect(await run(source), '0a1b2c');
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
