import 'dart:async';
import 'dart:convert';

import 'package:weils_api/core/network/http_transport.dart';
import 'package:weils_api/core/platform/runtime_info.dart';

import '../../domain/entities/workspace_entities.dart';
import '../../domain/repositories/request_gateway.dart';
import '../../domain/use_cases/request_headers.dart';
import '../../domain/entities/sse_event.dart';

class HttpRequestGateway implements RequestGateway {
  HttpRequestGateway(this.transport, {String? userAgent})
    : userAgent = userAgent ?? defaultUserAgent;
  final HttpTransport transport;
  final String userAgent;
  /// 将领域请求转换为传输任务，仅对 HTTP 200 且类型正确的响应启用 SSE 解析。
  /// 增量解码 UTF-8 并解析事件，实时更新最多每 100 毫秒一次，结束时立即发送最终结果。
  @override
  RequestTask<ResponseRecord> start(
    RequestSpec request, {
    required Duration timeout,
    int sseMaxResponseMb = 2,
  }) {
    final wantsSse = request.protocol == 'sse';
    final generated = defaultRequestHeaders(request, userAgent: userAgent);
    final task = transport.start(
      TransportRequest(
        method: request.method,
        uri: request.effectiveUri,
        userAgent: userAgent,
        body: requestBodyBytes(request),
        maxStreamBytes: sseMaxResponseMb * 1024 * 1024,
        streamWhen: !wantsSse
            ? null
            : (status, headers) =>
                  status == 200 &&
                  headers['content-type']
                          ?.split(';')
                          .first
                          .trim()
                          .toLowerCase() ==
                      'text/event-stream',
        headers: [
          for (final header in generated)
            if (header.value != null) MapEntry(header.name, header.value!),
          for (final header in request.headers)
            if (header.enabled && header.name.trim().isNotEmpty)
              MapEntry(header.name.trim(), header.value),
        ],
      ),
      timeout: timeout,
    );
    final updates = StreamController<ResponseRecord>();
    final body = StringBuffer();
    final events = <SseEvent>[];
    final parser = SseParser(events.add);
    final decoder = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(
          _TextSink((text) {
            body.write(text);
            parser.add(text);
          }),
        );
    TransportUpdate? latest;
    Timer? pending;
    /// 将传输响应映射为领域响应，附带已捕获事件、实际响应类型和本次捕获上限。
    ResponseRecord record(TransportResponse r) => ResponseRecord(
      statusCode: r.statusCode,
      reason: r.reason,
      body: latest?.streaming == true ? body.toString() : r.body,
      headers: r.headers,
      elapsedMs: r.elapsedMs,
      byteCount: r.byteCount,
      failure: r.failure,
      cancelled: r.cancelled,
      truncated: r.truncated,
      isSse: latest?.streaming == true,
      sseRequested: wantsSse,
      captureLimitBytes: !wantsSse
          ? null
          : latest?.streaming == true
          ? sseMaxResponseMb * 1024 * 1024
          : IoHttpTransport.maxBodyBytes,
      sseEvents: latest?.streaming == true ? events : null,
    );
    final subscription = task.updates.listen((update) {
      latest = update;
      if (update.streaming && update.bytes.isNotEmpty) {
        decoder.add(update.bytes);
      }
      pending ??= Timer(const Duration(milliseconds: 100), () {
        pending = null;
        final head = latest!;
        updates.add(
          record(
            TransportResponse(
              statusCode: head.statusCode,
              reason: head.reason,
              headers: head.headers,
              elapsedMs: head.elapsedMs,
              byteCount: head.byteCount,
            ),
          ),
        );
      });
    });
    final result = task.result.then((response) async {
      await subscription.cancel();
      pending?.cancel();
      decoder.close();
      final finalRecord = record(response);
      updates.add(finalRecord);
      unawaited(updates.close());
      return finalRecord;
    });
    return RequestTask(task.cancel, result, updates: updates.stream);
  }
}

class _TextSink implements Sink<String> {
  _TextSink(this.onText);
  final void Function(String) onText;
  /// 将增量 UTF-8 解码出的文本交给正文累积与 SSE 解析回调。
  @override
  void add(String data) => onText(data);
  /// 接收解码结束通知；正文缓冲与解析器由请求任务统一管理，无需额外关闭。
  @override
  void close() {}
}
