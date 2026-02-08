import '../ast/ast.dart';
import 'environment.dart';

/// Result of an interpreter execution.
class ExecutionResult {
  final Object? value;
  final List<String> output;
  final Map<String, Object?> variables;

  ExecutionResult({this.value, required this.output, required this.variables});
}

/// Sentinel object to indicate that a method was not found.
/// Used to distinguish between a method that returns null and a missing method.
class _MethodNotFound {
  const _MethodNotFound();
}

/// Sentinel value indicating a method was not found on a KromBindable object.
const methodNotFound = _MethodNotFound();

/// Interface for objects that can be bound to KromScript.
///
/// Implement this interface on Dart classes you want to expose to
/// KromScript via the `.bind()` API.
///
/// Example:
/// ```dart
/// class User implements KromBindable {
///   final String name;
///   User(this.name);
///
///   @override
///   Object? getProperty(String name) {
///     if (name == 'name') return this.name;
///     return null;
///   }
///
///   @override
///   Object? callMethod(String name, List<Object?> args) {
///     if (name == 'sayHello') return "Hello, I'm ${this.name}";
///     return null;
///   }
/// }
/// ```
abstract class KromBindable {
  /// Get a property value by name.
  /// Returns null if the property doesn't exist.
  Object? getProperty(String name);

  /// Call a method by name with arguments.
  /// Returns [methodNotFound] if the method doesn't exist.
  /// Can return null if the method exists and returns null.
  Object? callMethod(String name, List<Object?> args);
}

/// Wrapper to signal early return from evaluation.
class ReturnValue {
  final Object? value;
  ReturnValue(this.value);
}

/// Function value (user defined).
class FunctionValue {
  final List<Identifier> parameters;
  final BlockStatement body;
  final Environment env;

  FunctionValue(this.parameters, this.body, this.env);
}
