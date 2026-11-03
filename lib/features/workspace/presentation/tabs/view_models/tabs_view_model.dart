import '../../../domain/entities/workspace_entities.dart';
import '../../../domain/repositories/workspace_repository.dart';
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
  bool isDirty(RequestSpec draft) =>
      value.requests.where((r) => r.id == draft.id).firstOrNull != draft;
  void selectTab(String? id) => repository.selectTab(id);
  void reorderDraft(int oldIndex, int newIndex) =>
      repository.reorderDraft(oldIndex, newIndex);
}
