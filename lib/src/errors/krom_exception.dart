/// Base exception for all KromScript errors.
abstract class KromException implements Exception {
  final String message;
  final int? line;
  final int? column;

  KromException(this.message, {this.line, this.column});

  @override
  String toString() {
    final loc = line != null ? ' (at line $line:${column ?? 0})' : '';
    return 'KromException: $message$loc';
  }
}

/// Error thrown during parsing (syntax error).
class KromSyntaxError extends KromException {
  KromSyntaxError(super.message, {super.line, super.column});

  @override
  String toString() => 'SyntaxError: $message at line $line:${column ?? 0}';
}

/// Error thrown during execution (runtime error).
class KromRuntimeError extends KromException {
  KromRuntimeError(super.message, {super.line, super.column});

  @override
  String toString() => 'RuntimeError: $message${line != null ? " at line $line" : ""}';
}

/// Error thrown when script execution times out or exceeds operation limit.
class KromResourceError extends KromRuntimeError {
  KromResourceError(super.message);
}
