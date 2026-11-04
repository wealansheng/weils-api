import '../../features/workspace/domain/entities/workspace_snapshot.dart';
import '../../features/workspace/domain/repositories/workspace_repository.dart';
import '../../features/workspace/presentation/view_models/repository_view_model.dart';

typedef _BootstrapState = ({bool ready, bool blocked, WorkspaceNotice? notice});

class BootstrapViewModel extends RepositoryViewModel<_BootstrapState> {
  BootstrapViewModel(WorkspaceRepository repository)
    : super(
        repository,
        (s) => (ready: s.ready, blocked: s.storageBlocked, notice: s.notice),
      );
  bool get ready => value.ready;
  bool get storageBlocked => value.blocked;
  WorkspaceNotice? get notice => value.notice;
  /// 清除工作区当前提示，初始化和持久化状态仍由仓库维护。
  void dismissNotice() => repository.dismissNotice();
}
