/// Unified result type for service operations.
/// Use exhaustive switch in controllers:
/// ```dart
/// switch (result) {
///   case Success(:final data): // handle
///   case Failure(:final message): // handle
/// }
/// ```
sealed class Result<T> {
  const Result();
  factory Result.success(T data) = Success<T>;
  factory Result.failure(String message, [Object? error]) = Failure<T>;
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  const Failure(this.message, [this.error]);
}
