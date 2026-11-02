import 'package:krom_script/krom_script.dart';
import 'package:test/test.dart';

Object? ev(String source) => KromScript.eval(source);

String show(String expression) => kromDisplay(ev(expression));

Matcher raises(String message) => throwsA(isA<KromScriptException>()
    .having((e) => e.toString(), 'message', contains(message)));

void main() {
  group('sum and avg', () {
    test('add up numbers, integral results without .0', () {
      expect(ev('sum([1, 2, 3, 4])'), 10);
      expect(ev('sum([0.5, 0.25])'), 0.75);
      expect(ev('avg([2, 4, 6])'), 4);
      expect(ev('avg([1, 2])'), 1.5);
    });

    test('an empty or null list gives 0', () {
      expect(ev('sum([])'), 0);
      expect(ev('sum(null)'), 0);
      expect(ev('avg([])'), 0);
    });

    // A form totals rows where some have no amount yet: null counts as 0, as
    // it does in arithmetic, and the TypeScript twin gives the same total.
    test('null counts as 0', () {
      expect(ev('sum(map([{t: 200}, {t: 50}, {q: 4}], fn(l) { return l.t }))'),
          250);
      expect(ev('avg([2, null])'), 1);
    });

    test('anything but numbers raises', () {
      expect(() => ev('sum([1, "a"])'),
          raises('sum requires an array of numbers'));
      expect(() => ev('sum("abc")'), raises('sum requires an array'));
    });

    test('read as methods', () {
      expect(ev('[1, 2, 3].sum()'), 6);
      expect(ev('[2, 4].avg()'), 3);
    });
  });

  group('unique, flatten, push, concat', () {
    test('unique keeps the first of equal values', () {
      expect(show('unique([1, 1, 2, 3, 3])'), '[1, 2, 3]');
      expect(ev('unique([1, "1", 1.0])'), equals([1, '1']));
      expect(show('unique([{a: 1, b: 2}, {b: 2, a: 1}])'), '[{a: 1, b: 2}]');
    });

    test('flatten goes one level deep', () {
      expect(show('flatten([1, [2, [3]], []])'), '[1, 2, [3]]');
      expect(ev('flatten(null)'), equals([]));
    });

    test('push returns a new list and leaves the argument alone', () {
      expect(show('''
let a = [1]
let b = push(a, 2, 3)
[a, b]
'''), '[[1], [1, 2, 3]]');
      expect(show('push(null, 1)'), '[1]');
      expect(
          () => ev('push([1])'), raises('push requires at least 2 arguments'));
    });

    test('concat joins lists, null being empty', () {
      expect(show('concat([1], [2, 3], null, [])'), '[1, 2, 3]');
      expect(ev('concat()'), equals([]));
      expect(() => ev('concat([1], 2)'),
          raises('concat requires array arguments'));
    });
  });

  group('sortBy', () {
    const lignes = '''
let lignes = [
  {nom: "b", montant: 10, ville: {nom: "Ouaga"}},
  {nom: "a", montant: 2, ville: {nom: "Bobo"}},
  {nom: "c", montant: 10, ville: {nom: "Koudougou"}}
]
''';

    test('sorts numbers numerically and text by its characters', () {
      expect(ev('${lignes}pluck(sortBy(lignes, "montant"), "nom")'),
          equals(['a', 'b', 'c']));
      expect(ev('${lignes}pluck(sortBy(lignes, "nom"), "nom")'),
          equals(['a', 'b', 'c']));
    });

    test('desc reverses the order, ties keep theirs', () {
      expect(ev('${lignes}pluck(sortBy(lignes, "montant", "desc"), "nom")'),
          equals(['b', 'c', 'a']));
    });

    test('reads a dotted path', () {
      expect(ev('${lignes}pluck(sortBy(lignes, "ville.nom"), "nom")'),
          equals(['a', 'c', 'b']));
    });

    test('refuses an unknown order', () {
      expect(() => ev('sortBy([], "a", "up")'),
          raises('sortBy order must be "asc" or "desc"'));
    });
  });

  group('keys, values, entries, has', () {
    test('keys come sorted, values and entries follow them', () {
      expect(ev('keys({b: 2, a: 1, c: 3})'), equals(['a', 'b', 'c']));
      expect(show('values({b: 2, a: 1})'), '[1, 2]');
      expect(
          ev('entries({b: 2, a: 1})'),
          equals([
            ['a', 1],
            ['b', 2]
          ]));
    });

    // A value not loaded yet reads as having no keys.
    test('null is an empty object', () {
      expect(ev('keys(null)'), equals([]));
      expect(ev('values(null)'), equals([]));
      expect(ev('entries(null)'), equals([]));
      expect(ev('has(null, "a")'), isFalse);
    });

    test('anything else raises', () {
      expect(() => ev('keys([1])'), raises('keys requires an object argument'));
      expect(() => ev('has(3, 1)'),
          raises('has requires an object or array as first argument'));
    });

    test('has reads a key of an object, a value of a list', () {
      expect(ev('has({a: null}, "a")'), isTrue);
      expect(ev('has({a: 1}, "b")'), isFalse);
      expect(ev('has([1, 2, 3], 2)'), isTrue);
      expect(ev('has([1, 2, 3], "2")'), isFalse);
      expect(ev('has([1.0], 1)'), isTrue);
      expect(() => ev('has({a: 1}, 1)'),
          raises('has requires a string key for objects'));
    });
  });

  group('parseInt and parseFloat', () {
    test('read text and numbers', () {
      expect(ev('parseInt("42")'), 42);
      expect(ev('parseInt(" 3.9 ")'), 3);
      expect(ev('parseInt("-3.9")'), -3);
      expect(ev('parseInt(7.8)'), 7);
      expect(ev('parseFloat("2.5")'), 2.5);
      expect(ev('parseFloat(3)'), 3);
    });

    test('refuse what is not a number', () {
      expect(() => ev('parseInt("12px")'),
          raises("cannot parse '12px' as integer"));
      expect(() => ev('parseFloat("x")'), raises("cannot parse 'x' as number"));
      expect(() => ev('parseInt(null)'),
          raises('parseInt requires a string or number'));
    });
  });

  group('regexMatch and regexReplace', () {
    test('a match anywhere, unless anchored', () {
      expect(ev(r'regexMatch("tel 70112233", "\\d{8}")'), isTrue);
      expect(ev(r'regexMatch("tel 70112233", "^\\d{8}$")'), isFalse);
    });

    test('replaces every match, with groups', () {
      expect(ev(r'regexReplace("70 11 22 33", "\\s", "")'), '70112233');
      expect(
          ev(r'regexReplace("2026-10-23", "(\\d+)-(\\d+)-(\\d+)", "$3/$2/$1")'),
          '23/10/2026');
      expect(ev(r'regexReplace("a", "a", "$$1")'), r'$1');
      expect(
          ev(r'regexReplace("Awa", "(?<p>\\w+)", "$<p>! ($&)")'), 'Awa! (Awa)');
    });

    test('an invalid pattern raises', () {
      expect(() => ev('regexMatch("a", "(")'), raises('invalid regex'));
    });
  });

  group('some, every, flatMap', () {
    test('some and every test each item with its index', () {
      expect(ev('some([1, 5, 3], fn(x) { return x > 4 })'), isTrue);
      expect(ev('some([1, 2], fn(x) { return x > 4 })'), isFalse);
      expect(ev('every([5, 6], fn(x) { return x > 4 })'), isTrue);
      expect(ev('every([5, 1], fn(x) { return x > 4 })'), isFalse);
      expect(ev('some([0, 0, 7], fn(x, i) { return i == 2 })'), isTrue);
    });

    test('an empty or absent list: nothing found, nothing contradicts', () {
      expect(ev('some([], fn(x) { return true })'), isFalse);
      expect(ev('some(null, fn(x) { return true })'), isFalse);
      expect(ev('every([], fn(x) { return false })'), isTrue);
      expect(ev('every(null, fn(x) { return false })'), isTrue);
    });

    test('flatMap maps then flattens one level', () {
      expect(show('flatMap([1, 2], fn(x) { return [x, x * 10] })'),
          '[1, 10, 2, 20]');
      expect(show('flatMap([1, 2], fn(x) { return x })'), '[1, 2]');
      expect(ev('flatMap(null, fn(x) { return x })'), equals([]));
    });
  });
}
