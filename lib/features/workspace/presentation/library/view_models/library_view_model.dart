import '../../../domain/entities/workspace_entities.dart';
import '../../../domain/repositories/workspace_repository.dart';
import '../../view_models/repository_view_model.dart';

typedef _LibraryState = ({
  List<Folder> folders,
  List<RequestSpec> requests,
  String? activeId,
});

class LibraryViewModel extends RepositoryViewModel<_LibraryState> {
  LibraryViewModel(WorkspaceRepository repository)
    : super(
        repository,
        (s) => (
          folders: s.snapshot.folders,
          requests: s.snapshot.requests,
          activeId: s.snapshot.activeId,
        ),
      );
  String _query = '';
  String get query => _query;
  List<Folder> get folders => value.folders;
  List<RequestSpec> get requests => value.requests;
  String? get activeId => value.activeId;
  void search(String query) {
    _query = query.trim().toLowerCase();
    notifyListeners();
  }

  bool matches(RequestSpec r) =>
      '${r.name} ${r.url}'.toLowerCase().contains(query);
  bool folderContainsDraft(String folderId, String draftId) => repository
      .state
      .snapshot
      .drafts
      .any((r) => r.id == draftId && r.folderId == folderId);
  void newRequest({String? folderId}) =>
      repository.newRequest(folderId: folderId);
  void open(RequestSpec request) => repository.openRequest(request);
  void addFolder(String name) => repository.addFolder(name);
  void renameFolder(Folder folder, String name) =>
      repository.renameFolder(folder.id, name);
  void renameRequest(RequestSpec request, String name) =>
      repository.renameRequest(request.id, name);
  void deleteFolder(Folder folder) => repository.deleteFolder(folder.id);
  void deleteRequest(String id) => repository.deleteRequest(id);
}
