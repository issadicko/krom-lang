# Changelog

## Non publié

### Breaking Changes

- **Une seule représentation numérique à la frontière hôte** (#14). Le type
  Dart d'un nombre ne dépend plus du chemin par lequel le script l'a atteint :
  un nombre entier est un `int`, un nombre fractionnaire un `double`. Avant,
  `m.n` et `m["n"]` rendaient `3` (donnée hôte intacte) alors que `1 + 1` et
  `l.length` rendaient `2.0` et `3.0` (chemin calculé / réflexif) — le même
  champ se sérialisait donc en `3` ou en `3.0` selon qu'un script l'avait
  touché ou non.

  La règle est énoncée une seule fois, dans `lib/src/runtime/numbers.dart`
  (`kromCanonicalNumber` / `kromCanonicalValue`, tous deux exportés), et
  appliquée à chaque passage : variables hôte entrantes, `ScriptResult.value`,
  `KSEngineResult.value`, `KSEngine.invokeSync` / `getVariable` /
  `reactiveState`, et les deux sens de `KromBindable`. `kromDisplay` rend
  désormais les nombres via cette même règle.

  L'arithmétique est inchangée : l'interpréteur calcule toujours en `double`,
  la division, le modulo et les débordements se comportent à l'identique. La
  sortie de `print()` est inchangée elle aussi (`print(1 + 1)` affiche
  toujours `2`), tout comme `jsonStringify`, qui garde son encodage réseau.

### Migration

- Un appelant qui écrivait `result.value as double` doit écrire
  `(result.value as num).toDouble()` — de même pour les arguments reçus par un
  `KromBindable.callMethod`, qui arrivent maintenant sous forme canonique.
  Les comparaisons de valeur (`result.value == 2.0`) restent vraies : en Dart
  `2 == 2.0`.

## 1.0.1

Qualité du paquet (aucun changement d'API ni de comportement) :

- Code entièrement conforme à `dart format`.
- Suppression du code mort signalé par l'analyseur (imports, champs et
  variables locales inutilisés) dans `lib/`, `bin/` et `test/`.
- `path` déclaré en `dev_dependency` (utilisé par les tests).

## 1.0.0

Première version **stable**. API figée, sûreté par défaut et un langage
nettement plus expressif — sur Dart, Kotlin, Go et TypeScript.

### Langage

- **Chaînes `else if`** — plus besoin de `if` imbriqués.
- **Affectations composées** : `+=`, `-=`, `*=`, `/=`.
- **Opérateur ternaire** : `cond ? a : b`.
- **`for-in` sur les maps** — itère sur les clés.
- **Natif `range()`** pour les boucles numériques.
- **Commentaires bloc** `/* ... */`.
- **Affichage des entiers sans `.0`** : `4` au lieu de `4.0`, appliqué à
  `toString`, l'interpolation, `+`, `print`, `join` et aux clés de map
  (`jsonStringify` reste inchangé — format réseau préservé).

### Sûreté

- **Garde d'exécution activée par défaut** : budget d'opérations + deadline,
  pour qu'un script tiers ne puisse pas figer l'hôte. `ExecutionLimits.unlimited`
  reste disponible pour du code de confiance.
- **`print()`** est aussi routé vers la sortie standard, en plus de
  `developer.log`.

### Optimiseur & introspection hôte

- Correction de plusieurs bugs de fausse suppression / transformation
  (propagation de constantes dans les boucles et les closures, inlining
  capturant un paramètre, round-trip du `else` après optimisation).
- Les hooks de cycle de vie (`onInit`/`onShow`/`onHide`/`onDispose`) sont
  préservés au tree-shaking.
- **Introspection réactive** : `reactiveState()` / `setReactiveValue()` pour
  lire et piloter l'état, `lastOpsUsed` / `maxOperations` pour instrumenter
  le budget d'opérations.

### Migration

Rien à migrer depuis 0.2.0 : ces ajouts sont rétrocompatibles.

## 0.2.0

### Breaking Changes

- **Binding API**: Objects passed to `.bind()` must now implement `KromBindable` interface
  - This enables support for **iOS, Android, and Web** platforms
  - Removed dependency on `dart:mirrors` which is not available on these platforms

### Migration Guide

Before (0.1.x):
```dart
// Automatic reflection - no longer supported
class User {
  final String name;
  User(this.name);
  String greet() => "Hello, $name!";
}
final result = KromScript.builder('user.greet()').bind('user', User('Alice')).execute();
```

After (0.2.0):
```dart
class User implements KromBindable {
  final String name;
  User(this.name);
  String greet() => "Hello, $name!";

  @override
  Object? getProperty(String name) => name == 'name' ? this.name : null;

  @override
  Object? callMethod(String name, List<Object?> args) {
    if (name == 'greet') return greet();
    return null;
  }
}
final result = KromScript.builder('user.greet()').bind('user', User('Alice')).execute();
```

## 0.1.1

- Fixed string template parsing for complex expressions
- Improved error messages for undefined variables
- Performance optimizations for repeated script execution

## 0.1.0

- Added `for...in` loop support for iterating over arrays
- Added `while` loop support for conditional iteration
- Added user-defined functions with `fn` keyword
- Enhanced array operations: `map`, `filter`, `reduce`, `find`, `findIndex`
- Added operation limit and timeout for script execution
- Performance improvements via AST caching

## 0.0.1

- 🎉 Initial release
- Variables and expressions
- Null-safety operators (`?.`, `?:`)
- Control flow (if/else)
- Native functions:
  - String manipulation
  - Math operations
  - Crypto (MD5, SHA1, SHA256)
  - JSON parsing/stringify
  - Base64/URL encoding
  - Array operations
- Custom function registration
- Builder pattern API
