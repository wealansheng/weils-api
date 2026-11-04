import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/use_cases/request_headers.dart';
import '../../view_models/repository_view_model.dart';

enum EntryKind { params, headers }

typedef _EditorState = ({
  RequestSpec? draft,
  RequestSpec? saved,
  List<Folder> folders,
});

class RequestEditorViewModel extends RepositoryViewModel<_EditorState> {
  RequestEditorViewModel(
    WorkspaceRepository repository,
    this.requestId,
    this.userAgent,
  ) : _lastRequest = repository.state.snapshot.draft(requestId)!,
      super(
        repository,
        (s) => (
          draft: s.snapshot.draft(requestId),
          saved: s.snapshot.requests
              .where((r) => r.id == requestId)
              .firstOrNull,
          folders: s.snapshot.folders,
        ),
      );
  final String requestId, userAgent;
  RequestSpec _lastRequest;
  RequestSpec get request => _lastRequest = value.draft ?? _lastRequest;
  List<Folder> get folders => value.folders;
  bool get dirty => request != value.saved;
  List<DefaultHeader> get defaultHeaders =>
      defaultRequestHeaders(request, userAgent: userAgent);
  void update(RequestSpec Function(RequestSpec) change) =>
      repository.updateDraft(requestId, change);
  void setName(String v) => update((r) => r.copyWith(name: v));
  void setUrl(String v) => update((r) => r.copyWith(url: v));
  void setFolder(String v) => update((r) => r.copyWith(folderId: v));
  void setMethod(String v) => update((r) => r.copyWith(method: v));
  void setBodyType(String v) => update((r) => r.copyWith(bodyType: v));
  void setBody(String v) => update((r) => r.copyWith(body: v));
  void setAuthType(String v) => update((r) => r.copyWith(authType: v));
  void setToken(String v) => update((r) => r.copyWith(token: v));
  void _entries(EntryKind kind, List<Entry> Function(List<Entry>) change) =>
      update(
        (r) => kind == EntryKind.params
            ? r.copyWith(params: change(r.params))
            : r.copyWith(headers: change(r.headers)),
      );
  void addEntry(EntryKind kind) => _entries(kind, (rows) => [...rows, Entry()]);
  void updateEntry(EntryKind kind, String id, Entry Function(Entry) change) =>
      _entries(
        kind,
        (rows) => [for (final row in rows) row.id == id ? change(row) : row],
      );
  void deleteEntry(EntryKind kind, String id) =>
      _entries(kind, (rows) => rows.where((r) => r.id != id).toList());
}
