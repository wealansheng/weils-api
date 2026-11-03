import 'dart:convert';

int _sequence = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

class Entry {
  Entry({
    String? id,
    this.name = '',
    this.value = '',
    this.description = '',
    this.enabled = true,
  }) : id = id ?? newId();
  final String id;
  String name;
  String value;
  String description;
  bool enabled;
  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    value: json['value'] as String? ?? '',
    description: json['description'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'value': value,
    'description': description,
    'enabled': enabled,
  };
}

class RequestSpec {
  RequestSpec({
    String? id,
    this.name = '未命名接口',
    this.folderId = 'default',
    this.method = 'GET',
    this.url = '',
    List<Entry>? params,
    List<Entry>? headers,
    this.bodyType = 'none',
    this.body = '',
    this.authType = 'none',
    this.token = '',
  }) : id = id ?? newId(),
       params = params ?? [],
       headers = headers ?? [];
  final String id;
  String name, folderId, method, url, bodyType, body, authType, token;
  final List<Entry> params, headers;
  factory RequestSpec.fromJson(Map<String, dynamic> json) => RequestSpec(
    id: json['id'] as String,
    name: json['name'] as String? ?? '未命名接口',
    folderId: json['folderId'] as String? ?? 'default',
    method: json['method'] as String? ?? 'GET',
    url: json['url'] as String? ?? '',
    params: _entries(json['params']),
    headers: _entries(json['headers']),
    bodyType: json['bodyType'] as String? ?? 'none',
    body: json['body'] as String? ?? '',
    authType: json['authType'] as String? ?? 'none',
    token: json['token'] as String? ?? '',
  );
  static List<Entry> _entries(dynamic list) => (list as List? ?? [])
      .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'folderId': folderId,
    'method': method,
    'url': url,
    'params': params.map((e) => e.toJson()).toList(),
    'headers': headers.map((e) => e.toJson()).toList(),
    'bodyType': bodyType,
    'body': body,
    'authType': authType,
    'token': token,
  };
  RequestSpec copy({bool newIdentity = false}) {
    final json = toJson();
    if (newIdentity) json['id'] = newId();
    return RequestSpec.fromJson(json);
  }

  String get fingerprint => jsonEncode(toJson());

  /// Preserve repeated URL query values. Table rows override matching URL keys;
  /// disabling a table row also removes that key from the outgoing URL.
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
    // Uri.replace(query: '') retains an empty '?' marker. Strip that marker
    // without rebuilding (and potentially re-encoding) the original URL path.
    final clean = uri.replace(query: '').removeFragment().toString();
    return Uri.parse(
      clean.endsWith('?') ? clean.substring(0, clean.length - 1) : clean,
    );
  }

  String? validate() {
    try {
      final uri = effectiveUri;
      if (!['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        return '请输入完整的 HTTP 或 HTTPS 地址，例如 https://api.example.com/users';
      }
      if (bodyType == 'json' && body.trim().isNotEmpty) jsonDecode(body);
      const headerPattern = r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$";
      for (final row in headers.where((e) => e.enabled && e.name.isNotEmpty)) {
        if (!RegExp(headerPattern).hasMatch(row.name) ||
            row.value.contains(RegExp(r'[\r\n]'))) {
          return 'Header 名称或值包含无效字符，请检查 Headers。';
        }
      }
      if (token.contains(RegExp(r'[\r\n]'))) return 'Bearer Token 不能包含换行。';
    } on FormatException {
      return bodyType == 'json'
          ? 'URL 或 JSON 格式不正确，请检查后重试。'
          : 'URL 格式不正确，请检查后重试。';
    }
    return null;
  }
}

class Folder {
  Folder(this.id, this.name);
  final String id;
  String name;
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Folder.fromJson(Map<String, dynamic> json) =>
      Folder(json['id'] as String, json['name'] as String);
}

class ResponseRecord {
  ResponseRecord({
    this.statusCode,
    this.reason = '',
    this.body = '',
    this.headers = const {},
    this.elapsedMs = 0,
    this.byteCount = 0,
    this.error,
    this.cancelled = false,
    this.truncated = false,
  });
  final int? statusCode;
  final String reason, body;
  final Map<String, String> headers;
  final int elapsedMs, byteCount;
  final String? error;
  final bool cancelled, truncated;
  bool get success =>
      statusCode != null && statusCode! >= 200 && statusCode! < 400;
  String get statusLabel => cancelled
      ? '已取消'
      : statusCode == null
      ? '请求失败'
      : '$statusCode $reason'.trim();
  String get sizeLabel => byteCount < 1024
      ? '$byteCount B'
      : byteCount < 1024 * 1024
      ? '${(byteCount / 1024).toStringAsFixed(1)} KB'
      : '${(byteCount / (1024 * 1024)).toStringAsFixed(1)} MB';
  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'reason': reason,
    'body': body,
    'headers': headers,
    'elapsedMs': elapsedMs,
    'byteCount': byteCount,
    'error': error,
    'cancelled': cancelled,
    'truncated': truncated,
  };
  factory ResponseRecord.fromJson(Map<String, dynamic> json) => ResponseRecord(
    statusCode: json['statusCode'] as int?,
    reason: json['reason'] as String? ?? '',
    body: json['body'] as String? ?? '',
    headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
    elapsedMs: json['elapsedMs'] as int? ?? 0,
    byteCount: json['byteCount'] as int? ?? 0,
    error: json['error'] as String?,
    cancelled: json['cancelled'] as bool? ?? false,
    truncated: json['truncated'] as bool? ?? false,
  );
}

class HistoryRecord {
  HistoryRecord({
    String? id,
    required this.request,
    required this.response,
    DateTime? time,
  }) : id = id ?? newId(),
       time = time ?? DateTime.now();
  final String id;
  final RequestSpec request;
  final ResponseRecord response;
  final DateTime time;
  Map<String, dynamic> toJson() => {
    'id': id,
    'request': request.toJson(),
    'response': response.toJson(),
    'time': time.toIso8601String(),
  };
  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
    id: json['id'] as String,
    request: RequestSpec.fromJson(
      Map<String, dynamic>.from(json['request'] as Map),
    ),
    response: ResponseRecord.fromJson(
      Map<String, dynamic>.from(json['response'] as Map),
    ),
    time: DateTime.parse(json['time'] as String),
  );
}
