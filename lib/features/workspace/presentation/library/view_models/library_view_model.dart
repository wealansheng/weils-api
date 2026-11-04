import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/repositories/workspace_repository.dart';
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
  /// 规范化接口库搜索文本并通知列表刷新。
  void search(String query) {
    _query = query.trim().toLowerCase();
    notifyListeners();
  }

  /// 根据名称和 URL 进行不区分大小写的接口筛选。
  bool matches(RequestSpec r) =>
      '${r.name} ${r.url}'.toLowerCase().contains(query);
  /// 判断指定草稿是否属于目标目录，供删除前的运行状态检查使用。
  bool folderContainsDraft(String folderId, String draftId) => repository
      .state
      .snapshot
      .drafts
      .any((r) => r.id == draftId && r.folderId == folderId);
  /// 在指定目录新建并打开请求草稿。
  void newRequest({String? folderId}) =>
      repository.newRequest(folderId: folderId);
  /// 打开并选中指定接口的编辑草稿。
  void open(RequestSpec request) => repository.openRequest(request);
  /// 将新建目录操作转交工作区仓库。
  void addFolder(String name) => repository.addFolder(name);
  /// 按目录标识提交新名称。
  void renameFolder(Folder folder, String name) =>
      repository.renameFolder(folder.id, name);
  /// 按请求标识提交新名称，并由仓库同步已打开草稿。
  void renameRequest(RequestSpec request, String name) =>
      repository.renameRequest(request.id, name);
  /// 删除指定目录及关联请求，确认交互由界面负责。
  void deleteFolder(Folder folder) => repository.deleteFolder(folder.id);
  /// 删除指定请求及其打开的草稿。
  void deleteRequest(String id) => repository.deleteRequest(id);
}
