/// Status of a single setup step.
enum StepStatus { pending, running, completed, failed }

/// Immutable state for one setup step, observed by the splash screen.
class SetupStepState {
  final String label;
  final String detail;
  final StepStatus status;
  final double progress;
  final String? errorMessage;
  final String? fixHint;

  /// When true, the UI should show an input field (e.g. GitHub PAT prompt).
  final bool needsInput;

  /// Label for the input field (e.g. "GitHub Personal Access Token").
  final String? inputLabel;

  const SetupStepState({
    required this.label,
    this.detail = '',
    this.status = StepStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.fixHint,
    this.needsInput = false,
    this.inputLabel,
  });

  /// Create a copy with updated fields.
  /// Pass [clearError] = true to reset error/hint on retry.
  SetupStepState copyWith({
    String? label,
    String? detail,
    StepStatus? status,
    double? progress,
    String? errorMessage,
    String? fixHint,
    bool clearError = false,
    bool? needsInput,
    String? inputLabel,
  }) {
    return SetupStepState(
      label: label ?? this.label,
      detail: detail ?? this.detail,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fixHint: clearError ? null : (fixHint ?? this.fixHint),
      needsInput: needsInput ?? (clearError ? false : this.needsInput),
      inputLabel: clearError ? null : (inputLabel ?? this.inputLabel),
    );
  }
}
