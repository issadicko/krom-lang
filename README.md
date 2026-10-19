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
- **100+ Native Functions**: string, math, `range()`, random, type, array, dates, JSON, encoding, crypto

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

### KromScript.eval(source, {limits})
Evaluates a script and returns the result value.

### KromScript.run(source, {variables, limits})
Runs a script with optional variables and returns `ScriptResult`.

### KromScript.builder(source)
Creates a builder for advanced configuration.

### Execution guard

Every entry point runs under `ExecutionLimits()` — an operation budget and a
wall-clock deadline — so an infinite loop fails with a resource error instead of
hanging the host. Tune it, or opt out explicitly for trusted first-party code:

```dart
// Tighter budget than the default.
KromScript.builder(source)
    .withLimits(const ExecutionLimits(deadline: Duration(milliseconds: 200)))
    .execute();

// No budget, no deadline — trusted code only.
KromScript.builder(source).withLimits(ExecutionLimits.unlimited).execute();
```

`withMaxOperations(n)` and `withTimeout(d)` override one bound each and leave the
other at its default.

## Native Functions

| Category | Functions |
|----------|-----------|
| String | `toString`, `toNumber`, `length`, `substring`, `toUpperCase`, `toLowerCase`, `trim`, `split`, `join`, `replace`, `contains`, `startsWith`, `endsWith`, `indexOf` |
| Math | `abs`, `floor`, `ceil`, `round`, `min`, `max`, `pow`, `sqrt`, `sin`, `cos`, `tan`, `log`, `log10`, `exp` |
| Random | `random`, `randomInt`, `randomUUID` |
| Type | `typeOf`, `isNull`, `isNumber`, `isString`, `isBool` |
| Array | `size`, `first`, `last`, `reverse`, `slice`, `sort`, `chunk`, `compact`, `pluck`, `zip`, `fromEntries`, `difference`, `intersection`, `union` |
| Array by key | `groupBy`, `countBy`, `indexBy`, `uniqueBy`, `sumBy`, `minBy`, `maxBy`, `partition` |
| JSON | `jsonParse`, `jsonStringify` |
| Encoding | `base64Encode`, `base64Decode`, `urlEncode`, `urlDecode` |
| Crypto | `md5`, `sha1`, `sha256` |
| Date/Time | `now`, `date`, `time`, `datetime`, `timestamp`, `isDate`, `toISO`, `formatDate`, `parseDate`, `year`, `month`, `day`, `hour`, `minute`, `second`, `dayOfWeek`, `daysInMonth`, `isWeekend`, `addDays`, `addHours`, `addMinutes`, `addSeconds`, `addMonths`, `addYears`, `diffDays`, `diffHours`, `diffMinutes`, `diffMonths`, `diffYears`, `age`, `startOfDay`, `endOfDay`, `startOfMonth`, `endOfMonth` |

### Dates

A date argument is a number (milliseconds since 1970-01-01T00:00:00Z, fraction
truncated toward zero) or ISO text: `YYYY-MM-DD`, or `YYYY-MM-DD` followed by
`T` (or a space) and `HH:mm`, `HH:mm:ss` or `HH:mm:ss.SSS` (up to 9 fraction
digits, kept to milliseconds), with an optional `Z` or `+HH:mm` / `-HH:mm`
zone. Without zone the time is UTC. Fields are validated: `2026-02-29` is not
a date.

Every calendar computation is done in UTC, whatever the host's time zone. A
date function given an unreadable date (`null`, a malformed string, a boolean…)
returns `null` and never raises; a count that is not a number does raise.
Functions that return an instant return milliseconds; `toISO` writes
`YYYY-MM-DDTHH:mm:ss.SSSZ`.

`formatDate` and `parseDate` share the tokens `YYYY`, `YY` (formatting only),
`MM`, `DD`, `HH`, `mm`, `ss` and `SSS`; anything else is copied (formatting) or
must match exactly (parsing). When parsing, each token reads exactly its width
in digits and the whole text must be consumed.

```
formatDate("2026-03-05T07:08:09.045Z", "DD/MM/YY HH:mm:ss.SSS") // "05/03/26 07:08:09.045"
parseDate("19/10/2026 08:05", "DD/MM/YYYY HH:mm")               // 1792397100000
toISO(addMonths("2026-01-31", 1))                               // "2026-02-28T00:00:00.000Z"
age("2000-10-20", "2026-10-19")                                 // 25
```

### Lists

A list argument may be `null`, which behaves as an empty list; any other value
raises. The by-key functions (`groupBy`, `countBy`, …) take a key that is
either a path (`"ville.nom"`: object keys, or list indexes written in digits)
or a function `fn(item, index)`; the empty path `""` is the item itself.

Two values are equal (`union`, `difference`, `uniqueBy`…) when they have the
same type and the same text once keys are sorted: `1` equals `1.0` but not
`"1"`, and `{a: 1, b: 2}` equals `{b: 2, a: 1}`. The objects built by
`groupBy`, `countBy`, `indexBy` and `fromEntries` list their keys in sorted
order.

### Method syntax

Any native and any by-key function can be called as a method, the receiver
becoming the first argument: `items.groupBy("type")`,
`"2026-10-19".addDays(1).toISO()`. A callable member of the receiver wins. Called
by name, a function declared by the script or registered by the host replaces a
builtin of the same name.

## Other Implementations

| Language | Package |
|----------|---------|  
| **Kotlin** | [Maven Central](https://central.sonatype.com/artifact/io.github.issadicko/kodi-script) |
| **Go** | [pkg.go.dev](https://pkg.go.dev/github.com/issadicko/kodi-script-go) |
| **TypeScript** | [npm](https://www.npmjs.com/package/@issadicko/kodi-script) |

## License

MIT
