import '../ast/ast.dart';
import 'tree_shaker.dart';
import 'constant_propagation.dart';
import 'function_inlining.dart';
import 'dead_code_elimination.dart';

/// Optimizer performs AST transformations to optimize the code.
class Optimizer {
  final bool enableTreeShaking;
  final bool enableInlining;
  final bool enableConstantPropagation;
  final bool enableDeadCodeElimination;

  Optimizer({
    this.enableTreeShaking = true,
    this.enableInlining = true,
    this.enableConstantPropagation = true,
    this.enableDeadCodeElimination = true,
  });

  Program optimize(Program program) {
    var result = program;

    // 1. Tree shaking (removes unused functions)
    if (enableTreeShaking) {
      final shaker = TreeShaker();
      result = shaker.shake(result);
    }

    // 2. Function Inlining
    if (enableInlining) {
      final inliner = FunctionInliner();
      result = inliner.optimize(result);
    }

    // 3. Constant Propagation & Folding
    if (enableConstantPropagation) {
      final cp = ConstantPropagation();
      result = cp.optimize(result);
    }

    // 4. Dead Code Elimination
    if (enableDeadCodeElimination) {
      final dce = DeadCodeElimination();
      result = dce.optimize(result);
    }

    return result;
  }
}
