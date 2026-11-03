import 'folder.dart';
import 'request_spec.dart';
import 'history_record.dart';

const _unchanged = Object();

enum WorkspaceNotice { recoveredBackup, recoveredEmpty, loadFailed, saveFailed }

class WorkspaceSnapshot {
  WorkspaceSnapshot({
    List<Folder> folders = const [Folder('default', '默认模块')],
    List<RequestSpec> requests = const [],
    List<RequestSpec> drafts = const [],
    List<HistoryRecord> history = const [],
    this.activeId,
    this.timeoutSeconds = 30,
  }) : folders = List.unmodifiable(folders),
       requests = List.unmodifiable(requests),
       drafts = List.unmodifiable(drafts),
       history = List.unmodifiable(history);
  const WorkspaceSnapshot._(
    this.folders,
    this.requests,
    this.drafts,
    this.history,
    this.activeId,
    this.timeoutSeconds,
  );
  final List<Folder> folders;
  final List<RequestSpec> requests, drafts;
  final List<HistoryRecord> history;
  final String? activeId;
  final int timeoutSeconds;
  RequestSpec? get active => drafts.where((d) => d.id == activeId).firstOrNull;
  bool isDirty(RequestSpec draft) =>
      requests.where((r) => r.id == draft.id).firstOrNull != draft;
  bool get hasDirtyDrafts => drafts.any(isDirty);
  RequestSpec? draft(String id) => drafts.where((d) => d.id == id).firstOrNull;
  WorkspaceSnapshot copyWith({
    List<Folder>? folders,
    List<RequestSpec>? requests,
    List<RequestSpec>? drafts,
    List<HistoryRecord>? history,
    Object? activeId = _unchanged,
    int? timeoutSeconds,
  }) => WorkspaceSnapshot._(
    folders == null ? this.folders : List.unmodifiable(folders),
    requests == null ? this.requests : List.unmodifiable(requests),
    drafts == null ? this.drafts : List.unmodifiable(drafts),
    history == null ? this.history : List.unmodifiable(history),
    identical(activeId, _unchanged) ? this.activeId : activeId as String?,
    timeoutSeconds ?? this.timeoutSeconds,
  );
}

class WorkspaceState {
  const WorkspaceState({
    required this.snapshot,
    required this.dataDirectory,
    this.ready = false,
    this.storageBlocked = false,
    this.notice,
  });
  final WorkspaceSnapshot snapshot;
  final String dataDirectory;
  final bool ready, storageBlocked;
  final WorkspaceNotice? notice;
  WorkspaceState copyWith({
    WorkspaceSnapshot? snapshot,
    String? dataDirectory,
    bool? ready,
    bool? storageBlocked,
    Object? notice = _unchanged,
  }) => WorkspaceState(
    snapshot: snapshot ?? this.snapshot,
    dataDirectory: dataDirectory ?? this.dataDirectory,
    ready: ready ?? this.ready,
    storageBlocked: storageBlocked ?? this.storageBlocked,
    notice: identical(notice, _unchanged)
        ? this.notice
        : notice as WorkspaceNotice?,
  );
}
