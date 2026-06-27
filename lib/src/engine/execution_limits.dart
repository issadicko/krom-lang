/// Limits applied to every script execution (top-level load, `build()`,
/// callbacks, reactive builders) so a misbehaving — or hostile — mini-app
/// cannot hang the host: an **operation budget** and a **wall-clock deadline**,
/// both enforced by the interpreter at each statement and loop iteration.
///
/// **Safe by default**: enabled with generous bounds. A legitimate build or
/// callback runs a few thousand operations in well under the deadline, so it is
/// never affected, while `while (true) {}` trips the guard and throws
/// ([KromResourceError]) instead of looping forever.
///
/// The host SDK integrator can tune the bounds or disable the guard entirely
/// ([ExecutionLimits.unlimited]) for trusted / first-party code.
///
/// NB: the guard is *cooperative* and runs on the caller's thread, so a
/// bounded-but-heavy execution still costs up to [deadline] of jank before it
/// trips. Running the mini-app off the UI thread (a separate isolate) is the
/// stronger, complementary mechanism.
class ExecutionLimits {
  /// Whether the guard is active. When `false`, scripts run unbounded.
  final bool enabled;

  /// Maximum interpreter operations per execution before a
  /// `KromResourceError('max operations exceeded')`. `0` = unlimited.
  final int maxOperations;

  /// Wall-clock budget per execution before a
  /// `KromResourceError('execution timeout')`. [Duration.zero] = no deadline.
  final Duration deadline;

  const ExecutionLimits({
    this.enabled = true,
    this.maxOperations = 10000000,
    this.deadline = const Duration(seconds: 1),
  });

  /// Guard disabled — scripts run with no operation/time limit. Use only for
  /// trusted, first-party mini-apps.
  static const ExecutionLimits unlimited = ExecutionLimits(
    enabled: false,
    maxOperations: 0,
    deadline: Duration.zero,
  );

  ExecutionLimits copyWith({
    bool? enabled,
    int? maxOperations,
    Duration? deadline,
  }) =>
      ExecutionLimits(
        enabled: enabled ?? this.enabled,
        maxOperations: maxOperations ?? this.maxOperations,
        deadline: deadline ?? this.deadline,
      );

  @override
  String toString() => 'ExecutionLimits(enabled: $enabled, '
      'maxOperations: $maxOperations, deadline: $deadline)';
}
