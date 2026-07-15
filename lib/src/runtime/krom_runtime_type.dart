/// Interface for invoking functions in KromScript.
abstract class KromFunctionInvoker {
  Object? applyFunction(Object? fn, List<Object?> args);
}

/// Interface for handling runtime operations on Dart types in KromScript.
abstract class KromRuntimeType<T> {
  /// Gets a property from the target object.
  /// Returns `null` if the property is not found.
  Object? getProperty(T target, String name, KromFunctionInvoker invoker);

  /// Calls a method on the target object.
  /// Returns `null` if the method is not found (or really returns null).
  /// Should throw [KromRuntimeError] if arguments are invalid.
  Object? callMethod(
      T target, String name, List<Object?> args, KromFunctionInvoker invoker);
}

/// Registry for KromRuntimeType instances.
class TypeRegistry {
  static final TypeRegistry _instance = TypeRegistry._();
  static TypeRegistry get instance => _instance;

  final Map<Type, KromRuntimeType> _types = {};

  // Register default types on instance creation or explicit init?
  // Make it public so we can register from external file
  void addType<T>(KromRuntimeType<T> type) {
    register<T>(type);
  }

  TypeRegistry._();

  /// Registers a runtime type handler for Dart type [T].
  void register<T>(KromRuntimeType<T> handler) {
    _types[T] = handler;
  }

  /// Gets the handler for the runtime type of [value].
  /// Returns `null` if no handler is registered for the type.
  KromRuntimeType<Object>? getHandler(Object? value) {
    if (value == null) return null;

    // Direct match
    if (_types.containsKey(value.runtimeType)) {
      return _types[value.runtimeType] as KromRuntimeType<Object>;
    }

    // Look for supertypes
    for (final entry in _types.entries) {
      if (checkType(value, entry.key)) {
        return entry.value as KromRuntimeType<Object>;
      }
    }

    return null;
  }

  // Helper to check type without mirrors
  bool checkType(Object value, Type type) {
    if (type == List && value is List) return true;
    if (type == Map && value is Map) return true;
    if (type == String && value is String) return true;
    if (type == int && value is int) return true;
    if (type == double && value is double) return true;
    if (type == bool && value is bool) return true;

    return value.runtimeType == type;
  }
}
