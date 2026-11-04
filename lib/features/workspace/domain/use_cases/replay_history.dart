import '../entities/workspace_entities.dart';
import '../repositories/workspace_repository.dart';

class ReplayHistory {
  const ReplayHistory(this.repository);
  final WorkspaceRepository repository;
  /// 将历史请求复制为新标识草稿，保留协议与请求配置，原目录已删除时使用默认目录。
  RequestSpec call(HistoryRecord record) {
    final folders = repository.state.snapshot.folders;
    final draft = record.request.copyWith(
      newIdentity: true,
      name: '${record.request.name} · 重发',
      folderId: folders.any((f) => f.id == record.request.folderId)
          ? record.request.folderId
          : folders.first.id,
    );
    repository.openRequest(draft);
    return draft;
  }
}
