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

/// 统一持有和替换不可变工作区快照，作为工作区状态的唯一写入入口。
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
  bool _openingWorkspace = false;

  /// 替换当前状态，并在仓库未释放时同步通知订阅者。
  void _emit(WorkspaceState next) {
    _state = next;
    if (!_disposed) _changes.add(next);
  }

  /// 更新工作区快照，默认使用 400 毫秒防抖合并自动保存。
  void _change(WorkspaceSnapshot snapshot, {bool persist = true}) {
    if (_openingWorkspace) throw const AppFailure(FailureCode.busy);
    _emit(state.copyWith(snapshot: snapshot));
    if (!persist || _disposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(flush()),
    );
  }

  /// 写入恢复成功后清除保存失败提示，其他提示保持不变。
  void _clearSaveFailure() {
    if (state.notice == WorkspaceNotice.saveFailed) {
      _emit(state.copyWith(notice: null));
    }
  }

  /// 加载或恢复本地工作区；读取失败时进入禁止写入状态，保护原数据。
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

  /// 等待设置和 Mock 提交完成后落盘，失败时返回结果并保留内存编辑。
  /// 退出时可只从待写快照排除未保存草稿，不修改用户仍在编辑的内容。
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

  /// 复用正在执行的设置保存任务，避免同时提交多个设置事务。
  @override
  Future<Outcome<void>> updateSettings({
    required int timeout,
    int? sseMaxResponseMb,
    String? directoryPath,
  }) {
    if (_settingsChange != null) return _settingsChange!;
    final operation = _updateSettings(timeout, directoryPath, sseMaxResponseMb);
    _settingsChange = operation;
    return operation.whenComplete(() => _settingsChange = null);
  }

  /// 保存设置；空目录迁移当前数据，已有工作区先保留当前草稿再完整加载。
  Future<Outcome<void>> _updateSettings(
    int timeout,
    String? path,
    int? sseMaxResponseMb,
  ) async {
    _saveTimer?.cancel();
    await _mockChange;
    if (state.storageBlocked) {
      return const Outcome.failure(AppFailure(FailureCode.read));
    }
    if (timeout < 1 ||
        timeout > 300 ||
        (sseMaxResponseMb != null &&
            (sseMaxResponseMb < 1 || sseMaxResponseMb > 50))) {
      return const Outcome.failure(AppFailure(FailureCode.invalidData));
    }
    try {
      final data = WorkspaceJson.encode(
        _snapshot.copyWith(
          timeoutSeconds: timeout,
          sseMaxResponseMb: sseMaxResponseMb,
        ),
      );
      if (path == null) {
        await source.write(data);
      } else {
        try {
          await source.relocate(path, data);
        } on AppFailure catch (e) {
          if (e.code != FailureCode.conflict) rethrow;
          _openingWorkspace = true;
          try {
            // 草稿和历史留在原目录，目标工作区保留自己的设置与已保存内容。
            await source.write(WorkspaceJson.encode(_snapshot));
            final loaded = await source.openWorkspace(path);
            _emit(
              state.copyWith(
                snapshot: WorkspaceJson.decode(loaded),
                dataDirectory: source.directoryPath,
                notice: null,
                workspaceRevision: state.workspaceRevision + 1,
              ),
            );
          } finally {
            _openingWorkspace = false;
          }
          return const Outcome.success();
        }
      }
      // 合并磁盘操作期间产生的编辑和请求结果，避免用旧快照覆盖新状态。
      _emit(
        state.copyWith(
          snapshot: _snapshot.copyWith(
            timeoutSeconds: timeout,
            sseMaxResponseMb: sseMaxResponseMb,
          ),
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

  /// 在指定目录或默认目录新建草稿，并将其设为当前标签页。
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

  /// 打开并选中请求；相同标识的草稿已打开时不重复添加。
  @override
  void openRequest(RequestSpec request) => _change(
    _snapshot.copyWith(
      drafts: _snapshot.drafts.any((r) => r.id == request.id)
          ? null
          : [..._snapshot.drafts, request],
      activeId: request.id,
    ),
  );

  /// 按标识替换草稿，禁止编辑改变实体标识，内容未变化时不触发保存。
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

  /// 切换当前标签页，并将选中状态纳入自动保存。
  @override
  void selectTab(String? id) => _change(_snapshot.copyWith(activeId: id));

  /// 将草稿移动到有效目标位置，忽略无效来源与未变化的顺序。
  @override
  void reorderDraft(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _snapshot.drafts.length) return;
    newIndex = newIndex.clamp(0, _snapshot.drafts.length - 1);
    if (oldIndex == newIndex) return;
    final drafts = [..._snapshot.drafts];
    drafts.insert(newIndex, drafts.removeAt(oldIndex));
    _change(_snapshot.copyWith(drafts: drafts));
  }

  /// 将草稿提交为已保存接口并立即落盘，失败时回滚已保存版本且保留草稿。
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

  /// 移除草稿；关闭当前标签页时选中相邻标签页，并安排持久化。
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

  /// 创建带有新标识的接口目录，并安排持久化。
  @override
  Folder addFolder(String name) {
    final folder = Folder(newId(), name);
    _change(_snapshot.copyWith(folders: [..._snapshot.folders, folder]));
    return folder;
  }

  /// 按标识修改目录名称，保留其余目录及请求关联。
  @override
  void renameFolder(String id, String name) => _change(
    _snapshot.copyWith(
      folders: [
        for (final f in _snapshot.folders)
          f.id == id ? f.copyWith(name: name) : f,
      ],
    ),
  );

  /// 同步修改已保存接口与同标识草稿的名称。
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

  /// 删除已保存接口，并关闭对应草稿标签页。
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

  /// 删除目录及关联的接口与草稿；没有剩余目录时恢复默认目录。
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

  /// 将请求结束记录放到历史列表首位，并安排持久化。
  @override
  void appendHistory(HistoryRecord record) =>
      _change(_snapshot.copyWith(history: [record, ..._snapshot.history]));

  /// 清空历史并立即保存；失败时恢复旧记录，同时保留期间新增的历史。
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

  /// 清除当前工作区提示，不修改工作区内容。
  @override
  void dismissNotice() => _emit(state.copyWith(notice: null));

  /// 创建带独立默认路径的 Mock 草稿，并设为当前编辑项。
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

  /// 选中 Mock；尚未打开时从已保存定义创建编辑草稿。
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

  /// 编辑指定 Mock 草稿，禁止修改标识，忽略未变化的结果。
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

  /// 串行执行 Mock 提交，并等待已有设置事务；只有磁盘写入成功才发布已保存定义。
  /// 普通保存会等待此事务，避免旧快照覆盖已提交的 Mock。
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

  /// 校验路由、场景和响应模板，落盘成功后才更新服务可见的已保存定义。
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

  /// 在串行事务中删除 Mock，写入成功后同步移除草稿与选中状态。
  @override
  Future<Outcome<void>> deleteMock(String id) => _commitMock(() async {
    /// 从给定快照移除目标 Mock 及其草稿，保留其他并发修改。
    WorkspaceSnapshot remove(WorkspaceSnapshot s) => s.copyWith(
      mocks: s.mocks.where((d) => d.id != id).toList(),
      mockDrafts: s.mockDrafts.where((d) => d.id != id).toList(),
      mockActiveId: s.mockActiveId == id ? null : s.mockActiveId,
    );
    await source.write(WorkspaceJson.encode(remove(_snapshot)));
    _change(remove(_snapshot), persist: false);
    return const Outcome.success();
  });

  /// 校验并保存 Mock 端口，成功后再更新内存设置。
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

  /// 停止自动保存并关闭状态流，阻止释放后继续发布状态。
  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    unawaited(_changes.close());
  }
}
