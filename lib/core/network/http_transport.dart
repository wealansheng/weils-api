import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../errors/app_failure.dart';

class TransportRequest {
  const TransportRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
    required this.userAgent,
    this.streamWhen,
    this.maxStreamBytes = IoHttpTransport.maxBodyBytes,
  });
  final String method, userAgent;
  final Uri uri;
  final List<MapEntry<String, String>> headers;
  final List<int> body;
  final bool Function(int statusCode, Map<String, String> headers)? streamWhen;
  final int maxStreamBytes;
}

class TransportResponse {
  const TransportResponse({
    this.statusCode,
    this.reason = '',
    this.body = '',
    this.headers = const {},
    this.elapsedMs = 0,
    this.byteCount = 0,
    this.failure,
    this.cancelled = false,
    this.truncated = false,
  });
  final int? statusCode;
  final String reason, body;
  final Map<String, String> headers;
  final int elapsedMs, byteCount;
  final AppFailure? failure;
  final bool cancelled, truncated;
}

class TransportTask {
  const TransportTask(
    this.cancel,
    this.result, {
    this.updates = const Stream.empty(),
  });
  final void Function() cancel;
  final Future<TransportResponse> result;
  final Stream<TransportUpdate> updates;
}

/// 首次更新仅包含响应头，后续更新携带本次捕获的正文数据块。
class TransportUpdate {
  const TransportUpdate({
    required this.statusCode,
    required this.reason,
    required this.headers,
    required this.streaming,
    this.bytes = const [],
    this.elapsedMs = 0,
    this.byteCount = 0,
  });
  final int statusCode, elapsedMs, byteCount;
  final String reason;
  final Map<String, String> headers;
  final bool streaming;
  final List<int> bytes;
}

abstract interface class HttpTransport {
  /// 启动可取消的传输任务，通过最终结果和可选更新流返回响应。
  TransportTask start(TransportRequest request, {required Duration timeout});
}

class IoHttpTransport implements HttpTransport {
  static const maxBodyBytes = 2 * 1024 * 1024;
  /// 为单次请求创建独立客户端，管理响应头、正文捕获、超时与取消。
  /// 普通响应限制总时长；满足流式条件后解除时限，并使用本次固定的捕获上限。
  @override
  TransportTask start(TransportRequest spec, {required Duration timeout}) {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = spec.userAgent;
    final completed = Completer<TransportResponse>();
    final updates = StreamController<TransportUpdate>(sync: true);
    final watch = Stopwatch()..start();
    final bytes = BytesBuilder(copy: false);
    var received = 0;
    var streaming = false;
    int? statusCode;
    var reason = '';
    String? charset;
    var headers = <String, String>{};
    Timer? deadline;
    /// 幂等结束传输，保留已捕获的状态、Headers 和正文，并释放计时器与客户端。
    void finish({
      AppFailure? failure,
      bool cancelled = false,
      bool truncated = false,
    }) {
      if (completed.isCompleted) return;
      deadline?.cancel();
      watch.stop();
      final captured = bytes.takeBytes();
      completed.complete(
        TransportResponse(
          statusCode: statusCode,
          reason: reason,
          headers: headers,
          body: !streaming && (charset == 'iso-8859-1' || charset == 'latin1')
              ? latin1.decode(captured)
              : utf8.decode(captured, allowMalformed: true),
          elapsedMs: watch.elapsedMilliseconds,
          byteCount: received,
          failure: failure,
          cancelled: cancelled,
          truncated: truncated,
        ),
      );
      client.close(force: true);
      unawaited(updates.close());
    }

    /// 将超时转换为统一失败结果，保留超时前收到的响应内容。
    void timeOut() => finish(
      failure: AppFailure(FailureCode.timeout, seconds: timeout.inSeconds),
    );
    deadline = Timer(timeout, timeOut);
    /// 应用请求头与正文并读取响应，按普通或流式规则处理大小限制和网络异常。
    Future<void> perform() async {
      try {
        final request = await client.openUrl(spec.method, spec.uri);
        if (completed.isCompleted) return;
        request.contentLength = spec.body.length;
        final applied = <String>{};
        for (final entry in spec.headers) {
          if (applied.add(entry.key.toLowerCase())) {
            request.headers.set(entry.key, entry.value);
          } else {
            request.headers.add(entry.key, entry.value);
          }
        }
        if (spec.body.isNotEmpty) request.add(spec.body);
        final response = await request.close();
        if (completed.isCompleted) return;
        statusCode = response.statusCode;
        reason = response.reasonPhrase;
        charset = response.headers.contentType?.charset?.toLowerCase();
        response.headers.forEach(
          (key, values) => headers[key] = values.join(', '),
        );
        headers = Map.unmodifiable(headers);
        streaming = spec.streamWhen?.call(statusCode!, headers) ?? false;
        if (streaming) {
          deadline?.cancel();
        } else if (spec.streamWhen != null) {
          // 未建立事件流时，正文读取仍受独立的超时限制。
          deadline?.cancel();
          deadline = Timer(timeout, timeOut);
        }
        final limit = streaming ? spec.maxStreamBytes : maxBodyBytes;
        /// 向启用更新流的任务发送响应头或数据块，普通 HTTP 不发送中间更新。
        void emit([List<int> chunk = const []]) {
          if (spec.streamWhen == null) return;
          updates.add(
            TransportUpdate(
              statusCode: statusCode!,
              reason: reason,
              headers: headers,
              streaming: streaming,
              bytes: chunk,
              elapsedMs: watch.elapsedMilliseconds,
              byteCount: received,
            ),
          );
        }

        emit();
        await for (final chunk in response) {
          if (completed.isCompleted) return;
          received += chunk.length;
          final remaining = limit - bytes.length;
          final captured = chunk.length <= remaining
              ? chunk
              : chunk.sublist(0, remaining);
          bytes.add(captured);
          emit(captured);
          if (streaming ? bytes.length >= limit : received > limit) {
            finish(truncated: true);
            return;
          }
        }
        finish();
      } catch (error) {
        finish(
          failure: AppFailure(
            error is HandshakeException
                ? FailureCode.tls
                : error is SocketException
                ? FailureCode.connection
                : error is HttpException
                ? FailureCode.interrupted
                : FailureCode.unknownNetwork,
            cause: error,
          ),
        );
      }
    }

    unawaited(perform());
    return TransportTask(
      () => finish(cancelled: true),
      completed.future,
      updates: updates.stream,
    );
  }
}
