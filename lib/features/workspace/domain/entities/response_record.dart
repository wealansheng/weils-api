import 'package:weils_api/core/errors/app_failure.dart';

import 'sse_event.dart';

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
    this.sseRequested = false,
    this.isSse = false,
    this.captureLimitBytes,
    List<SseEvent>? sseEvents,
  }) : headers = Map.unmodifiable(headers),
       _sseEvents = sseEvents == null ? null : List.unmodifiable(sseEvents);
  final int? statusCode;
  final String reason, body;
  final Map<String, String> headers;
  final int elapsedMs, byteCount;

  /// 旧版工作区保存的错误文本，读取后原样保留以避免历史信息丢失。
  final String? legacyError;
  final AppFailure? failure;
  final bool cancelled, truncated;
  final bool sseRequested, isSse;
  final int? captureLimitBytes;
  final List<SseEvent>? _sseEvents;
  late final List<SseEvent> sseEvents =
      _sseEvents ?? (isSse ? SseParser.parse(body) : const <SseEvent>[]);
  late final String sseData = sseEvents.map((e) => e.data).join();
  bool get success =>
      statusCode != null && statusCode! >= 200 && statusCode! < 400;
  bool get hasError => failure != null || legacyError != null;
}
