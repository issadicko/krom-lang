# KromScript Dart SDK

[![pub package](https://img.shields.io/pub/v/krom_script.svg)](https://pub.dev/packages/krom_script)
[![Release](https://img.shields.io/github/v/release/issadicko/krom-lang)](https://github.com/issadicko/krom-lang/releases)

A lightweight, embeddable scripting language interpreter for Dart/Flutter applications.

📖 **Documentation complète** : [docs-kodiscript.dickode.net](https://docs-kodiscript.dickode.net/)

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  krom_script: ^1.0.0
```

## Quick Start

```dart
import 'package:krom_script/krom_script.dart';

void main() {
  // Simple evaluation
  final result = KromScript.eval('2 + 3 * 4');
  print(result); // 14.0

  // With variables
  final greeting = KromScript.run(
    'greeting + ", " + name + "!"',
    variables: {'greeting': 'Hello', 'name': 'World'},
  );
  print(greeting.value); // "Hello, World!"

  // Capture output
  final output = KromScript.run('''
    let items = ["apple", "banana", "cherry"]
    for (item in items) {
      print(item)
    }
  ''');
  print(output.output); // ["apple", "banana", "cherry"]
}
```

## Features

- **Variables**: `let x = 10`
- **Functions**: `fn(a, b) { return a + b }`
- **Control Flow**: `if` / `else if` / `else`, `for-in` (arrays & maps), `while`, ternary `cond ? a : b`
- **Operators**: arithmetic, comparison, logical, and compound assignment (`+=`, `-=`, `*=`, `/=`)
- **Data Types**: numbers (whole numbers print without a trailing `.0`, and reach the host as an `int` — fractions as a `double`), strings, booleans, arrays, objects
- **Comments**: line `//` and block `/* ... */`
- **Null Safety**: `?.` (safe access), `?:` (elvis operator)
- **Safe by default**: built-in execution guard (op-budget + deadline)
- **48+ Native Functions**: string, math, `range()`, random, type, array, JSON, encoding, crypto

## 🔌 Extensibilité

KromScript est conçu pour être **extensible**. Vous pouvez enrichir le langage en ajoutant vos propres fonctions natives.

### Fonctions personnalisées

```dart
final result = KromScript.builder('greet("Dart")')
    .registerFunction('greet', (args) => 'Hello, ${args[0]}!')
    .execute();

print(result.value); // "Hello, Dart!"
```

### Exemple : intégration Flutter

```dart
class ScriptEngine {
  final UserRepository userRepo;
  final NotificationService notifications;
  
  ScriptEngine(this.userRepo, this.notifications);
  
  Future<ScriptResult> execute(String script, Map<String, dynamic> context) {
    return KromScript.builder(script)
      .withVariables(context)
      .registerFunction('fetchUser', (args) async {
        return await userRepo.findById(args[0] as int);
      })
      .registerFunction('sendPush', (args) {
        notifications.send(
          title: args[0] as String,
          body: args[1] as String,
        );
        return true;
      })
      .registerFunction('calculatePrice', (args) {
        final quantity = args[0] as num;
        final unitPrice = args[1] as num;
        final discount = args.length > 2 ? args[2] as num : 0;
        return quantity * unitPrice * (1 - discount / 100);
      })
      .execute();
  }
}
```

Cela permet à vos utilisateurs d'écrire des scripts puissants tout en gardant le contrôle sur les fonctionnalités exposées.

## API Reference

### KromScript.eval(source)
Evaluates a script and returns the result value.

### KromScript.run(source, {variables})
Runs a script with optional variables and returns `ScriptResult`.

### KromScript.builder(source)
Creates a builder for advanced configuration.

## Native Functions

| Category | Functions |
|----------|-----------|
| String | `toString`, `toNumber`, `length`, `substring`, `toUpperCase`, `toLowerCase`, `trim`, `split`, `join`, `replace`, `contains`, `startsWith`, `endsWith`, `indexOf` |
| Math | `abs`, `floor`, `ceil`, `round`, `min`, `max`, `pow`, `sqrt`, `sin`, `cos`, `tan`, `log`, `log10`, `exp` |
| Random | `random`, `randomInt`, `randomUUID` |
| Type | `typeOf`, `isNull`, `isNumber`, `isString`, `isBool` |
| Array | `size`, `first`, `last`, `reverse`, `slice`, `sort` |
| JSON | `jsonParse`, `jsonStringify` |
| Encoding | `base64Encode`, `base64Decode`, `urlEncode`, `urlDecode` |
| Crypto | `md5`, `sha1`, `sha256` |
| Date/Time | `now`, `date`, `time`, `datetime`, `timestamp`, `formatDate`, `year`, `month`, `day`, `hour`, `minute`, `second`, `dayOfWeek`, `addDays`, `addHours`, `diffDays` |

## Other Implementations

| Language | Package |
|----------|---------|  
| **Kotlin** | [Maven Central](https://central.sonatype.com/artifact/io.github.issadicko/kodi-script) |
| **Go** | [pkg.go.dev](https://pkg.go.dev/github.com/issadicko/kodi-script-go) |
| **TypeScript** | [npm](https://www.npmjs.com/package/@issadicko/kodi-script) |

## License

MIT
