# Changelog

## Non publié

### Correctifs

- **Propriété nulle ou absente** — `m.vide` et `m.absent` valent désormais
  `null` au lieu de lever `cannot access property … : object must implement
  KromBindable` (#10). La résolution répondait sur la *valeur* : un `null`
  légitime était indistinguable d'une propriété introuvable et repartait vers
  le chemin réflexif, qui lève sur une map. Elle répond maintenant sur la
  *présence* — `KromRuntimeType.hasProperty`, que le handler des maps résout
  par `containsKey`. Comme ailleurs dans le langage, une propriété absente
  vaut `null` : fausse en condition, rattrapable par `?:`.

- **Objets liés (`KromBindable`)** — lire une propriété déclarée qui vaut
  `null` renvoyait un `NativeFunctionValue`, l'emballage de méthode. Cet objet
  est vrai en condition et se retrouvait tel quel dans les données de l'hôte —
  une valeur calculée a écrit une fonction dans un corps JSON envoyé à un
  serveur (#10). L'emballage n'est plus construit qu'en position d'appel
  (`p.methode()`) ; une lecture simple vaut `null`. `Obs(null).value` vaut donc
  `null`, et `RxList().first` sur une liste vide aussi.

- **`?.` ne résolvait que sur les maps** (#11) : `l?.length` valait `null` là
  où `l.length` valait `3`, silencieusement. `?.` effectue désormais exactement
  la même résolution que `.` — maps, listes, chaînes, objets liés, méthodes
  comprises — et ne court-circuite que sur un receveur `null`. `a?.b` et `a.b`
  ne diffèrent plus que sur ce point.

### Migration

- Un code qui s'appuyait sur la levée d'exception pour détecter une propriété
  manquante reçoit maintenant `null`. C'est l'objet du correctif, mais le
  changement est visible : tester `x == null`, ou `x ?: défaut`.
- `?.` sur un receveur qui n'expose rien (nombre, booléen, objet hôte non
  `KromBindable`) lève désormais comme `.`, au lieu de valoir silencieusement
  `null`. Seul un receveur `null` court-circuite.
- Une méthode d'objet lié lue comme valeur (`p.methode` sans appel, pour la
  passer en callback) vaut `null` : l'appeler directement, ou l'envelopper
  dans une lambda `fn(x) { p.methode(x) }`.
- Le contournement qui réécrivait `bloc.champ` en `bloc?.champ` pour obtenir
  un `null` n'a plus lieu d'être.

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
