enum FailureCode {
  read,
  write,
  conflict,
  notFound,
  invalidData,
  connection,
  tls,
  interrupted,
  unknownNetwork,
  timeout,
}

/// Infrastructure failures carry machine-readable information, never UI copy.
class AppFailure implements Exception {
  const AppFailure(this.code, {this.seconds, this.cause});
  final FailureCode code;
  final int? seconds;
  final Object? cause;
}

class Outcome<T> {
  const Outcome.success([this.value]) : failure = null;
  const Outcome.failure(this.failure) : value = null;
  final T? value;
  final AppFailure? failure;
  bool get succeeded => failure == null;
}
