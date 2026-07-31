import '../natives/natives.dart';
import '../errors/krom_exception.dart';
import 'krom_runtime_type.dart';

// Helper for boolean logic used in control flow and filters
bool isTruthy(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  return true;
}

class KromInteractionError extends KromRuntimeError {
  KromInteractionError(super.message);
}

class KromListType extends KromRuntimeType<List> {
  @override
  Object? getProperty(List target, String name, KromFunctionInvoker invoker) {
    if (name == 'length' || name == 'size') {
      return target.length.toDouble();
    }
    if (name == 'isEmpty') {
      return target.isEmpty;
    }
    if (name == 'isNotEmpty') {
      return target.isNotEmpty;
    }

    // Methods returning NativeFunctionValue
    if (name == 'add') {
      return NativeFunctionValue((args) {
        if (args.isEmpty) throw KromInteractionError('add requires 1 argument');
        target.add(args[0]);
        return null; // void return
      });
    }

    if (name == 'remove') {
      return NativeFunctionValue((args) {
        if (args.isEmpty)
          throw KromInteractionError('remove requires 1 argument');
        return target.remove(args[0]);
      });
    }

    if (name == 'clear') {
      return NativeFunctionValue((args) {
        target.clear();
        return null;
      });
    }

    if (name == 'contains') {
      return NativeFunctionValue((args) {
        if (args.isEmpty)
          throw KromInteractionError('contains requires 1 argument');
        return target.contains(args[0]);
      });
    }

    if (name == 'map') {
      return NativeFunctionValue((args) {
        if (args.isEmpty) return [];
        final fn = args[0];
        // Convert List to avoid concurrent modification during iteration if we were modifying?
        // Not modifying, but good practice.
        // Also pass index as second arg
        var index = 0.0;
        return target.map((e) {
          return invoker.applyFunction(fn, [e, index++]);
        }).toList();
      });
    }

    if (name == 'filter' || name == 'where') {
      return NativeFunctionValue((args) {
        if (args.isEmpty) return [];
        final fn = args[0];
        final result = <Object?>[];
        var index = 0.0;
        for (final item in target) {
          if (isTruthy(invoker.applyFunction(fn, [item, index++]))) {
            result.add(item);
          }
        }
        return result;
      });
    }

    if (name == 'forEach') {
      return NativeFunctionValue((args) {
        if (args.isEmpty) return null;
        final fn = args[0];
        var index = 0.0;
        for (final item in target) {
          invoker.applyFunction(fn, [item, index++]);
        }
        return null;
      });
    }

    if (name == 'any') {
      return NativeFunctionValue((args) {
        if (args.isEmpty) return false;
        final fn = args[0];
        var index = 0.0;
        for (final item in target) {
          if (isTruthy(invoker.applyFunction(fn, [item, index++]))) return true;
        }
        return false;
      });
    }

    if (name == 'every') {
      return NativeFunctionValue((args) {
        if (args.isEmpty) return true;
        final fn = args[0];
        var index = 0.0;
        for (final item in target) {
          if (!isTruthy(invoker.applyFunction(fn, [item, index++])))
            return false;
        }
        return true;
      });
    }

    return null;
  }

  @override
  Object? callMethod(List target, String name, List<Object?> args,
      KromFunctionInvoker invoker) {
    // We handle method calls via getProperty returning a function,
    // but we could implement direct calls here if we change architecture.
    // For now returning null means handled elsewhere or not supported directly.
    return null;
  }
}

class KromMapType extends KromRuntimeType<Map> {
  @override
  Object? getProperty(Map target, String name, KromFunctionInvoker invoker) {
    // Direct property access on Map returns the value for that key
    // This matches interpreter behavior: obj[prop]
    // However, interpreter also supports method calls implicitly if we add them here.

    // Check for Map methods first? Or prefer keys?
    // Interpreter preferred keys.
    if (target.containsKey(name)) {
      return target[name];
    }

    // If not a key, maybe a method?
    if (name == 'keys') {
      return target.keys.toList();
    }
    if (name == 'values') {
      return target.values.toList();
    }
    if (name == 'length' || name == 'size') {
      return target.length.toDouble();
    }
    if (name == 'isEmpty') {
      return target.isEmpty;
    }
    if (name == 'isNotEmpty') {
      return target.isNotEmpty;
    }
    if (name == 'clear') {
      return NativeFunctionValue((args) {
        target.clear();
        return null;
      });
    }

    return null;
  }

  @override
  bool hasProperty(Map target, String name, KromFunctionInvoker invoker) {
    // A key that is present but holds null is still a property of the map.
    return target.containsKey(name) ||
        getProperty(target, name, invoker) != null;
  }

  @override
  Object? callMethod(Map target, String name, List<Object?> args,
      KromFunctionInvoker invoker) {
    return null;
  }
}

class KromStringType extends KromRuntimeType<String> {
  @override
  Object? getProperty(String target, String name, KromFunctionInvoker invoker) {
    if (name == 'length') {
      return target.length.toDouble();
    }
    if (name == 'isEmpty') {
      return target.isEmpty;
    }
    if (name == 'isNotEmpty') {
      return target.isNotEmpty;
    }

    // Methods
    if (name == 'substring') {
      return NativeFunctionValue((args) {
        if (args.isEmpty)
          throw KromInteractionError('substring requires at least 1 argument');
        final start = (args[0] as num).toInt();
        final end = args.length > 1 ? (args[1] as num?)?.toInt() : null;
        return target.substring(start, end);
      });
    }

    if (name == 'split') {
      return NativeFunctionValue((args) {
        if (args.isEmpty)
          throw KromInteractionError('split requires 1 argument');
        final pattern = args[0] as String;
        return target.split(pattern);
      });
    }

    if (name == 'trim') {
      return NativeFunctionValue((args) => target.trim());
    }

    if (name == 'toLowerCase') {
      return NativeFunctionValue((args) => target.toLowerCase());
    }

    if (name == 'toUpperCase') {
      return NativeFunctionValue((args) => target.toUpperCase());
    }

    return null;
  }

  @override
  Object? callMethod(String target, String name, List<Object?> args,
      KromFunctionInvoker invoker) {
    return null;
  }
}
