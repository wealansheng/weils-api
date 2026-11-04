import 'dart:async';
import 'dart:convert';

import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/core/utils/identity.dart';
import '../../domain/entities/workspace_entities.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../data_sources/workspace_data_source.dart';
import '../models/workspace_json.dart';
import 'package:weils_api/features/mock/domain/entities/mock_definition.dart';
import 'package:weils_api/features/mock/domain/use_cases/generate_mock.dart';

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
  Future<Outcome<void>>? _mockChange;
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

  void _clearSaveFailure() {
    if (state.notice == WorkspaceNotice.saveFailed) {
      _emit(state.copyWith(notice: null));
    }
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
    await _mockChange;
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
        mockDrafts: snapshot.mockDrafts
            .where((d) => !snapshot.isMockDirty(d))
            .toList(),
        mockActiveId:
            snapshot.mockDrafts.any(
              (d) => d.id == snapshot.mockActiveId && !snapshot.isMockDirty(d),
            )
            ? snapshot.mockActiveId
            : null,
        drafts: clean,
        activeId: clean.any((d) => d.id == snapshot.activeId)
            ? snapshot.activeId
            : clean.lastOrNull?.id,
      );
    }
    try {
      await source.write(WorkspaceJson.encode(snapshot));
      _clearSaveFailure();
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
    await _mockChange;
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
      _clearSaveFailure();
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
  MockDefinition newMock() {
    final draft = MockDefinition(path: '/mock-${newId().substring(0, 8)}');
    _change(
      _snapshot.copyWith(
        mockDrafts: [..._snapshot.mockDrafts, draft],
        mockActiveId: draft.id,
      ),
    );
    return draft;
  }

  @override
  void selectMock(String id) {
    final saved = _snapshot.mocks.where((d) => d.id == id).firstOrNull;
    _change(
      _snapshot.copyWith(
        mockDrafts: _snapshot.mockDrafts.any((d) => d.id == id) || saved == null
            ? null
            : [..._snapshot.mockDrafts, saved],
        mockActiveId: id,
      ),
    );
  }

  @override
  void updateMockDraft(
    String id,
    MockDefinition Function(MockDefinition) update,
  ) {
    final draft = _snapshot.mockDrafts.where((d) => d.id == id).firstOrNull;
    if (draft == null) return;
    final next = update(draft);
    if (next.id != id) throw ArgumentError('Mock identity cannot be changed');
    if (next == draft) return;
    _change(
      _snapshot.copyWith(
        mockDrafts: [
          for (final d in _snapshot.mockDrafts) d.id == id ? next : d,
        ],
      ),
    );
  }

  /// Serialize commits and publish saved definitions only after disk success.
  /// Ordinary flushes wait for this transaction before taking their snapshot.
  Future<Outcome<void>> _commitMock(
    Future<Outcome<void>> Function() operation,
  ) {
    final previous = _mockChange;
    final settings = _settingsChange;
    final task = Future<Outcome<void>>(() async {
      await previous;
      await settings;
      if (state.storageBlocked) {
        return const Outcome.failure(AppFailure(FailureCode.read));
      }
      try {
        final result = await operation();
        if (result.succeeded) _clearSaveFailure();
        return result;
      } on MockValidationException catch (e) {
        return Outcome.failure(AppFailure(FailureCode.invalidData, cause: e));
      } on Object catch (e) {
        _emit(state.copyWith(notice: WorkspaceNotice.saveFailed));
        return Outcome.failure(AppFailure(FailureCode.write, cause: e));
      }
    });
    _mockChange = task;
    unawaited(
      task.then((_) {
        if (identical(_mockChange, task)) _mockChange = null;
      }),
    );
    return task;
  }

  @override
  Future<Outcome<void>> saveMock(String id) => _commitMock(() async {
    final draft = _snapshot.mockDrafts.where((d) => d.id == id).firstOrNull;
    if (draft == null) {
      return const Outcome.failure(AppFailure(FailureCode.notFound));
    }
    validateMockDefinition(draft, _snapshot.mocks);
    for (final scenario in draft.scenarios) {
      if (scenario.bodyType == 'json') {
        MockGenerator().generate(scenario.body);
      } else if (utf8.encode(scenario.body).length > mockMaxBytes) {
        throw const MockValidationException('响应正文超过 2 MB');
      }
    }
    final saved = [
      for (final d in _snapshot.mocks)
        if (d.id != id) d,
      draft,
    ];
    await source.write(WorkspaceJson.encode(_snapshot.copyWith(mocks: saved)));
    _change(_snapshot.copyWith(mocks: saved), persist: false);
    return const Outcome.success();
  });

  @override
  Future<Outcome<void>> deleteMock(String id) => _commitMock(() async {
    WorkspaceSnapshot remove(WorkspaceSnapshot s) => s.copyWith(
      mocks: s.mocks.where((d) => d.id != id).toList(),
      mockDrafts: s.mockDrafts.where((d) => d.id != id).toList(),
      mockActiveId: s.mockActiveId == id ? null : s.mockActiveId,
    );
    await source.write(WorkspaceJson.encode(remove(_snapshot)));
    _change(remove(_snapshot), persist: false);
    return const Outcome.success();
  });

  @override
  Future<Outcome<void>> setMockPort(int port) => _commitMock(() async {
    if (port < 1 || port > 65535) {
      return const Outcome.failure(AppFailure(FailureCode.invalidData));
    }
    await source.write(
      WorkspaceJson.encode(_snapshot.copyWith(mockPort: port)),
    );
    _change(_snapshot.copyWith(mockPort: port), persist: false);
    return const Outcome.success();
  });
  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    unawaited(_changes.close());
  }
}
