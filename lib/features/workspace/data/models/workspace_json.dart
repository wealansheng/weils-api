import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/workspace_entities.dart';
import '../../../mock/data/mock_json.dart';

/// The v1 disk schema is isolated here; entities know nothing about JSON.
abstract final class WorkspaceJson {
  static Entry entry(Map<String, dynamic> j) => Entry(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    value: j['value'] as String? ?? '',
    description: j['description'] as String? ?? '',
    enabled: j['enabled'] as bool? ?? true,
  );
  static Map<String, dynamic> entryJson(Entry e) => {
    'id': e.id,
    'name': e.name,
    'value': e.value,
    'description': e.description,
    'enabled': e.enabled,
  };
  static List<Entry> _entries(dynamic data) => (data as List? ?? [])
      .map((j) => entry(Map<String, dynamic>.from(j as Map)))
      .toList();
  static RequestSpec request(Map<String, dynamic> j) => RequestSpec(
    id: j['id'] as String,
    name: j['name'] as String? ?? '未命名接口',
    folderId: j['folderId'] as String? ?? 'default',
    method: j['method'] as String? ?? 'GET',
    url: j['url'] as String? ?? '',
    params: _entries(j['params']),
    headers: _entries(j['headers']),
    bodyType: j['bodyType'] as String? ?? 'none',
    body: j['body'] as String? ?? '',
    authType: j['authType'] as String? ?? 'none',
    token: j['token'] as String? ?? '',
  );
  static Map<String, dynamic> requestJson(RequestSpec r) => {
    'id': r.id,
    'name': r.name,
    'folderId': r.folderId,
    'method': r.method,
    'url': r.url,
    'params': r.params.map(entryJson).toList(),
    'headers': r.headers.map(entryJson).toList(),
    'bodyType': r.bodyType,
    'body': r.body,
    'authType': r.authType,
    'token': r.token,
  };
  static ResponseRecord response(Map<String, dynamic> j) => ResponseRecord(
    statusCode: j['statusCode'] as int?,
    reason: j['reason'] as String? ?? '',
    body: j['body'] as String? ?? '',
    headers: Map<String, String>.from(j['headers'] as Map? ?? {}),
    elapsedMs: j['elapsedMs'] as int? ?? 0,
    byteCount: j['byteCount'] as int? ?? 0,
    legacyError: j['error'] as String?,
    cancelled: j['cancelled'] as bool? ?? false,
    truncated: j['truncated'] as bool? ?? false,
  );
  static Map<String, dynamic> responseJson(ResponseRecord r) => {
    'statusCode': r.statusCode,
    'reason': r.reason,
    'body': r.body,
    'headers': r.headers,
    'elapsedMs': r.elapsedMs,
    'byteCount': r.byteCount,
    'error': _legacyError(r),
    'cancelled': r.cancelled,
    'truncated': r.truncated,
  };
  static HistoryRecord history(Map<String, dynamic> j) => HistoryRecord(
    id: j['id'] as String,
    request: request(Map<String, dynamic>.from(j['request'] as Map)),
    response: response(Map<String, dynamic>.from(j['response'] as Map)),
    time: DateTime.parse(j['time'] as String),
  );
  static Map<String, dynamic> historyJson(HistoryRecord h) => {
    'id': h.id,
    'request': requestJson(h.request),
    'response': responseJson(h.response),
    'time': h.time.toIso8601String(),
  };

  static void validate(Map<String, dynamic> j) {
    if (j['version'] != 1 ||
        [
          'requests',
          'drafts',
          'folders',
          'history',
        ].any((key) => j[key] is! List)) {
      throw const FormatException('Unsupported workspace data');
    }
  }

  static WorkspaceSnapshot decode(Map<String, dynamic> j) {
    validate(j);
    final folders = (j['folders'] as List)
        .map((f) => Folder(f['id'] as String, f['name'] as String))
        .toList();
    if (folders.isEmpty) folders.add(const Folder('default', '默认模块'));
    final folderIds = folders.map((f) => f.id).toSet();
    List<RequestSpec> requests(String key) => (j[key] as List).map((data) {
      final r = request(Map<String, dynamic>.from(data as Map));
      return folderIds.contains(r.folderId)
          ? r
          : r.copyWith(folderId: folders.first.id);
    }).toList();
    final drafts = requests('drafts');
    final active = j['activeId'] as String?;
    return WorkspaceSnapshot(
      folders: folders,
      requests: requests('requests'),
      drafts: drafts,
      history: (j['history'] as List)
          .map((h) => history(Map<String, dynamic>.from(h as Map)))
          .toList(),
      activeId: drafts.any((d) => d.id == active)
          ? active
          : drafts.lastOrNull?.id,
      timeoutSeconds: (j['timeoutSeconds'] as int? ?? 30).clamp(1, 300),
      mocks: (j['mocks'] as List? ?? [])
          .map((d) => MockJson.decode(Map<String, dynamic>.from(d as Map)))
          .toList(),
      mockDrafts: (j['mockDrafts'] as List? ?? [])
          .map((d) => MockJson.decode(Map<String, dynamic>.from(d as Map)))
          .toList(),
      mockActiveId: j['mockActiveId'] as String?,
      mockPort: (j['mockPort'] as int? ?? 3000).clamp(1, 65535),
    );
  }

  static Map<String, dynamic> encode(WorkspaceSnapshot s) => {
    'version': 1,
    'folders': s.folders.map((f) => {'id': f.id, 'name': f.name}).toList(),
    'requests': s.requests.map(requestJson).toList(),
    'drafts': s.drafts.map(requestJson).toList(),
    'history': s.history.map(historyJson).toList(),
    'activeId': s.activeId,
    'timeoutSeconds': s.timeoutSeconds,
    if (s.mocks.isNotEmpty) 'mocks': s.mocks.map(MockJson.encode).toList(),
    if (s.mockDrafts.isNotEmpty)
      'mockDrafts': s.mockDrafts.map(MockJson.encode).toList(),
    if (s.mockActiveId != null) 'mockActiveId': s.mockActiveId,
    if (s.mockPort != 3000) 'mockPort': s.mockPort,
  };

  // Historical v1 files store rendered error strings rather than error codes.
  // Keep that wire representation stable without importing presentation code.
  static String? _legacyError(ResponseRecord r) =>
      r.legacyError ??
      switch (r.failure?.code) {
        null => null,
        FailureCode.timeout => '请求超时（${r.failure!.seconds} 秒），请检查服务或调整超时设置。',
        FailureCode.tls => 'TLS 连接失败，请检查服务证书。',
        FailureCode.connection => '无法连接到服务器，请检查地址、网络和服务状态。',
        FailureCode.interrupted => 'HTTP 连接中断，请检查服务器后重试。',
        _ => '请求未能完成，请检查 URL、Headers 和请求内容。',
      };
}
