# Changelog

## 1.0.3

### Les erreurs d'exécution disent où (#24)

Le lexer connaît la ligne de chaque jeton depuis toujours ; l'interprète, lui,
levait des `Exception` nues. `undefined variable: total` arrivait donc **sans
la moindre position**, et l'auteur n'avait qu'à relire son fichier. Seules les
erreurs de syntaxe étaient situées.

C'est pire pour une mini-app : le script exécuté est une concaténation, et
c'est la position qui permet à l'hôte de retrouver le fichier d'origine. Sans
elle, toute la chaîne de correspondance en aval reste sans objet.

Deux mécanismes, complémentaires :

- **Les sites qui connaissent le nœud fautif le nomment exactement** —
  identifiant inconnu, propriété sur `null`, affectation impossible, indexation,
  division par zéro, opérateur inconnu, arguments de `map`/`filter`/`reduce`/
  `find`/`findIndex`. Ligne **et** colonne.
- **Chaque statement sert de filet** pour le reste : ce qu'aucun site ne nomme —
  une native qui lève, un appel sur ce qui n'est pas une fonction — reçoit au
  moins la ligne du statement en cours. L'imbrication est sans danger : la
  position la plus interne est posée en premier, les cadres extérieurs laissent
  passer une erreur déjà située.

Deux choses restent intactes : un `KromResourceError` (budget, délai) garde son
type, parce que ce n'est pas une faute du code exécuté ; et une erreur qui
portait déjà une position la conserve.

`Statement` et `Expression` déclarent désormais `Token get token` — les
sous-classes stockaient déjà ce jeton, l'exposer suffisait.

**Visible pour l'appelant** : le type change pour les erreurs qui étaient des
`Exception` nues, et devient `KromRuntimeError`. Un hôte qui filtrait sur le
texte du message n'est pas affecté — le message est inchangé, la position s'y
ajoute en suffixe.

## 1.0.2

Six correctifs de justesse et de sûreté (#10 à #15). Le numéro est un correctif,
mais **plusieurs changements sont visibles** : lire la section Migration avant
de monter de version.

### Analyse — sources tronquées rejetées (#12)

Deux sources tronquées passaient la validation à l'analyse :

- **Chaîne non terminée** : le lexeur signale désormais
  `unterminated string literal`, à la ligne et à la colonne du guillemet
  ouvrant, pour les deux styles de guillemets (`"` et `'`). Un guillemet
  échappé (`\"`) ne ferme plus la chaîne par accident.
- **Bloc non fermé** : un bloc qui atteint la fin du fichier sans son `}`
  produit `expected TokenType.rbrace, got TokenType.eof`, exactement comme le
  font déjà `(` et `[`.

Les erreurs lexicales remontent par la liste `Parser.errors()` existante — pas
de seconde API d'erreurs : `KromScript.run`, `KromEngine.load` et tout appel à
`Parser(Lexer(src)).parseProgram()` les voient sans changement côté appelant.

**Impact** — des sources jusqu'ici acceptées puis exécutées sont maintenant
rejetées à l'analyse. C'est l'intention : elles ne pouvaient s'exécuter
qu'avec une sémantique différente de celle écrite.

### Ordre — plus de coercition des opérandes non numériques (#15)

- **Opérateurs d'ordre (`<`, `>`, `<=`, `>=`)** — ils ne coercent plus les
  opérandes non numériques vers `0.0` (#15). `null < 5` répondait `true` :
  dans un moteur de règles, `age < 18` sur un champ non rempli déclenchait une
  validation qui devait rester dormante.

  L'ordre n'est désormais défini que sur les nombres et les chaînes qui se
  parsent comme des nombres. Tout autre opérande — `null`, booléen, map,
  liste, fonction, chaîne non numérique — rend la comparaison indéfinie, et
  une comparaison indéfinie vaut **`false`**, des deux côtés et pour les
  quatre opérateurs. Sur une donnée absente, `age < 18` et `age >= 18` sont
  donc tous les deux faux : aucune règle d'ordre ne se déclenche sur une
  valeur qu'on n'a pas.

  Une chaîne numérique continue de se comparer numériquement (`"10" > 5` vaut
  toujours `true`). L'égalité (`==` / `!=`), l'arithmétique et `sort()` sont
  inchangées.

### Résolution de propriété — null et absent lus comme null (#10, #11)

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

### Garde d'exécution — appliquée par défaut (#13)

- **La garde d'exécution s'applique enfin à `KromScript`.** `ExecutionLimits`
  se documentait « sûr par défaut » mais n'était câblée que dans `KSEngine` :
  `KromScript.eval`, `KromScript.run` et `KromScript.builder(...).execute()`
  s'exécutaient sans budget d'opérations ni deadline, si bien que
  `while (true) { }` figeait l'hôte. Ces trois points d'entrée tournent
  désormais sous `ExecutionLimits()` (10 000 000 opérations, 1 s).
- **Nouveau `KromScriptBuilder.withLimits(ExecutionLimits)`** et paramètre
  nommé `limits` sur `KromScript.run` / `KromScript.eval` : le type documenté
  est maintenant atteignable depuis l'API publique.
- `withMaxOperations()` et `withTimeout()` restent valables — ils *surchargent*
  désormais la borne correspondante au lieu d'être le seul moyen d'en avoir
  une, et réarment la garde si elle avait été désactivée.
- Une seule implémentation de l'application des bornes
  (`ExecutionLimits.applyTo`), partagée par `KromScript` et `KSEngine`, pour
  que les deux chemins ne puissent plus diverger.

**Migration** : un script qui bouclait sans fin échoue maintenant avec
`KromResourceError` au lieu de tourner indéfiniment. Un script légitime reste
très en deçà des bornes. Pour du code de confiance qui doit tourner sans
limite, l'option est explicite : `withLimits(ExecutionLimits.unlimited)` (ou
`limits: ExecutionLimits.unlimited`).

### Représentation numérique — une seule règle, jusqu'au JSON (#14)

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
  sortie de `print()` et l'interpolation sont inchangées elles aussi
  (`print(1 + 1)` affiche toujours `2`).

- **`jsonStringify` suit la même règle** — `jsonStringify({ n: 3 })` rend
  désormais `{"n":3}` au lieu de `{"n":3.0}`, récursivement dans les listes et
  les maps. Cela **révoque la décision de 1.0.0** qui gardait l'encodage JSON
  de Dart au nom du « format réseau préservé ».

  Motif : ce moteur est l'un de trois jumeaux (Go côté serveur, TypeScript côté
  web, Dart côté mobile) qui doivent produire des corps JSON identiques octet
  pour octet. Go et TypeScript sérialisent `2`, pas `2.0` : le format réseau
  que le canon spécifie est bien `2`, et c'était donc la divergence, non la
  préservation. `jsonParse` est déjà canonique (`jsonDecode` rend un `int` pour
  un littéral entier), donc `jsonStringify(jsonParse(s))` fait maintenant un
  aller-retour stable.

### Migration

**#15 — opérateurs d'ordre.** Visible pour un script qui s'appuyait sur l'ancienne coercition :

- `null < 5`, `"abc" < 5`, `true < 5`, `[…] < 5`, `{…} < 5` passent de `true`
  à `false` (et de même dans le sens miroir, `5 > null`, etc.).
- `null <= null` et `"abc" <= "abc"` passent de `true` à `false` : deux
  opérandes non ordonnables ne sont pas « égaux » au sens de l'ordre. Utiliser
  `==` pour tester l'égalité.
- L'identité `!(a < b) == (a >= b)` n'est plus garantie quand un opérande
  n'est pas ordonnable — comme pour `NaN` en IEEE-754 et en JavaScript.

Un script qui doit distinguer « absent » de « comparé » teste explicitement
`x == null` (ou `x ?: valeurParDéfaut`) avant la comparaison.

**#10 / #11 — résolution de propriété.**

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

**#14 — représentation numérique.**

- Un appelant qui écrivait `result.value as double` doit écrire
  `(result.value as num).toDouble()` — de même pour les arguments reçus par un
  `KromBindable.callMethod`, qui arrivent maintenant sous forme canonique.
  Les comparaisons de valeur (`result.value == 2.0`) restent vraies : en Dart
  `2 == 2.0`.
- Qui analyse la sortie de `jsonStringify` en attendant `2.0` doit accepter
  `2`. Un consommateur JSON standard n'est pas concerné : `2` et `2.0` s'y
  décodent sur le même nombre.

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
