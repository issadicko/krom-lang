# Changelog

## 1.1.0

### Les dates se lisent en texte ISO et se calculent en UTC

Un argument `date` est un nombre (millisecondes depuis 1970-01-01T00:00:00Z,
fraction tronquée vers zéro) ou un texte ISO : `YYYY-MM-DD`,
`YYYY-MM-DDTHH:mm[:ss[.S…]]` (espace accepté à la place du `T`, fraction
gardée à la milliseconde), suivi au besoin de `Z` ou d'un décalage `+HH:mm`,
`-HH:mm` ou `+HHmm`. Sans zone, l'heure est en UTC.

La lecture est stricte : `DateTime.parse` normalise `2026-02-29` en 1er mars,
elle ne sert donc pas. Le mois, le jour (années bissextiles comprises),
l'heure, la minute et la seconde sont vérifiés ; `2026-02-29` n'est pas une
date.

Les fonctions existantes changent en conséquence :

- `date()`, `time()`, `datetime()`, `year`, `month`, `day`, `hour`, `minute`,
  `second`, `dayOfWeek` calculent en UTC. Elles suivaient le fuseau de l'hôte,
  et un même script donnait deux réponses sur deux machines.
- `timestamp`, `formatDate`, `year`…`dayOfWeek`, `addDays`, `addHours` et
  `diffDays` acceptent un texte ISO, plus seulement des millisecondes.
- Une date illisible donne `null` au lieu de lever : `timestamp("nope")` vaut
  `null`. Un nombre en texte (`"1700000000000"`) n'est plus une date.
- Le nombre de jours ou d'heures de `addDays` / `addHours` doit être un
  nombre ; un texte numérique (`"2"`) est refusé, il était converti.
- `diffDays(a, b)` vaut `trunc((b - a) / 86 400 000)` : négatif quand `b < a`.
- `datetime()` écrit `YYYY-MM-DDTHH:mm:ss.SSSZ`, comme `toISO(now())`.
- `formatDate` connaît `YY` et `SSS` ; la lecture du format se fait de gauche à
  droite, le jeton le plus long l'emporte, le reste est recopié.

### Nouvelles fonctions de date

`parseDate(texte, format)`, `isDate`, `toISO`, `addMonths`, `addYears`,
`addMinutes`, `addSeconds`, `diffHours`, `diffMinutes`, `diffMonths`,
`diffYears`, `age(naissance, [à])`, `startOfDay`, `endOfDay`, `startOfMonth`,
`endOfMonth`, `daysInMonth`, `isWeekend`.

`addMonths` et `addYears` ramènent un jour inexistant au dernier jour du mois
cible (`2026-01-31` + 1 mois = `2026-02-28`). `diffMonths` compte les mois
calendaires entiers, heure du jour comprise. `parseDate` lit chaque jeton sur
sa largeur exacte, exige que le texte soit consommé en entier et rend `null`
pour une date qui n'existe pas (`31/02/2026`).

### Nouvelles fonctions de liste

`chunk`, `compact`, `pluck`, `zip`, `fromEntries`, `difference`,
`intersection`, `union`. Une liste `null` vaut une liste vide ; toute autre
valeur qui n'est pas une liste lève.

Deux valeurs sont égales quand elles ont le même type et le même texte, clés
triées : `1` égale `1.0` mais pas `"1"`, et `{a: 1, b: 2}` égale
`{b: 2, a: 1}`. Un chemin (`"ville.nom"`, `"items.0.id"`) lit une clé d'objet
ou un indice de liste écrit en chiffres ; `""` désigne l'élément lui-même.

### Regroupements par clé

`groupBy`, `countBy`, `indexBy`, `uniqueBy`, `sumBy`, `minBy`, `maxBy` et
`partition` vivent à côté de `map` et `filter` : la clé est un chemin ou une
fonction `fn(item, index)`, et la fonction rappelle le script. Un `sumBy` sur
une clé qui n'est pas un nombre lève ; `minBy` et `maxBy` rendent l'élément, le
premier en cas d'égalité, `null` quand il ne reste aucune clé.

Les objets construits par `groupBy`, `countBy`, `indexBy` et `fromEntries`
rangent leurs clés dans l'ordre trié, l'ordre dans lequel les autres SDK les
affichent. Une fonction déclarée par le script, ou enregistrée par l'hôte, sous
le même nom reste prioritaire.

### Toute native s'appelle comme une méthode

`"2026-10-19".addDays(1).toISO()` et `items.groupBy("type")` s'écrivent
comme `addDays("2026-10-19", 1)` : quand le récepteur n'a aucun membre
appelable de ce nom, l'appel devient `nom(récepteur, args…)`. Un membre
appelable du récepteur reste prioritaire. Un nombre ou un booléen peut
désormais être récepteur, ce qui permet d'enchaîner (`addDays` rend des
millisecondes) ; une méthode inconnue échoue comme avant.

`liste.size()` échouait, `size` étant la propriété, et fonctionne maintenant.

## 1.0.5

### La virgule finale est acceptée dans les tableaux et les appels

Un tableau ou un appel écrit un élément par ligne se termine naturellement par
une virgule ; le parseur la refusait (« no prefix parse function for ] »). Elle
est désormais acceptée, comme elle l'était déjà dans les objets.


## 1.0.4

### Une fonction appelée par son nom peut vivre dans un espace de noms

`invoke`, `invokeSync` et `invokeSynchronized` cherchaient le nom reçu dans
l'environnement, à plat. Un hôte qui passe une fonction par chaîne de
caractères — `builder: "homeTab"`, `onTap: "valider"` — ne pouvait donc
atteindre qu'une déclaration de premier niveau.

Le nom accepte désormais des points : `"homeView.homeTab"` récupère
`homeView`, descend dans la map, et appelle ce qu'il y trouve. Chaque segment
intermédiaire doit être une map ; sinon la résolution échoue proprement sur le
`not found` habituel, ce qui laisse intact le moyen qu'a l'hôte de distinguer
un hook absent d'une vraie erreur.

Un nom sans point suit exactement le chemin d'avant.

Ça ouvre le bundler aux imports scopés : un module compilé en fermeture expose
ses déclarations dans un objet, et ses fonctions restent adressables par nom.

### L'état réactif d'un module reste visible

`reactiveState()` ne voyait que les `Obs` de premier niveau, et ceux d'un
module scopé auraient disparu derrière leur map. Les objets sont maintenant
ouverts d'un niveau et leurs entrées réactives rapportées sous la forme
`module.nom`. `setReactiveValue()` accepte le même chemin, pour qu'un
inspecteur d'état puisse toujours écrire ce qu'il affiche.

### Un alias qui ne vit que dans une chaîne n'est plus supprimé

L'élimination de code mort ne comptait comme usage qu'un identifiant. Une
variable dont la seule référence est une chaîne pointée — `builder:
"homeView.homeTab"`, que l'hôte résout à l'appel — passait donc pour morte et
disparaissait, emportant le module entier.

Une chaîne de la forme `nom.nom` compte désormais comme un usage de son premier
segment. Le motif est strict : une phrase ou un nom de fichier ne garde rien en
vie.

## 1.0.3

### Les erreurs d'exécution disent où (#24)

Le lexer connaît la ligne de chaque jeton depuis toujours ; l'interprète, lui,
levait des `Exception` nues. `undefined variable: total` arrivait donc **sans
la moindre position**, et l'auteur n'avait qu'à relire son fichier. Seules les
erreurs de syntaxe étaient situées.

C'est pire pour une mini-app : le script exécuté est une concaténation, et
c'est la position qui permet à l'hôte de retrouver le fichier d'origine. Sans
elle, toute la chaîne de correspondance en aval reste sans objet.

La position vient de deux endroits :

- **Quand l'interprète détecte l'erreur lui-même**, il connaît l'expression
  fautive et donne sa ligne et sa colonne : identifiant inconnu, propriété sur
  `null`, affectation impossible, indexation, division par zéro, opérateur
  inconnu, arguments de `map`/`filter`/`reduce`/`find`/`findIndex`.
- **Pour les autres erreurs**, celles levées ailleurs — une fonction native, un
  appel sur une valeur qui n'est pas une fonction — l'interprète donne la ligne
  de l'instruction en cours d'exécution.

Quand les deux s'appliquent, la position la plus précise est conservée : une
erreur qui a déjà une position n'est pas réécrite.

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
