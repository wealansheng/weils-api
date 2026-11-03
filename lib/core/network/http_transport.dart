import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors/app_failure.dart';

class TransportRequest {
  const TransportRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
    required this.userAgent,
  });
  final String method, userAgent;
  final Uri uri;
  final List<MapEntry<String, String>> headers;
  final List<int> body;
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
  const TransportTask(this.cancel, this.result);
  final void Function() cancel;
  final Future<TransportResponse> result;
}

abstract interface class HttpTransport {
  TransportTask start(TransportRequest request, {required Duration timeout});
}

class IoHttpTransport implements HttpTransport {
  static const maxBodyBytes = 2 * 1024 * 1024;
  @override
  TransportTask start(TransportRequest spec, {required Duration timeout}) {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = spec.userAgent;
    final cancelled = Completer<TransportResponse>();
    final watch = Stopwatch()..start();
    var stopped = false;
    Future<TransportResponse> perform() async {
      final request = await client.openUrl(spec.method, spec.uri);
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
      final bytes = <int>[];
      var received = 0;
      var truncated = false;
      await for (final chunk in response) {
        received += chunk.length;
        bytes.addAll(chunk.take(maxBodyBytes - bytes.length));
        if (received > maxBodyBytes) {
          truncated = true;
          break;
        }
      }
      final headers = <String, String>{};
      response.headers.forEach(
        (key, values) => headers[key] = values.join(', '),
      );
      final charset = response.headers.contentType?.charset?.toLowerCase();
      return TransportResponse(
        statusCode: response.statusCode,
        reason: response.reasonPhrase,
        body: charset == 'iso-8859-1' || charset == 'latin1'
            ? latin1.decode(bytes)
            : utf8.decode(bytes, allowMalformed: true),
        headers: headers,
        elapsedMs: watch.elapsedMilliseconds,
        byteCount: received,
        truncated: truncated,
      );
    }

    final result = Future.any([perform(), cancelled.future])
        .timeout(
          timeout,
          onTimeout: () => TransportResponse(
            failure: AppFailure(
              FailureCode.timeout,
              seconds: timeout.inSeconds,
            ),
            elapsedMs: watch.elapsedMilliseconds,
          ),
        )
        .catchError(
          (Object error) => TransportResponse(
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
            elapsedMs: watch.elapsedMilliseconds,
          ),
        )
        .whenComplete(() {
          stopped = true;
          watch.stop();
          client.close(force: true);
        });
    return TransportTask(() {
      if (!stopped && !cancelled.isCompleted) {
        cancelled.complete(
          TransportResponse(
            cancelled: true,
            elapsedMs: watch.elapsedMilliseconds,
          ),
        );
        client.close(force: true);
      }
    }, result);
  }
}
