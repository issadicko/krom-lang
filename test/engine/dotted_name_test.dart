import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

/// A module compiled the way the bundler emits a scoped `@use`: the file's body
/// runs inside a closure and its top-level declarations come back as a map.
const _scoped = '''
let homeView = fn() {
  let label = "Accueil"
  let count = Obs(0)
  fn homeTab(suffix) { return label + suffix }
  fn bump() { count.set(count.value + 1) }
  return { homeTab: homeTab, bump: bump, count: count, label: label }
}()

let deep = { a: { b: { greet: fn() { return "hi" } } } }

fn page() { return homeView.homeTab("!") }
''';

Future<KSEngine> _loaded([String source = _scoped]) async {
  final engine = KSEngine();
  final result = await engine.load(source, enableOptimizer: false);
  expect(result.success, isTrue, reason: result.errors.join('\n'));
  return engine;
}

void main() {
  group('dotted callback names', () {
    test('invoke reaches a function inside a namespace', () async {
      final engine = await _loaded();
      final result = await engine.invoke('homeView.homeTab', ['!']);
      expect(result.success, isTrue, reason: result.errors.join('\n'));
      expect(result.value, 'Accueil!');
    });

    test('invokeSync reaches a function inside a namespace', () async {
      final engine = await _loaded();
      expect(engine.invokeSync('homeView.homeTab', ['?']), 'Accueil?');
    });

    test('walks more than one level', () async {
      final engine = await _loaded();
      expect(engine.invokeSync('deep.a.b.greet'), 'hi');
    });

    test('plain names are unaffected', () async {
      final engine = await _loaded();
      expect((await engine.invoke('page')).value, 'Accueil!');
    });

    test('a missing segment reports not found, it does not throw', () async {
      final engine = await _loaded();
      final result = await engine.invoke('homeView.nope');
      expect(result.success, isFalse);
      expect(result.errors.first, contains('not found'));
    });

    test('an unknown namespace reports not found', () async {
      final engine = await _loaded();
      final result = await engine.invoke('nope.homeTab');
      expect(result.success, isFalse);
      expect(result.errors.first, contains('not found'));
    });

    test('descending through a non-map is a miss, not a crash', () async {
      final engine = await _loaded();
      final result = await engine.invoke('homeView.label.length');
      expect(result.success, isFalse);
      expect(result.errors.first, contains('not found'));
    });

    test('a namespace entry that is not a function is rejected as such',
        () async {
      final engine = await _loaded();
      final result = await engine.invoke('homeView.label');
      expect(result.success, isFalse);
      expect(result.errors.first, contains('is not a function'));
    });

    test('a lifecycle hook missing from a namespace stays silent', () async {
      // MiniAppEngine.invokeLifecycle keys on "not found" to tell an undefined
      // hook from a real failure; the dotted path must keep that wording.
      final engine = await _loaded();
      final result = await engine.invoke('homeView.onShow');
      expect(result.success, isFalse);
      expect(result.errors.any((e) => e.contains('not found')), isTrue);
    });
  });

  group('reactive state inside a namespace', () {
    test('is reported as namespace.name', () async {
      final engine = await _loaded();
      expect(engine.reactiveState()['homeView.count'], 0);
    });

    test('follows a mutation made through a namespaced call', () async {
      final engine = await _loaded();
      await engine.invoke('homeView.bump');
      expect(engine.reactiveState()['homeView.count'], 1);
    });

    test('can be written back by an inspector', () async {
      final engine = await _loaded();
      expect(engine.setReactiveValue('homeView.count', 7), isTrue);
      expect(engine.reactiveState()['homeView.count'], 7);
    });

    test('writing back an unknown path fails cleanly', () async {
      final engine = await _loaded();
      expect(engine.setReactiveValue('homeView.nope', 1), isFalse);
      expect(engine.setReactiveValue('homeView.label', 'x'), isFalse);
    });

    test('top-level reactives keep their bare name', () async {
      final engine = await _loaded('let total = Obs(3)');
      expect(engine.reactiveState()['total'], 3);
      expect(engine.setReactiveValue('total', 9), isTrue);
      expect(engine.reactiveState()['total'], 9);
    });
  });
}
