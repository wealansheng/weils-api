import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// A generated header is preview data, not an editable/persisted custom row.
class DefaultHeader {
  const DefaultHeader(this.name, this.value);
  final String name;
  final String value;
}

final defaultUserAgent =
    'Dart/${Platform.version.split(' ').first.split('.').take(2).join('.')} (dart:io)';

List<int> requestBodyBytes(RequestSpec spec) =>
    spec.bodyType == 'none' ? const [] : utf8.encode(spec.body);

/// Shared by the editor and transport so generated values and overrides agree.
/// Names are case-insensitive; disabled custom rows do not replace defaults.
List<DefaultHeader> defaultRequestHeaders(RequestSpec spec) {
  final custom = spec.headers
      .where((e) => e.enabled && e.name.trim().isNotEmpty)
      .map((e) => e.name.trim().toLowerCase())
      .toSet();
  var host = '根据 URL 自动生成';
  try {
    final uri = spec.effectiveUri;
    if (['http', 'https'].contains(uri.scheme) && uri.host.isNotEmpty) {
      host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
      final defaultPort = uri.scheme == 'https' ? 443 : 80;
      if (uri.port != defaultPort) host = '$host:${uri.port}';
    }
  } on FormatException {
    // An incomplete URL can still show the other defaults while being edited.
  }
  final payload = requestBodyBytes(spec);
  return [
    DefaultHeader('Host', host),
    DefaultHeader('User-Agent', defaultUserAgent),
    const DefaultHeader('Accept-Encoding', 'gzip'),
    if (payload.isNotEmpty)
      DefaultHeader(
        'Content-Type',
        spec.bodyType == 'json'
            ? ContentType.json.toString()
            : ContentType('text', 'plain', charset: 'utf-8').toString(),
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
  ].where((e) => !custom.contains(e.name.toLowerCase())).toList();
}
