import 'package:weils_api/core/errors/app_failure.dart';

import '../repositories/workspace_repository.dart';

/// 将设置更新与可选的数据目录迁移作为同一次仓库操作提交。
class UpdateWorkspaceSettings {
  const UpdateWorkspaceSettings(this.repository);
  final WorkspaceRepository repository;
  /// 将全局设置保存请求交给工作区仓库，统一返回写入或目录迁移结果。
  Future<Outcome<void>> call({
    required int timeout,
    String? directoryPath,
    int? sseMaxResponseMb,
  }) => repository.updateSettings(
    timeout: timeout,
    directoryPath: directoryPath,
    sseMaxResponseMb: sseMaxResponseMb,
  );
}
