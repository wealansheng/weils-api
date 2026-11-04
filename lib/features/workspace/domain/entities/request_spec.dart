import 'dart:convert';

import 'package:weils_api/core/utils/identity.dart';
import 'entry.dart';

enum RequestValidation {
  invalidUrl,
  invalidUrlFormat,
  invalidJsonOrUrl,
  invalidHeader,
  invalidToken,
}

class RequestSpec {
  RequestSpec({
    String? id,
    this.name = '未命名接口',
    this.folderId = 'default',
    this.method = 'GET',
    this.url = '',
    List<Entry> params = const [],
    List<Entry> headers = const [],
    this.bodyType = 'none',
    this.body = '',
    this.authType = 'none',
    this.token = '',
  }) : id = id ?? newId(),
       params = List.unmodifiable(params),
       headers = List.unmodifiable(headers);
  final String id, name, folderId, method, url, bodyType, body, authType, token;
  final List<Entry> params, headers;

  RequestSpec copyWith({
    String? name,
    String? folderId,
    String? method,
    String? url,
    List<Entry>? params,
    List<Entry>? headers,
    String? bodyType,
    String? body,
    String? authType,
    String? token,
    bool newIdentity = false,
  }) => RequestSpec(
    id: newIdentity ? null : id,
    name: name ?? this.name,
    folderId: folderId ?? this.folderId,
    method: method ?? this.method,
    url: url ?? this.url,
    params: params ?? this.params,
    headers: headers ?? this.headers,
    bodyType: bodyType ?? this.bodyType,
    body: body ?? this.body,
    authType: authType ?? this.authType,
    token: token ?? this.token,
  );

  Uri get effectiveUri {
    final uri = Uri.parse(url.trim());
    final query = <String, List<String>>{
      for (final e in uri.queryParametersAll.entries) e.key: List.of(e.value),
    };
    for (final row in params) {
      if (row.name.trim().isNotEmpty) query.remove(row.name.trim());
    }
    for (final row in params.where(
      (e) => e.enabled && e.name.trim().isNotEmpty,
    )) {
      query.putIfAbsent(row.name.trim(), () => []).add(row.value);
    }
    if (query.isNotEmpty) {
      return uri.replace(queryParameters: query).removeFragment();
    }
    final clean = uri.replace(query: '').removeFragment().toString();
    return Uri.parse(
      clean.endsWith('?') ? clean.substring(0, clean.length - 1) : clean,
    );
  }

  RequestValidation? validate() {
    try {
      final uri = effectiveUri;
      if (!['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        return RequestValidation.invalidUrl;
      }
      if (bodyType == 'json' && body.trim().isNotEmpty) jsonDecode(body);
      const pattern = r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$";
      for (final row in headers.where((e) => e.enabled && e.name.isNotEmpty)) {
        if (!RegExp(pattern).hasMatch(row.name) ||
            row.value.contains(RegExp(r'[\r\n]'))) {
          return RequestValidation.invalidHeader;
        }
      }
      if (token.contains(RegExp(r'[\r\n]'))) {
        return RequestValidation.invalidToken;
      }
    } on FormatException {
      return bodyType == 'json'
          ? RequestValidation.invalidJsonOrUrl
          : RequestValidation.invalidUrlFormat;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is RequestSpec &&
      id == other.id &&
      name == other.name &&
      folderId == other.folderId &&
      method == other.method &&
      url == other.url &&
      bodyType == other.bodyType &&
      body == other.body &&
      authType == other.authType &&
      token == other.token &&
      sameItems(params, other.params) &&
      sameItems(headers, other.headers);
  @override
  int get hashCode => Object.hash(
    id,
    name,
    folderId,
    method,
    url,
    bodyType,
    body,
    authType,
    token,
    Object.hashAll(params),
    Object.hashAll(headers),
  );
}
