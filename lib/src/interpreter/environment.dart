/// Environment holds variable bindings.
class Environment {
  final Environment? _outer;
  final Map<String, Object?> _store = {};
  final List<String> _output = [];

  Environment([this._outer]);

  (Object?, bool) get(String name) {
    if (_store.containsKey(name)) {
      return (_store[name], true);
    }
    return _outer?.get(name) ?? (null, false);
  }

  void set(String name, Object? value) {
    _store[name] = value;
  }

  /// Updates a variable in the scope where it was originally defined.
  ///
  /// Searches up the scope chain to find where the variable exists,
  /// then updates it there. If not found, sets it in the current scope.
  bool update(String name, Object? value) {
    if (_store.containsKey(name)) {
      _store[name] = value;
      return true;
    }
    if (_outer != null) {
      return _outer!.update(name, value);
    }
    // Variable not found in any scope, set in current scope
    _store[name] = value;
    return false;
  }

  /// Updates variable at specific scope distance.
  void assignAt(int distance, String name, Object? value) {
    _ancestor(distance)._store[name] = value;
  }

  void addOutput(String line) {
    _output.add(line);
  }

  List<String> getOutput() => List.unmodifiable(_output);

  /// Clears the output buffer.
  void clearOutput() {
    _output.clear();
  }

  /// Exports all variables from all scopes to a Map.
  ///
  /// Variables in inner scopes shadow those in outer scopes.
  Map<String, Object?> toMap() {
    final result = <String, Object?>{};
    // First add outer scope variables (if any)
    if (_outer != null) {
      result.addAll(_outer!.toMap());
    }
    // Then add current scope (shadows outer)
    result.addAll(_store);
    return result;
  }

  /// Gets value at specific scope distance.
  Object? getAt(int distance, String name) {
    return _ancestor(distance)._store[name];
  }

  /// Gets value from global scope (root environment).
  (Object?, bool) getGlobal(String name) {
    var env = this;
    while (env._outer != null) {
      env = env._outer!;
    }
    if (env._store.containsKey(name)) {
      return (env._store[name], true);
    }
    return (null, false);
  }

  Environment _ancestor(int distance) {
    var env = this;
    for (var i = 0; i < distance; i++) {
      if (env._outer == null) {
        // Should not happen if Resolver is correct
        throw Exception("Invalid scope distance: $distance (depth exceeded)");
      }
      env = env._outer!;
    }
    return env;
  }
}
