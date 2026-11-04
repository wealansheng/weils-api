import '../../domain/entities/workspace_snapshot.dart';

abstract interface class WorkspaceDataSource {
  String get directoryPath;
  WorkspaceNotice? get recoveryNotice;

  /// 读取工作区 JSON；首次使用没有数据时返回空值。
  Future<Map<String, dynamic>?> read();

  /// 持久化指定工作区数据，失败通过异常交给仓库处理。
  Future<void> write(Map<String, dynamic> data);

  /// 将工作区写入目标目录，并在成功后更新实际使用的数据位置。
  Future<void> relocate(String path, Map<String, dynamic> data);

  /// 校验并加载目标工作区，成功后切换目录指针；不改写目标数据。
  Future<Map<String, dynamic>> openWorkspace(String path);
}
