enum FailureCode {
  read,
  write,
  conflict,
  busy,
  notFound,
  invalidData,
  connection,
  tls,
  interrupted,
  unknownNetwork,
  timeout,
}

/// 基础设施错误只携带可识别的错误信息，展示文案由界面层转换。
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
