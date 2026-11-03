import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/workspace_entities.dart';

String? workspaceNoticeMessage(WorkspaceNotice? notice) => switch (notice) {
  null => null,
  WorkspaceNotice.recoveredBackup => '数据文件无法读取，已恢复上一次备份。原文件已保留在数据目录。',
  WorkspaceNotice.recoveredEmpty => '数据文件无法读取，已打开空白工作区。原文件已保留在数据目录，可用于恢复。',
  WorkspaceNotice.loadFailed => '无法读取本地数据，为避免覆盖原文件，已暂停保存。请检查数据目录的文件与访问权限，然后重启。',
  WorkspaceNotice.saveFailed => '本地保存失败，编辑内容仍在内存中。请检查磁盘空间和数据目录权限，再尝试保存。',
};
String? validationMessage(RequestValidation? validation) =>
    switch (validation) {
      null => null,
      RequestValidation.invalidUrl =>
        '请输入完整的 HTTP 或 HTTPS 地址，例如 https://api.example.com/users',
      RequestValidation.invalidUrlFormat => 'URL 格式不正确，请检查后重试。',
      RequestValidation.invalidJsonOrUrl => 'URL 或 JSON 格式不正确，请检查后重试。',
      RequestValidation.invalidHeader => 'Header 名称或值包含无效字符，请检查 Headers。',
      RequestValidation.invalidToken => 'Bearer Token 不能包含换行。',
    };
String networkFailureMessage(AppFailure failure) => switch (failure.code) {
  FailureCode.timeout => '请求超时（${failure.seconds} 秒），请检查服务或调整超时设置。',
  FailureCode.tls => 'TLS 连接失败，请检查服务证书。',
  FailureCode.connection => '无法连接到服务器，请检查地址、网络和服务状态。',
  FailureCode.interrupted => 'HTTP 连接中断，请检查服务器后重试。',
  _ => '请求未能完成，请检查 URL、Headers 和请求内容。',
};

extension ResponsePresentation on ResponseRecord {
  String? get error =>
      legacyError ?? (failure == null ? null : networkFailureMessage(failure!));
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
}
