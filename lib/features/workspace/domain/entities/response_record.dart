import '../../../../core/errors/app_failure.dart';

class ResponseRecord {
  ResponseRecord({
    this.statusCode,
    this.reason = '',
    this.body = '',
    Map<String, String> headers = const {},
    this.elapsedMs = 0,
    this.byteCount = 0,
    this.legacyError,
    this.failure,
    this.cancelled = false,
    this.truncated = false,
  }) : headers = Map.unmodifiable(headers);
  final int? statusCode;
  final String reason, body;
  final Map<String, String> headers;
  final int elapsedMs, byteCount;

  /// Older workspace files store rendered errors; retain them losslessly.
  final String? legacyError;
  final AppFailure? failure;
  final bool cancelled, truncated;
  bool get success =>
      statusCode != null && statusCode! >= 200 && statusCode! < 400;
  bool get hasError => failure != null || legacyError != null;
}
