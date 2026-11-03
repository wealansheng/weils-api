import 'dart:convert';

import '../entities/request_spec.dart';

class DefaultHeader {
  const DefaultHeader(this.name, this.value);
  final String name;

  /// A null Host is displayed as a placeholder but never sent to the server.
  final String? value;
}

List<int> requestBodyBytes(RequestSpec spec) =>
    spec.bodyType == 'none' ? const [] : utf8.encode(spec.body);

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
    /* The editor may contain an incomplete URL. */
  }
  final payload = requestBodyBytes(spec);
  return [
    DefaultHeader('Host', host),
    DefaultHeader('User-Agent', userAgent),
    const DefaultHeader('Accept-Encoding', 'gzip'),
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
