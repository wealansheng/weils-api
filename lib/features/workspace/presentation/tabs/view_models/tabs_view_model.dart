import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/repositories/workspace_repository.dart';
import '../../view_models/repository_view_model.dart';

typedef _TabsState = ({
  List<RequestSpec> drafts,
  List<RequestSpec> requests,
  String? activeId,
});

class TabsViewModel extends RepositoryViewModel<_TabsState> {
  TabsViewModel(WorkspaceRepository repository)
    : super(
        repository,
        (s) => (
          drafts: s.snapshot.drafts,
          requests: s.snapshot.requests,
          activeId: s.snapshot.activeId,
        ),
      );
  List<RequestSpec> get drafts => value.drafts;
  String? get activeId => value.activeId;
  RequestSpec? get active =>
      value.drafts.where((d) => d.id == activeId).firstOrNull;
  /// 查询指定请求草稿是否存在未保存修改。
  bool isDirty(RequestSpec draft) =>
      value.requests.where((r) => r.id == draft.id).firstOrNull != draft;
  /// 将标签页选择交给仓库，并持久化当前选中项。
  void selectTab(String? id) => repository.selectTab(id);
  /// 将拖拽后的标签页顺序交给仓库更新。
  void reorderDraft(int oldIndex, int newIndex) =>
      repository.reorderDraft(oldIndex, newIndex);
}
