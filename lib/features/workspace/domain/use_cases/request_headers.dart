import 'dart:convert';

import '../entities/request_spec.dart';

class DefaultHeader {
  const DefaultHeader(this.name, this.value);
  final String name;

  /// Host 未生成时以占位文本展示，不将空值发送给服务器。
  final String? value;
}

/// 按正文类型生成 UTF-8 字节，未启用正文时返回空字节列表。
List<int> requestBodyBytes(RequestSpec spec) =>
    spec.bodyType == 'none' ? const [] : utf8.encode(spec.body);

/// 生成 Host、正文、认证和 SSE 等默认 Headers；启用的同名自定义项按大小写不敏感覆盖。
List<DefaultHeader> defaultRequestHeaders(
  RequestSpec spec, {
  required String userAgent,
}) {
  final custom = spec.headers
      .where((e) => e.enabled && e.name.trim().isNotEmpty)
      .map((e) => e.name.trim().toLowerCase())
      .toSet();
  String? host;
  try {
    final uri = spec.effectiveUri;
    if (['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty) {
      host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
      if (uri.port != (uri.scheme == 'https' ? 443 : 80)) {
        host = '$host:${uri.port}';
      }
    }
  } on FormatException {
    /* 编辑中的 URL 可能尚未完整，暂不生成 Host。 */
  }
  final payload = requestBodyBytes(spec);
  return [
    DefaultHeader('Host', host),
    DefaultHeader('User-Agent', userAgent),
    const DefaultHeader('Accept-Encoding', 'gzip'),
    if (spec.protocol == 'sse')
      const DefaultHeader('Accept', 'text/event-stream'),
    if (payload.isNotEmpty)
      DefaultHeader(
        'Content-Type',
        spec.bodyType == 'json'
            ? 'application/json; charset=utf-8'
            : 'text/plain; charset=utf-8',
      ),
    if (!custom.contains('transfer-encoding') &&
        (payload.isNotEmpty ||
            ![
              'GET',
              'HEAD',
              'DELETE',
              'CONNECT',
              'TRACE',
            ].contains(spec.method)))
      DefaultHeader('Content-Length', '${payload.length}'),
    if (spec.authType == 'bearer' && spec.token.isNotEmpty)
      DefaultHeader('Authorization', 'Bearer ${spec.token}'),
  ].where((h) => !custom.contains(h.name.toLowerCase())).toList();
}
