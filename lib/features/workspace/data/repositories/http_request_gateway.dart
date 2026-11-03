import '../../../../core/network/http_transport.dart';
import '../../../../core/platform/runtime_info.dart';
import '../../domain/entities/workspace_entities.dart';
import '../../domain/repositories/request_gateway.dart';
import '../../domain/use_cases/request_headers.dart';

class HttpRequestGateway implements RequestGateway {
  HttpRequestGateway(this.transport, {String? userAgent})
    : userAgent = userAgent ?? defaultUserAgent;
  final HttpTransport transport;
  final String userAgent;
  @override
  RequestTask<ResponseRecord> start(
    RequestSpec request, {
    required Duration timeout,
  }) {
    final generated = defaultRequestHeaders(request, userAgent: userAgent);
    final task = transport.start(
      TransportRequest(
        method: request.method,
        uri: request.effectiveUri,
        userAgent: userAgent,
        body: requestBodyBytes(request),
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
    return RequestTask(
      task.cancel,
      task.result.then(
        (r) => ResponseRecord(
          statusCode: r.statusCode,
          reason: r.reason,
          body: r.body,
          headers: r.headers,
          elapsedMs: r.elapsedMs,
          byteCount: r.byteCount,
          failure: r.failure,
          cancelled: r.cancelled,
          truncated: r.truncated,
        ),
      ),
    );
  }
}
