import 'package:test/test.dart';
import 'package:krom_script/krom_script.dart';

void main() {
  test('should parse array as function argument in nested structure', () {
    final source = '''
let Row = fn(props, children) {
  return { type: "Row", children: children }
}

let IconButton = fn(name, props) {
  return { type: "IconButton", name: name }
}

let Box = fn(props, child) {
  return { type: "Box", child: child }
}

let Icon = fn(name, props) {
  return { type: "Icon", name: name }
}

fn build() {
  return Row({ spacing: 12 }, [
    IconButton("refresh", { size: 24, color: "black", onTap: "onRefresh" }),
    Box({ width: 48, height: 48, borderRadius: 24, color: "black" }, 
      Icon("person", { size: 24, color: "white" })
    )
  ])
}
''';

    final engine = KSEngine();
    expect(() => engine.load(source), returnsNormally);

    final result = engine.invoke('build');
    expect(result, isNotNull);
    print('Result: $result');
  });
}
