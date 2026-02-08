# KromLang Resolver - Résolution Statique des Variables

Le **Resolver** effectue une analyse statique de l'AST pour pré-calculer les distances de scope des variables, permettant des accès O(1) à l'exécution.

## Activation

Le Resolver est **automatiquement exécuté** lors du `load()` :

```dart
await engine.load(source);  // Resolver.resolve() appelé automatiquement
```

## Comment ça fonctionne

### 1. Analyse au Parse Time

```
┌─────────────────────────────────────────────────┐
│  load(source)                                   │
│   ├── Parse → AST                               │
│   ├── Resolver.resolve(AST) ← Analyse statique  │
│   ├── [Optimizer.optimize(AST)]                 │
│   └── Interpreter.eval(AST)                     │
└─────────────────────────────────────────────────┘
```

### 2. Calcul des Distances

Le Resolver parcourt l'AST et calcule la **distance** entre chaque utilisation de variable et sa déclaration :

```javascript
let x = 10              // Scope 0
{
  let y = 20            // Scope 1
  {
    let z = 30          // Scope 2
    print(x)            // distance = 2  (x est 2 scopes au-dessus)
    print(y)            // distance = 1  (y est 1 scope au-dessus)
    print(z)            // distance = 0  (z est dans ce scope)
  }
}
```

### 3. Stockage dans l'Interpreter

```dart
// Resolver appelle:
interpreter.resolve(identifierExpr, distance);

// Stocké dans:
_locals[identifierExpr] = distance;  // Map<Expression, int>
```

### 4. Lookup Optimisé à l'Exécution

```dart
// Au lieu de: (O(n) - parcourt la chaîne de scopes)
_env.get(name);

// On fait: (O(1) - accès direct)
_env.getAt(distance, name);
```

---

## Support des Closures

Le Resolver gère correctement les closures grâce au calcul lexical des distances:

```javascript
let makeCounter = fn() {
  let count = 0           // Scope de makeCounter
  return fn() {           // Closure
    count = count + 1     // distance = 1 (count est 1 scope au-dessus)
    return count
  }
}

let counter = makeCounter()
counter()  // → 1
counter()  // → 2
```

**Fonctionnement**:

1. `count` est résolu avec `distance = 1` au parse time
2. Quand la closure est appelée, `_applyFunction` crée un environnement qui étend la closure capturée
3. `getAt(1, "count")` remonte correctement d'un niveau pour trouver `count`

---

## Éléments Résolus

| Type | Résolution |
|------|------------|
| `Identifier` | Distance calculée vers la déclaration |
| `Assignment` | Cible (left) et valeur résolues |
| `VarDecl` | Variable déclarée puis définie |
| `FunctionDeclaration` | Paramètres déclarés dans nouveau scope |
| `FunctionLiteral` | Idem |
| `ForStatement` | Variable d'itération dans son propre scope |
| `BlockStatement` | Nouveau scope créé |

---

## Gestion des Scopes

```dart
void _beginScope() {
  _scopes.add({});  // Nouveau scope vide
}

void _endScope() {
  _scopes.removeLast();  // Ferme le scope
}

void _declare(Token name) {
  _scopes.last[name.literal] = false;  // Déclaré mais pas initialisé
}

void _define(Token name) {
  _scopes.last[name.literal] = true;   // Initialisé
}
```

---

## Fallback pour Variables Non-Résolues

Si une variable n'est pas dans `_locals` (natives, globales), le lookup standard est utilisé:

```dart
case Identifier():
  if (_locals.containsKey(expr)) {
    final value = _lookupVariable(expr.value, expr);
    if (value != null) return value;
  }
  // Fallback: lookup standard
  final (value, found) = _env.get(expr.value);
```

---

## Comparaison de Performance

| Méthode | Complexité | Description |
|---------|------------|-------------|
| `_env.get(name)` | O(n) | Parcourt n scopes parents |
| `_env.getAt(distance, name)` | O(1) | Accès direct au bon scope |

**Gains significatifs** pour les scripts avec:

- Closures imbriquées
- Boucles accédant à des variables externes
- Fonctions récursives

---

## Détection d'Erreurs (Future)

Le Resolver peut détecter:

- ❌ Variable utilisée dans son propre initializer (`let x = x + 1`)
- ❌ Variable redéclarée dans le même scope
- ❌ `return` en dehors d'une fonction

> Ces validations sont préparées mais les erreurs ne sont pas encore levées.
