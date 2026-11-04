import 'package:weils_api/core/errors/app_failure.dart';

import '../../domain/entities/workspace_entities.dart';

import 'package:weils_api/features/mock/data/mock_json.dart';

/// 集中处理工作区 v1 磁盘格式，避免领域实体依赖 JSON 序列化。
abstract final class WorkspaceJson {
  /// 还原参数或 Header 行，旧数据缺少可选字段时使用默认值。
  static Entry entry(Map<String, dynamic> j) => Entry(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    value: j['value'] as String? ?? '',
    description: j['description'] as String? ?? '',
    enabled: j['enabled'] as bool? ?? true,
  );
  /// 将参数或 Header 行转换为可保存的 JSON 对象。
  static Map<String, dynamic> entryJson(Entry e) => {
    'id': e.id,
    'name': e.name,
    'value': e.value,
    'description': e.description,
    'enabled': e.enabled,
  };
  /// 将可选 JSON 数组还原为条目列表，缺失时返回空列表。
  static List<Entry> _entries(dynamic data) => (data as List? ?? [])
      .map((j) => entry(Map<String, dynamic>.from(j as Map)))
      .toList();
  /// 还原请求配置，未记录协议的旧请求默认使用 HTTP。
  static RequestSpec request(Map<String, dynamic> j) => RequestSpec(
    id: j['id'] as String,
    name: j['name'] as String? ?? '未命名接口',
    folderId: j['folderId'] as String? ?? 'default',
    method: j['method'] as String? ?? 'GET',
    protocol: j['protocol'] == 'sse' ? 'sse' : 'http',
    url: j['url'] as String? ?? '',
    params: _entries(j['params']),
    headers: _entries(j['headers']),
    bodyType: j['bodyType'] as String? ?? 'none',
    body: j['body'] as String? ?? '',
    authType: j['authType'] as String? ?? 'none',
    token: j['token'] as String? ?? '',
  );
  /// 序列化请求配置，默认 HTTP 协议不额外写出以兼容旧数据。
  static Map<String, dynamic> requestJson(RequestSpec r) => {
    'id': r.id,
    'name': r.name,
    'folderId': r.folderId,
    'method': r.method,
    if (r.protocol != 'http') 'protocol': r.protocol,
    'url': r.url,
    'params': r.params.map(entryJson).toList(),
    'headers': r.headers.map(entryJson).toList(),
    'bodyType': r.bodyType,
    'body': r.body,
    'authType': r.authType,
    'token': r.token,
  };
  /// 还原响应、终止状态及 SSE 元数据，保留历史错误文本。
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
    sseRequested: j['sseRequested'] == true,
    isSse: j['isSse'] == true,
    captureLimitBytes: j['captureLimitBytes'] as int?,
  );
  /// 保存响应原文与元数据；SSE 事件和拼接内容由原文重建，不重复写入。
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
    if (r.sseRequested) 'sseRequested': true,
    if (r.isSse) 'isSse': true,
    if (r.captureLimitBytes != null) 'captureLimitBytes': r.captureLimitBytes,
  };
  /// 还原一条历史记录中的请求、响应和开始时间。
  static HistoryRecord history(Map<String, dynamic> j) => HistoryRecord(
    id: j['id'] as String,
    request: request(Map<String, dynamic>.from(j['request'] as Map)),
    response: response(Map<String, dynamic>.from(j['response'] as Map)),
    time: DateTime.parse(j['time'] as String),
  );
  /// 将完整历史记录转换为本地 JSON 格式。
  static Map<String, dynamic> historyJson(HistoryRecord h) => {
    'id': h.id,
    'request': requestJson(h.request),
    'response': responseJson(h.response),
    'time': h.time.toIso8601String(),
  };

  /// 检查工作区是否为受支持的 v1 格式且必要集合均为数组。
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

  /// 还原工作区快照，修正失效的目录和选中项，并为新增设置补上默认值。
  static WorkspaceSnapshot decode(Map<String, dynamic> j) {
    validate(j);
    final folders = (j['folders'] as List)
        .map((f) => Folder(f['id'] as String, f['name'] as String))
        .toList();
    if (folders.isEmpty) folders.add(const Folder('default', '默认模块'));
    final folderIds = folders.map((f) => f.id).toSet();
    /// 还原指定请求集合，将已失效的所属目录修正为当前第一个目录。
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
      sseMaxResponseMb: (j['sseMaxResponseMb'] as int? ?? 2).clamp(1, 50),
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

  /// 输出 v1 工作区结构，新增字段使用默认值时省略，保持旧数据往返兼容。
  static Map<String, dynamic> encode(WorkspaceSnapshot s) => {
    'version': 1,
    'folders': s.folders.map((f) => {'id': f.id, 'name': f.name}).toList(),
    'requests': s.requests.map(requestJson).toList(),
    'drafts': s.drafts.map(requestJson).toList(),
    'history': s.history.map(historyJson).toList(),
    'activeId': s.activeId,
    'timeoutSeconds': s.timeoutSeconds,
    if (s.sseMaxResponseMb != 2) 'sseMaxResponseMb': s.sseMaxResponseMb,
    if (s.mocks.isNotEmpty) 'mocks': s.mocks.map(MockJson.encode).toList(),
    if (s.mockDrafts.isNotEmpty)
      'mockDrafts': s.mockDrafts.map(MockJson.encode).toList(),
    if (s.mockActiveId != null) 'mockActiveId': s.mockActiveId,
    if (s.mockPort != 3000) 'mockPort': s.mockPort,
  };

  // v1 历史记录保存错误文本；保留原有存储格式，避免数据层依赖界面代码。
  /// 将结构化网络错误映射为 v1 历史错误文本，优先保留已读取的原始错误。
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
