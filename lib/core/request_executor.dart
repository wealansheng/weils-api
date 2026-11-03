import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

class RequestOperation {
  RequestOperation(this._cancel, this.result);
  final void Function() _cancel;
  final Future<ResponseRecord> result;
  void cancel() => _cancel();
}

class RequestExecutor {
  // Bound captured bodies so a large download cannot exhaust the workspace.
  static const maxBodyBytes = 2 * 1024 * 1024;
  RequestOperation start(
    RequestSpec spec, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    final client = HttpClient()..connectionTimeout = timeout;
    final cancelled = Completer<ResponseRecord>();
    final watch = Stopwatch()..start();
    bool stopped = false;
    Future<ResponseRecord> perform() async {
      final request = await client.openUrl(spec.method, spec.effectiveUri);
      for (final entry in spec.headers.where(
        (e) => e.enabled && e.name.trim().isNotEmpty,
      )) {
        request.headers.add(entry.name.trim(), entry.value);
      }
      if (spec.authType == 'bearer' && spec.token.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${spec.token}',
        );
      }
      if (spec.bodyType != 'none' && spec.body.isNotEmpty) {
        request.headers.contentType ??= spec.bodyType == 'json'
            ? ContentType.json
            : ContentType('text', 'plain', charset: 'utf-8');
        request.add(utf8.encode(spec.body));
      }
      final response = await request.close();
      final bytes = <int>[];
      var received = 0;
      var truncated = false;
      await for (final chunk in response) {
        received += chunk.length;
        final available = maxBodyBytes - bytes.length;
        bytes.addAll(chunk.take(available));
        if (received > maxBodyBytes) {
          truncated = true;
          break;
        }
      }
      final headers = <String, String>{};
      response.headers.forEach(
        (key, values) => headers[key] = values.join(', '),
      );
      String text;
      final charset = response.headers.contentType?.charset?.toLowerCase();
      text = charset == 'iso-8859-1' || charset == 'latin1'
          ? latin1.decode(bytes)
          : utf8.decode(bytes, allowMalformed: true);
      return ResponseRecord(
        statusCode: response.statusCode,
        reason: response.reasonPhrase,
        body: text,
        headers: headers,
        elapsedMs: watch.elapsedMilliseconds,
        byteCount: received,
        truncated: truncated,
      );
    }

    final result = Future.any([perform(), cancelled.future])
        .timeout(
          timeout,
          onTimeout: () => ResponseRecord(
            error: '请求超时（${timeout.inSeconds} 秒），请检查服务或调整超时设置。',
            elapsedMs: watch.elapsedMilliseconds,
          ),
        )
        .catchError((Object error) {
          final message = error is HandshakeException
              ? 'TLS 连接失败，请检查服务证书。'
              : error is SocketException
              ? '无法连接到服务器，请检查地址、网络和服务状态。'
              : error is HttpException
              ? 'HTTP 连接中断，请检查服务器后重试。'
              : '请求未能完成，请检查 URL、Headers 和请求内容。';
          return ResponseRecord(
            error: message,
            elapsedMs: watch.elapsedMilliseconds,
          );
        })
        .whenComplete(() {
          stopped = true;
          watch.stop();
          client.close(force: true);
        });
    return RequestOperation(() {
      if (!stopped && !cancelled.isCompleted) {
        cancelled.complete(
          ResponseRecord(cancelled: true, elapsedMs: watch.elapsedMilliseconds),
        );
        client.close(force: true);
      }
    }, result);
  }
}
