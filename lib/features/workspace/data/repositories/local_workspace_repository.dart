import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/identity.dart';
import '../../domain/entities/workspace_entities.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../data_sources/workspace_data_source.dart';
import '../models/workspace_json.dart';

/// Owns the only mutable reference to the immutable workspace snapshot.
class LocalWorkspaceRepository implements WorkspaceRepository {
  LocalWorkspaceRepository(this.source)
    : _state = WorkspaceState(
        snapshot: WorkspaceSnapshot(),
        dataDirectory: source.directoryPath,
      );
  final WorkspaceDataSource source;
  WorkspaceState _state;
  @override
  WorkspaceState get state => _state;
  WorkspaceSnapshot get _snapshot => state.snapshot;
  final _changes = StreamController<WorkspaceState>.broadcast(sync: true);
  @override
  Stream<WorkspaceState> get changes => _changes.stream;
  Timer? _saveTimer;
  Future<Outcome<void>>? _settingsChange;
  bool _disposed = false;
  void _emit(WorkspaceState next) {
    _state = next;
    if (!_disposed) _changes.add(next);
  }

  void _change(WorkspaceSnapshot snapshot, {bool persist = true}) {
    _emit(state.copyWith(snapshot: snapshot));
    if (!persist || _disposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(flush()),
    );
  }

  @override
  Future<void> initialize() async {
    try {
      final data = await source.read();
      _emit(
        state.copyWith(
          snapshot: data == null ? _snapshot : WorkspaceJson.decode(data),
          ready: true,
          notice: source.recoveryNotice,
          dataDirectory: source.directoryPath,
        ),
      );
    } catch (_) {
      _emit(
        state.copyWith(
          ready: true,
          storageBlocked: true,
          notice: WorkspaceNotice.loadFailed,
        ),
      );
    }
  }

  @override
  Future<Outcome<void>> flush({bool discardDirtyDrafts = false}) async {
    _saveTimer?.cancel();
    final pending = _settingsChange;
    if (pending != null) await pending;
    if (state.storageBlocked) {
      return const Outcome.failure(AppFailure(FailureCode.read));
    }
    var snapshot = _snapshot;
    if (discardDirtyDrafts) {
      final clean = snapshot.drafts
          .where((draft) => !snapshot.isDirty(draft))
          .toList();
      snapshot = snapshot.copyWith(
        drafts: clean,
        activeId: clean.any((d) => d.id == snapshot.activeId)
            ? snapshot.activeId
            : clean.lastOrNull?.id,
      );
    }
    try {
      await source.write(WorkspaceJson.encode(snapshot));
      return const Outcome.success();
    } catch (e) {
      _emit(state.copyWith(notice: WorkspaceNotice.saveFailed));
      return Outcome.failure(AppFailure(FailureCode.write, cause: e));
    }
  }

  @override
  Future<Outcome<void>> updateSettings({
    required int timeout,
    String? directoryPath,
  }) {
    if (_settingsChange != null) return _settingsChange!;
    final operation = _updateSettings(timeout, directoryPath);
    _settingsChange = operation;
    return operation.whenComplete(() => _settingsChange = null);
  }

  Future<Outcome<void>> _updateSettings(int timeout, String? path) async {
    _saveTimer?.cancel();
    if (state.storageBlocked) {
      return const Outcome.failure(AppFailure(FailureCode.read));
    }
    if (timeout < 1 || timeout > 300) {
      return const Outcome.failure(AppFailure(FailureCode.invalidData));
    }
    try {
      final data = WorkspaceJson.encode(
        _snapshot.copyWith(timeoutSeconds: timeout),
      );
      if (path == null) {
        await source.write(data);
      } else {
        await source.relocate(path, data);
      }
      // Incorporate edits/request completions that occurred during disk IO.
      _emit(
        state.copyWith(
          snapshot: _snapshot.copyWith(timeoutSeconds: timeout),
          dataDirectory: source.directoryPath,
        ),
      );
      return const Outcome.success();
    } on AppFailure catch (e) {
      return Outcome.failure(e);
    } catch (e) {
      return Outcome.failure(AppFailure(FailureCode.write, cause: e));
    }
  }

  @override
  RequestSpec newRequest({String? folderId}) {
    final draft = RequestSpec(folderId: folderId ?? _snapshot.folders.first.id);
    _change(
      _snapshot.copyWith(
        drafts: [..._snapshot.drafts, draft],
        activeId: draft.id,
      ),
    );
    return draft;
  }

  @override
  void openRequest(RequestSpec request) => _change(
    _snapshot.copyWith(
      drafts: _snapshot.drafts.any((r) => r.id == request.id)
          ? null
          : [..._snapshot.drafts, request],
      activeId: request.id,
    ),
  );
  @override
  void updateDraft(String id, RequestSpec Function(RequestSpec) update) {
    final current = _snapshot.draft(id);
    if (current == null) return;
    final next = update(current);
    if (next.id != id) {
      throw ArgumentError('Draft identity cannot be changed by an edit');
    }
    if (next == current) return;
    _change(
      _snapshot.copyWith(
        drafts: [for (final d in _snapshot.drafts) d.id == id ? next : d],
      ),
    );
  }

  @override
  void selectTab(String? id) => _change(_snapshot.copyWith(activeId: id));
  @override
  void reorderDraft(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _snapshot.drafts.length) return;
    newIndex = newIndex.clamp(0, _snapshot.drafts.length - 1);
    if (oldIndex == newIndex) return;
    final drafts = [..._snapshot.drafts];
    drafts.insert(newIndex, drafts.removeAt(oldIndex));
    _change(_snapshot.copyWith(drafts: drafts));
  }

  @override
  Future<Outcome<void>> saveDraft(String id) async {
    final current = _snapshot.draft(id);
    if (current == null) {
      return const Outcome.failure(AppFailure(FailureCode.notFound));
    }
    final draft = current.name.trim().isEmpty
        ? current.copyWith(name: '未命名接口')
        : current;
    final old = _snapshot.requests.where((r) => r.id == id).firstOrNull;
    _change(
      _snapshot.copyWith(
        drafts: [for (final d in _snapshot.drafts) d.id == id ? draft : d],
        requests: old == null
            ? [..._snapshot.requests, draft]
            : [for (final r in _snapshot.requests) r.id == id ? draft : r],
      ),
      persist: false,
    );
    final result = await flush();
    if (!result.succeeded) {
      _change(
        _snapshot.copyWith(
          requests: [
            for (final r in _snapshot.requests)
              if (r.id != id || !identical(r, draft)) r else ?old,
          ],
        ),
        persist: false,
      );
    }
    return result;
  }

  @override
  void closeDraft(String id) {
    final index = _snapshot.drafts.indexWhere((r) => r.id == id);
    final drafts = _snapshot.drafts.where((r) => r.id != id).toList();
    _change(
      _snapshot.copyWith(
        drafts: drafts,
        activeId: _snapshot.activeId != id
            ? _snapshot.activeId
            : drafts.isEmpty
            ? null
            : drafts[index.clamp(0, drafts.length - 1)].id,
      ),
    );
  }

  @override
  Folder addFolder(String name) {
    final folder = Folder(newId(), name);
    _change(_snapshot.copyWith(folders: [..._snapshot.folders, folder]));
    return folder;
  }

  @override
  void renameFolder(String id, String name) => _change(
    _snapshot.copyWith(
      folders: [
        for (final f in _snapshot.folders)
          f.id == id ? f.copyWith(name: name) : f,
      ],
    ),
  );
  @override
  void renameRequest(String id, String name) => _change(
    _snapshot.copyWith(
      requests: [
        for (final r in _snapshot.requests)
          r.id == id ? r.copyWith(name: name) : r,
      ],
      drafts: [
        for (final r in _snapshot.drafts)
          r.id == id ? r.copyWith(name: name) : r,
      ],
    ),
  );
  @override
  void deleteRequest(String id) {
    _change(
      _snapshot.copyWith(
        requests: _snapshot.requests.where((r) => r.id != id).toList(),
      ),
      persist: false,
    );
    closeDraft(id);
  }

  @override
  void deleteFolder(String id) {
    final ids = {
      ..._snapshot.requests.where((r) => r.folderId == id).map((r) => r.id),
      ..._snapshot.drafts.where((r) => r.folderId == id).map((r) => r.id),
    };
    for (final requestId in ids) {
      deleteRequest(requestId);
    }
    final folders = _snapshot.folders.where((f) => f.id != id).toList();
    _change(
      _snapshot.copyWith(
        folders: folders.isEmpty ? [const Folder('default', '默认模块')] : folders,
      ),
    );
  }

  @override
  void appendHistory(HistoryRecord record) =>
      _change(_snapshot.copyWith(history: [record, ..._snapshot.history]));
  @override
  Future<Outcome<void>> clearHistory() async {
    final old = _snapshot.history;
    _change(_snapshot.copyWith(history: []), persist: false);
    final result = await flush();
    if (!result.succeeded) {
      _change(
        _snapshot.copyWith(history: [..._snapshot.history, ...old]),
        persist: false,
      );
    }
    return result;
  }

  @override
  void dismissNotice() => _emit(state.copyWith(notice: null));
  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    unawaited(_changes.close());
  }
}
