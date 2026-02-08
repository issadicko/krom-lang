# KromLang Optimizer

L'**Optimizer** est un module d'optimisation qui transforme l'AST (Abstract Syntax Tree) pour améliorer les performances à l'exécution.

## Activation

```dart
final result = await engine.load(source, enableOptimizer: true);
```

## Optimisations Implémentées

### 1. Constant Folding - Arithmétique

Évalue les expressions numériques constantes à la compilation.

| Expression | Avant | Après |
|------------|-------|-------|
| `1 + 2 + 3` | `BinaryExpr(+, BinaryExpr(+, 1, 2), 3)` | `NumberLiteral(6)` |
| `10 * 2 / 4` | `BinaryExpr(/, BinaryExpr(*, 10, 2), 4)` | `NumberLiteral(5)` |
| `15 % 4` | `BinaryExpr(%, 15, 4)` | `NumberLiteral(3)` |
| `-5` | `UnaryExpr(-, 5)` | `NumberLiteral(-5)` |

**Opérateurs supportés**: `+`, `-`, `*`, `/`, `%`

---

### 2. Constant Folding - Comparaisons

Évalue les comparaisons numériques constantes.

| Expression | Résultat |
|------------|----------|
| `5 > 3` | `true` |
| `10 <= 10` | `true` |
| `3 == 4` | `false` |
| `3 != 4` | `true` |

**Opérateurs supportés**: `<`, `>`, `<=`, `>=`, `==`, `!=`

---

### 3. Constant Folding - Chaînes

Concatène les chaînes littérales à la compilation.

```javascript
// Avant
let msg = "Hello, " + "World" + "!"

// Après optimisation
let msg = "Hello, World!"
```

---

### 4. Constant Folding - Booléens

Évalue les expressions logiques constantes.

| Expression | Résultat |
|------------|----------|
| `true && false` | `false` |
| `true \|\| false` | `true` |
| `!true` | `false` |
| `true == false` | `false` |

**Opérateurs supportés**: `&&`, `||`, `!`, `==`, `!=`

---

### 5. Dead Code Elimination - If Statements

Élimine les branches mortes quand la condition est constante.

```javascript
// Avant
if (true) {
  print("always")
} else {
  print("never")
}

// Après optimisation
{
  print("always")
}
```

```javascript
// Condition fausse → branch alternative ou bloc vide
if (false) {
  print("never")
}
// Après: bloc vide {}
```

---

### 6. Template String Folding

Fusionne les templates contenant uniquement des littéraux.

```javascript
// Avant
let x = "Val: ${"ue"}"  // StringTemplate avec 2 parts

// Après optimisation
let x = "Val: ue"       // StringLiteral simple
```

---

## Récursion Automatique

L'Optimizer traverse **tout l'AST** récursivement:

- ✅ `ExpressionStatement`
- ✅ `BlockStatement`
- ✅ `ReturnStatement`
- ✅ `VarDecl`
- ✅ `IfStatement`
- ✅ `WhileStatement`
- ✅ `ForStatement`
- ✅ `FunctionDeclaration`
- ✅ `FunctionLiteral`
- ✅ `CallExpr` (arguments optimisés)
- ✅ `ArrayLiteral` (éléments optimisés)
- ✅ `ObjectLiteral` (valeurs optimisées)
- ✅ `IndexExpr`
- ✅ `PropertyAccessExpr`
- ✅ `SafeAccessExpr`
- ✅ `ElvisExpr`
- ✅ `Assignment`

---

## Limitations Actuelles

| Non supporté | Raison |
|--------------|--------|
| Inlining de fonctions | Complexité d'analyse |
| Loop unrolling | Nécessite analyse de bornes |
| Common subexpression elimination | Nécessite analyse de flux |
| Constant propagation | Nécessite suivi des variables |

---

## Architecture

```
┌─────────────────────────────────────────┐
│              Optimizer                  │
├─────────────────────────────────────────┤
│  optimize(Program) → Program            │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ _optimizeStatement(Statement)     │  │
│  │  • Parcourt récursivement         │  │
│  │  • Détecte If(constant) → DCE     │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ _optimizeExpression(Expression)   │  │
│  │  • Constant folding               │  │
│  │  • Template merging               │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

## Exemple Complet

```javascript
// Code source
let result = (1 + 2) * 3 + (10 / 2)
let message = "Sum: " + "15"
if (5 > 3) {
  print(message)
}
```

```javascript
// Après optimisation
let result = 14.0
let message = "Sum: 15"
{
  print(message)
}
```

**Gains**: Aucun calcul arithmétique ni concaténation à l'exécution.
