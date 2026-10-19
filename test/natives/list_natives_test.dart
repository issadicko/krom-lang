import 'package:krom_script/krom_script.dart';
import 'package:test/test.dart';

Object? ev(String source) => KromScript.eval(source);

/// The text a script prints for [expression], with keys as the language
/// shows them.
String show(String expression) => kromDisplay(ev(expression));

Matcher raises(String message) => throwsA(isA<KromScriptException>()
    .having((e) => e.toString(), 'message', contains(message)));

const ventes = '''
let ventes = [
  {region: "Centre", produit: "Pass", montant: 500},
  {region: "Hauts-Bassins", produit: "Data", montant: 1500},
  {region: "Centre", produit: "Data", montant: 1000},
  {region: "Nord", produit: "Pass", montant: null}
]
''';

void main() {
  group('List argument', () {
    test('null behaves as an empty list', () {
      expect(ev('chunk(null, 2)'), equals([]));
      expect(ev('compact(null)'), equals([]));
      expect(ev('pluck(null, "a")'), equals([]));
      expect(ev('zip(null, [1])'), equals([]));
      expect(ev('fromEntries(null)'), equals({}));
      expect(ev('difference(null, [1])'), equals([]));
      expect(ev('intersection([1], null)'), equals([]));
      expect(ev('union(null, [1], null)'), equals([1]));
      expect(ev('groupBy(null, "a")'), equals({}));
      expect(ev('countBy(null, "a")'), equals({}));
      expect(ev('uniqueBy(null, "a")'), equals([]));
      expect(ev('partition(null, "a")'), equals([[], []]));
      expect(ev('minBy(null, "a")'), isNull);
    });

    test('any other value raises, naming the function', () {
      expect(() => ev('chunk("abc", 2)'),
          raises('chunk requires an array as first argument'));
      expect(() => ev('compact(3)'),
          raises('compact requires an array as first argument'));
      expect(() => ev('pluck({a: 1}, "a")'),
          raises('pluck requires an array as first argument'));
      expect(() => ev('zip([1], "a")'), raises('zip requires an array'));
      expect(() => ev('difference([1], 2)'),
          raises('difference requires an array as second argument'));
      expect(
          () => ev('union([1], 2)'), raises('union requires array arguments'));
      expect(() => ev('groupBy("abc", "x")'),
          raises('groupBy requires an array as first argument'));
      expect(() => ev('sumBy(true, "x")'),
          raises('sumBy requires an array as first argument'));
    });

    test('arguments are never modified', () {
      expect(
          ev('''
        let a = [1, null, 2, 2]
        let b = [2]
        compact(a)
        difference(a, b)
        union(a, b)
        chunk(a, 2)
        zip(a, b)
        [a, b]
      '''),
          equals([
            [1, null, 2, 2],
            [2]
          ]));
    });
  });

  group('chunk', () {
    test('cuts consecutive lists, the last possibly shorter', () {
      expect(
          ev('chunk([1, 2, 3, 4, 5], 2)'),
          equals([
            [1, 2],
            [3, 4],
            [5]
          ]));
      expect(
          ev('chunk([1, 2, 3, 4], 2)'),
          equals([
            [1, 2],
            [3, 4]
          ]));
      expect(
          ev('chunk([1, 2], 5)'),
          equals([
            [1, 2]
          ]));
      expect(ev('chunk([], 2)'), equals([]));
    });

    test('the size is truncated and must be at least 1', () {
      expect(
          ev('chunk([1, 2, 3, 4, 5], 2.7)'),
          equals([
            [1, 2],
            [3, 4],
            [5]
          ]));
      expect(() => ev('chunk([1], 0)'), raises('chunk requires a size'));
      expect(() => ev('chunk([1], 0.5)'), raises('chunk requires a size'));
      expect(() => ev('chunk([1], -1)'), raises('chunk requires a size'));
      expect(() => ev('chunk([1], "2")'), raises('chunk requires a size'));
      expect(() => ev('chunk([1], null)'), raises('chunk requires a size'));
    });
  });

  group('compact, pluck, zip', () {
    test('compact drops null and nothing else', () {
      expect(ev('compact([0, null, "", false, null, []])'),
          equals([0, '', false, []]));
    });

    test('pluck reads a dotted path on each element', () {
      const gens = '''
        let gens = [{nom: "Awa", ville: {nom: "Ouaga"}}, {nom: "Ali"}, {nom: "Ina", ville: {nom: "Bobo"}}]
      ''';
      expect(ev('$gens pluck(gens, "nom")'), equals(['Awa', 'Ali', 'Ina']));
      expect(ev('$gens pluck(gens, "ville.nom")'),
          equals(['Ouaga', null, 'Bobo']));
      expect(ev('$gens pluck(gens, "ville.nom.long")'),
          equals([null, null, null]));
    });

    test('a path step on a list is a zero-based index in digits', () {
      expect(ev('pluck([[1, 2], [3, 4]], "1")'), equals([2, 4]));
      expect(ev('pluck([[1, 2], [3]], "1")'), equals([2, null]));
      expect(ev('pluck([[1, 2]], "01")'), equals([null]));
      expect(ev('pluck([[1, 2]], "-1")'), equals([null]));
      expect(ev('pluck([[1, 2]], "+1")'), equals([null]));
      expect(ev('pluck([[1, 2]], "a")'), equals([null]));
      expect(ev('pluck([{items: [{id: 7}]}], "items.0.id")'), equals([7]));
    });

    test('the empty path designates the element itself', () {
      expect(ev('pluck([1, 2], "")'), equals([1, 2]));
    });

    test('a path that is not a string raises', () {
      expect(() => ev('pluck([{a: 1}], 1)'),
          raises('pluck requires a string path'));
    });

    test('zip stops at the shortest list', () {
      expect(
          ev('zip([1, 2, 3], ["a", "b"])'),
          equals([
            [1, 'a'],
            [2, 'b']
          ]));
      expect(
          ev('zip([1, 2], ["a", "b"], [true, false])'),
          equals([
            [1, 'a', true],
            [2, 'b', false]
          ]));
      expect(
          ev('zip([1, 2])'),
          equals([
            [1],
            [2]
          ]));
      expect(ev('zip()'), equals([]));
    });
  });

  group('fromEntries', () {
    test('builds an object, a later pair wins', () {
      expect(ev('fromEntries([["a", 1], ["b", 2], ["a", 3]])'),
          equals({'a': 3, 'b': 2}));
    });

    test('the key is the canonical text of the value', () {
      expect(
          ev('fromEntries([[1, "x"], [2.0, "y"], [null, "z"], [true, "t"]])'),
          equals({'1': 'x', '2': 'y', 'null': 'z', 'true': 't'}));
    });

    test('an element that is not a pair of at least two raises', () {
      for (final bad in ['[["seul"]]', '[3]', '[[]]', '["ab"]', '[null]']) {
        expect(() => ev('fromEntries($bad)'), raises('fromEntries requires'),
            reason: bad);
      }
      expect(ev('fromEntries([["a", 1, 2]])'), equals({'a': 1}));
    });

    test('the keys are listed in sorted order', () {
      expect(show('fromEntries([["b", 1], ["a", 2]])'), equals('{a: 2, b: 1}'));
    });
  });

  group('Equality of values', () {
    test('1 equals 1.0 but not "1"', () {
      expect(ev('size(union([1], [1.0]))'), equals(1));
      expect(ev('size(union([1], ["1"]))'), equals(2));
      expect(ev('difference([1, "1"], [1.0])'), equals(['1']));
    });

    test('objects are equal whatever the order of their keys', () {
      expect(ev('size(union([{a: 1, b: 2}], [{b: 2, a: 1}]))'), equals(1));
      expect(ev('size(union([{a: 1, b: [1, 2]}], [{b: [2, 1], a: 1}]))'),
          equals(2));
    });

    test('a value of another type is never equal', () {
      expect(
          ev('size(union([null], ["null"], [false], ["false"]))'), equals(4));
      expect(ev('size(union([[1]], ["[1]"]))'), equals(2));
      expect(ev('size(union([{}], ["{}"], [[]]))'), equals(3));
    });
  });

  group('difference, intersection, union', () {
    test('difference keeps the duplicates of the first list, in its order', () {
      expect(ev('difference([1, 2, 2, 3, 4], [2, 4])'), equals([1, 3]));
      expect(ev('difference([3, 1, 3, 2], [2])'), equals([3, 1, 3]));
      expect(ev('difference([1, 2], [])'), equals([1, 2]));
    });

    test(
        'intersection keeps the first occurrence, in the order of the first list',
        () {
      expect(ev('intersection([1, 2, 2, 3], [3, 2, 9])'), equals([2, 3]));
      expect(ev('intersection([3, 2, 1], [1, 2, 3])'), equals([3, 2, 1]));
    });

    test('union keeps the first occurrence in order of appearance', () {
      expect(ev('union([1, 2], [2, 3], [3, 4])'), equals([1, 2, 3, 4]));
      expect(ev('union([3, 1, 3], [2, 1])'), equals([3, 1, 2]));
      expect(ev('union([1, 2])'), equals([1, 2]));
      expect(ev('union()'), equals([]));
    });
  });

  group('groupBy, countBy, indexBy', () {
    test('groupBy puts the items under their key, in list order', () {
      expect(ev('$ventes groupBy(ventes, "region").keys'),
          equals(['Centre', 'Hauts-Bassins', 'Nord']));
      expect(ev('$ventes pluck(groupBy(ventes, "region").Centre, "montant")'),
          equals([500, 1000]));
    });

    test('the group key is the canonical text of the key value', () {
      expect(ev('$ventes groupBy(ventes, "montant").keys'),
          equals(['1000', '1500', '500', 'null']));
      expect(ev('groupBy([true, false, null, 1, 1.0, "1"], "").keys'),
          equals(['1', 'false', 'null', 'true']));
    });

    test('a key function receives the item and its index', () {
      expect(
          ev('groupBy(["a", "b", "c", "d"], fn(x, i) { return i % 2 })'),
          equals({
            '0': ['a', 'c'],
            '1': ['b', 'd']
          }));
    });

    test('countBy counts the items of each key', () {
      expect(ev('$ventes countBy(ventes, "produit")'),
          equals({'Data': 2, 'Pass': 2}));
      expect(
          ev('$ventes countBy(ventes, fn(v) { return (v.montant ?: 0) >= 1000 })'),
          equals({'false': 2, 'true': 2}));
    });

    test('indexBy keeps the last item of a key', () {
      expect(
          ev('$ventes indexBy(ventes, "produit").Pass.region'), equals('Nord'));
      expect(ev('$ventes indexBy(ventes, "produit").Data.region'),
          equals('Centre'));
    });

    test('objects built are listed in sorted key order', () {
      expect(show('$ventes countBy(ventes, "produit")'),
          equals('{Data: 2, Pass: 2}'));
      expect(show('indexBy([{k: "b"}, {k: "a"}], "k")'),
          equals('{a: {k: a}, b: {k: b}}'));
    });
  });

  group('uniqueBy, partition', () {
    test('uniqueBy keeps the first item of each key', () {
      expect(ev('$ventes pluck(uniqueBy(ventes, "region"), "produit")'),
          equals(['Pass', 'Data', 'Pass']));
      expect(ev('uniqueBy([1, 1.0, "1", 2, 1], "")'), equals([1, '1', 2]));
    });

    test('uniqueBy compares keys by value, not by order of keys', () {
      expect(
          ev('uniqueBy([{id: {a: 1, b: 2}}, {id: {b: 2, a: 1}}], "id").length'),
          equals(1));
    });

    test('partition splits on the truthiness of the key', () {
      expect(
          ev('partition([0, 1, null, 2], "")'),
          equals([
            [0, 1, 2],
            [null]
          ]));
      expect(
          ev('$ventes size(partition(ventes, fn(v) { return v.region == "Centre" })[0])'),
          equals(2));
      expect(
          ev('partition([1, 2, 3, 4], fn(x, i) { return i >= 2 })'),
          equals([
            [3, 4],
            [1, 2]
          ]));
    });
  });

  group('sumBy, minBy, maxBy', () {
    test('sumBy adds the key values and skips null', () {
      expect(ev('$ventes sumBy(ventes, "montant")'), equals(3000));
      expect(ev('sumBy([1, 2, 3], "")'), equals(6));
      expect(ev('sumBy([{p: 0.5}, {p: 0.25}], "p")'), equals(0.75));
      expect(ev('$ventes sumBy(ventes, fn(v, i) { return i })'), equals(6));
    });

    test('sumBy of nothing is 0', () {
      expect(ev('sumBy([], "x")'), equals(0));
      expect(ev('sumBy([{x: null}], "x")'), equals(0));
    });

    test('sumBy raises on a key that is not a number', () {
      expect(() => ev('$ventes sumBy(ventes, "region")'),
          raises('sumBy requires numeric keys'));
      expect(() => ev('sumBy([{x: "3"}], "x")'),
          raises('sumBy requires numeric keys'));
      expect(() => ev('sumBy([{x: true}], "x")'),
          raises('sumBy requires numeric keys'));
    });

    test('minBy and maxBy return the item, not the key', () {
      expect(ev('$ventes maxBy(ventes, "montant").produit'), equals('Data'));
      expect(ev('$ventes minBy(ventes, "montant").produit'), equals('Pass'));
      expect(ev('$ventes maxBy(ventes, "region").region'), equals('Nord'));
    });

    test('numbers compare numerically, anything else by text', () {
      expect(ev('maxBy([{n: 9}, {n: 10}, {n: 2}], "n").n'), equals(10));
      expect(ev('maxBy([{n: "9"}, {n: "10"}], "n").n'), equals('9'));
      expect(ev('minBy([{n: "b"}, {n: "a"}], "n").n'), equals('a'));
    });

    test('null keys are skipped, the first item wins on ties', () {
      expect(
          ev('maxBy([{n: null, id: 0}, {n: 1, id: 1}, {n: 1, id: 2}], "n").id'),
          equals(1));
      expect(ev('minBy([{n: 2, id: 0}, {n: 1, id: 1}, {n: 1, id: 2}], "n").id'),
          equals(1));
    });

    test('nothing left gives null', () {
      expect(ev('minBy([], "x")'), isNull);
      expect(ev('maxBy([{x: null}], "x")'), isNull);
    });
  });

  group('Key argument', () {
    test('anything but a path or a function raises', () {
      for (final key in ['3', 'null', 'true', '[]', '{}']) {
        for (final name in ['groupBy', 'countBy', 'indexBy', 'uniqueBy']) {
          expect(() => ev('$name([{a: 1}], $key)'),
              raises('$name requires a path string or a function as key'),
              reason: '$name $key');
        }
      }
    });

    test('a list that is not a list is reported before the key', () {
      expect(() => ev('groupBy("abc", 3)'),
          raises('groupBy requires an array as first argument'));
    });

    test('two arguments are required', () {
      expect(() => ev('groupBy([1])'), raises('groupBy requires 2 arguments'));
      expect(() => ev('groupBy([1], "a", "b")'),
          raises('groupBy requires 2 arguments'));
    });

    test('an error raised by the key function goes through', () {
      expect(() => ev('groupBy([1], fn(x) { return x.a.b })'),
          throwsA(isA<KromScriptException>()));
    });
  });

  group('Method syntax', () {
    test('natives and builtins are available as methods', () {
      expect(ev('[1, 2, 3, 4, 5].chunk(2).size()'), equals(3));
      expect(ev('$ventes ventes.groupBy("produit").Data.size()'), equals(2));
      expect(ev('$ventes ventes.sumBy("montant")'), equals(3000));
      expect(
          ev('[1, null, 2].compact().chunk(1)'),
          equals([
            [1],
            [2]
          ]));
      expect(ev('[[1, 2], [3, 4]].pluck("0")'), equals([1, 3]));
    });

    test('a callable member of the receiver wins', () {
      expect(ev('''
        let outils = {chunk: fn(x) { return "à moi" }}
        outils.chunk(1)
      '''), equals('à moi'));
    });

    test('a member that is not callable falls back on the function', () {
      expect(ev('[1, 2, 3].size()'), equals(3));
      expect(ev('"abc".length()'), equals(3));
      expect(ev('let m = {size: 7}\nm.size()'), equals(1));
    });

    test('a method that does not exist still fails', () {
      expect(() => ev('[1].inconnue()'), throwsA(isA<KromScriptException>()));
      expect(
          () => ev('{a: 1}.inconnue()'), throwsA(isA<KromScriptException>()));
      expect(() => ev('let n = 3\nn.inconnue()'),
          throwsA(isA<KromScriptException>()));
      expect(() => ev('let n = null\nn.chunk(1)'),
          raises("cannot access property 'chunk' on null"));
    });

    test('the existing list methods are untouched', () {
      expect(ev('[1, 2, 3].map(fn(x) { return x * 2 })'), equals([2, 4, 6]));
      expect(ev('[1, 2, 3].filter(fn(x) { return x > 1 })'), equals([2, 3]));
    });
  });

  group('Shadowing', () {
    test('a function declared by the script replaces a builtin', () {
      expect(ev('''
        fn partition(list, key) { return "à moi" }
        partition([1], "")
      '''), equals('à moi'));
      expect(ev('''
        let groupBy = fn(a, b) { return 42 }
        groupBy([1], "x")
      '''), equals(42));
    });

    test('a function declared by the script replaces a native', () {
      expect(ev('''
        fn chunk(list, n) { return "à moi" }
        chunk([1], 1)
      '''), equals('à moi'));
    });

    test('a function registered by the host replaces a builtin', () {
      final result = KromScript.builder('groupBy([1], "x")')
          .registerFunction('groupBy', (args) => 'hôte')
          .execute();
      expect(result.value, equals('hôte'));
    });

    test('and also when it is called as a method', () {
      final result = KromScript.builder('[1].groupBy("x")')
          .registerFunction('groupBy', (args) => 'hôte ${args.length}')
          .execute();
      expect(result.value, equals('hôte 2'));
    });
  });
}
