import '../../../../core/errors/app_failure.dart';
import '../entities/workspace_entities.dart';

abstract interface class WorkspaceRepository {
  WorkspaceState get state;
  Stream<WorkspaceState> get changes;
  Future<void> initialize();
  RequestSpec newRequest({String? folderId});
  void openRequest(RequestSpec request);
  void updateDraft(String id, RequestSpec Function(RequestSpec) update);
  void selectTab(String? id);
  void reorderDraft(int oldIndex, int newIndex);
  void closeDraft(String id);
  Future<Outcome<void>> saveDraft(String id);
  Folder addFolder(String name);
  void renameFolder(String id, String name);
  void renameRequest(String id, String name);
  void deleteRequest(String id);
  void deleteFolder(String id);
  void appendHistory(HistoryRecord record);
  Future<Outcome<void>> clearHistory();
  Future<Outcome<void>> updateSettings({
    required int timeout,
    String? directoryPath,
  });
  Future<Outcome<void>> flush({bool discardDirtyDrafts = false});
  void dismissNotice();
  void dispose();
}
