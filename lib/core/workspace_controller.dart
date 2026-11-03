import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'request_executor.dart';
import 'storage.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({WorkspaceStorage? storage, RequestExecutor? executor})
    : storage = storage ?? WorkspaceStorage(),
      executor = executor ?? RequestExecutor();
  final WorkspaceStorage storage;
  final RequestExecutor executor;
  final List<Folder> folders = [Folder('default', '默认模块')];
  final List<RequestSpec> requests = [];
  final List<RequestSpec> drafts = [];
  final List<HistoryRecord> history = [];
  final Map<String, ResponseRecord> responses = {};
  String? activeId, selectedHistoryId, runningId, notice, validationError;
  int timeoutSeconds = 30;
  bool ready = false, historyMode = false, storageBlocked = false;
  bool _disposed = false;
  Timer? _saveTimer;
  Future<bool>? _settingsChange;
  String? settingsError;
  RequestOperation? _operation;
  bool get running => _operation != null;
  RequestSpec? get active => drafts.where((d) => d.id == activeId).firstOrNull;
  HistoryRecord? get selectedHistory =>
      history.where((h) => h.id == selectedHistoryId).firstOrNull;
  bool isDirty(RequestSpec draft) =>
      requests.where((s) => s.id == draft.id).firstOrNull?.fingerprint !=
      draft.fingerprint;
  bool get hasDirtyDrafts => drafts.any(isDirty);

  Future<void> initialize() async {
    try {
      final json = await storage.read();
      if (json != null) {
        final loadedFolders = (json['folders'] as List)
            .map((e) => Folder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final loadedRequests = (json['requests'] as List)
            .map(
              (e) => RequestSpec.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        final loadedDrafts = (json['drafts'] as List)
            .map(
              (e) => RequestSpec.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        final loadedHistory = (json['history'] as List)
            .map(
              (e) =>
                  HistoryRecord.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        folders
          ..clear()
          ..addAll(loadedFolders);
        if (folders.isEmpty) folders.add(Folder('default', '默认模块'));
        requests.addAll(loadedRequests);
        drafts.addAll(loadedDrafts);
        history.addAll(loadedHistory);
        timeoutSeconds = (json['timeoutSeconds'] as int? ?? 30).clamp(1, 300);
        activeId = json['activeId'] as String?;
        if (active == null) activeId = drafts.lastOrNull?.id;
        final folderIds = folders.map((f) => f.id).toSet();
        for (final request in [...requests, ...drafts]) {
          if (!folderIds.contains(request.folderId)) {
            request.folderId = folders.first.id;
          }
        }
      }
      notice = storage.recoveryNotice;
    } catch (_) {
      storageBlocked = true;
      notice = '无法读取本地数据，为避免覆盖原文件，已暂停保存。请检查数据目录的文件与访问权限，然后重启。';
    }
    ready = true;
    _notify();
  }

  Map<String, dynamic> snapshot() => {
    'version': 1,
    'folders': folders.map((f) => f.toJson()).toList(),
    'requests': requests.map((r) => r.toJson()).toList(),
    'drafts': drafts.map((r) => r.toJson()).toList(),
    'history': history.map((h) => h.toJson()).toList(),
    'activeId': activeId,
    'timeoutSeconds': timeoutSeconds,
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void changed() {
    validationError = null;
    _notify();
    if (_disposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(flush());
    });
  }

  Future<bool> flush({bool discardDirtyDrafts = false}) async {
    _saveTimer?.cancel();
    final pending = _settingsChange;
    if (pending != null) await pending;
    if (storageBlocked) return false;
    try {
      final data = snapshot();
      if (discardDirtyDrafts) {
        final clean = drafts.where((draft) => !isDirty(draft)).toList();
        data['drafts'] = clean.map((draft) => draft.toJson()).toList();
        data['activeId'] = clean.any((draft) => draft.id == activeId)
            ? activeId
            : clean.lastOrNull?.id;
      }
      await storage.write(data);
      return true;
    } catch (_) {
      notice = '本地保存失败，编辑内容仍在内存中。请检查磁盘空间和数据目录权限，再尝试保存。';
      _notify();
      return false;
    }
  }

  Future<bool> updateSettings({required int timeout, String? directoryPath}) {
    if (_settingsChange != null) return _settingsChange!;
    final operation = _updateSettings(timeout, directoryPath);
    _settingsChange = operation;
    return operation.whenComplete(() => _settingsChange = null);
  }

  Future<bool> _updateSettings(int timeout, String? directoryPath) async {
    _saveTimer?.cancel();
    settingsError = null;
    if (storageBlocked) {
      settingsError = '请先恢复本地数据，再更改设置。';
      return false;
    }
    if (timeout < 1 || timeout > 300) {
      settingsError = '请填写 1–300 之间的整数';
      return false;
    }
    try {
      final data = snapshot()..['timeoutSeconds'] = timeout;
      if (directoryPath == null) {
        await storage.write(data);
      } else {
        await storage.relocate(directoryPath, data);
      }
      timeoutSeconds = timeout;
      _notify();
      return true;
    } on StorageLocationException catch (e) {
      settingsError = e.message;
    } catch (_) {
      settingsError = '设置未能保存，请检查所选目录的访问权限和磁盘空间。原目录仍在使用。';
    }
    return false;
  }

  RequestSpec newRequest({String? folderId}) {
    final spec = RequestSpec(folderId: folderId ?? folders.first.id);
    drafts.add(spec);
    activeId = spec.id;
    historyMode = false;
    changed();
    return spec;
  }

  void open(RequestSpec request) {
    if (!drafts.any((d) => d.id == request.id)) drafts.add(request.copy());
    activeId = request.id;
    historyMode = false;
    changed();
  }

  void selectTab(String? id) {
    activeId = id;
    historyMode = false;
    changed();
  }

  /// [newIndex] is the final position, as supplied by onReorderItem.
  void reorderDraft(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= drafts.length) return;
    newIndex = newIndex.clamp(0, drafts.length - 1);
    if (oldIndex == newIndex) return;
    drafts.insert(newIndex, drafts.removeAt(oldIndex));
    changed();
  }

  void showHistory() {
    historyMode = true;
    selectedHistoryId ??= history.firstOrNull?.id;
    _notify();
  }

  void selectHistory(HistoryRecord record) {
    selectedHistoryId = record.id;
    _notify();
  }

  RequestSpec replay(HistoryRecord record) {
    final spec = record.request.copy(newIdentity: true);
    spec.name = '${spec.name} · 重发';
    if (!folders.any((f) => f.id == spec.folderId)) {
      spec.folderId = folders.first.id;
    }
    drafts.add(spec);
    activeId = spec.id;
    historyMode = false;
    changed();
    return spec;
  }

  Future<bool> save(RequestSpec draft) async {
    if (draft.name.trim().isEmpty) draft.name = '未命名接口';
    final index = requests.indexWhere((r) => r.id == draft.id);
    final old = index < 0 ? null : requests[index];
    if (index < 0) {
      requests.add(draft.copy());
    } else {
      requests[index] = draft.copy();
    }
    final success = await flush();
    if (!success) {
      if (index < 0) {
        requests.removeWhere((r) => r.id == draft.id);
      } else {
        requests[index] = old!;
      }
    }
    _notify();
    return success;
  }

  void closeDraft(String id) {
    final index = drafts.indexWhere((d) => d.id == id);
    drafts.removeWhere((d) => d.id == id);
    responses.remove(id);
    if (activeId == id) {
      activeId = drafts.isEmpty
          ? null
          : drafts[index.clamp(0, drafts.length - 1)].id;
    }
    changed();
  }

  Folder addFolder(String name) {
    final folder = Folder(newId(), name);
    folders.add(folder);
    changed();
    return folder;
  }

  void renameFolder(Folder folder, String name) {
    folder.name = name;
    changed();
  }

  void renameRequest(RequestSpec request, String name) {
    request.name = name;
    for (final d in drafts.where((d) => d.id == request.id)) {
      d.name = name;
    }
    changed();
  }

  void deleteRequest(String id) {
    requests.removeWhere((r) => r.id == id);
    closeDraft(id);
  }

  void deleteFolder(Folder folder) {
    final ids = {
      ...requests.where((r) => r.folderId == folder.id).map((r) => r.id),
      ...drafts.where((r) => r.folderId == folder.id).map((r) => r.id),
    };
    for (final id in ids) {
      deleteRequest(id);
    }
    folders.remove(folder);
    if (folders.isEmpty) folders.add(Folder('default', '默认模块'));
    changed();
  }

  Future<void> send(RequestSpec draft) async {
    if (running) return;
    validationError = draft.validate();
    if (validationError != null) {
      _notify();
      return;
    }
    final spec = draft.copy();
    final startedAt = DateTime.now();
    runningId = draft.id;
    _operation = executor.start(
      spec,
      timeout: Duration(seconds: timeoutSeconds),
    );
    _notify();
    final result = await _operation!.result;
    responses[draft.id] = result;
    history.insert(
      0,
      HistoryRecord(request: spec, response: result, time: startedAt),
    );
    _operation = null;
    runningId = null;
    changed();
    await flush();
  }

  void cancel() => _operation?.cancel();
  Future<void> stop() async {
    final operation = _operation;
    if (operation != null) {
      operation.cancel();
      await operation.result;
    }
  }

  Future<bool> clearHistory() async {
    final old = List<HistoryRecord>.of(history);
    history.clear();
    selectedHistoryId = null;
    if (!await flush()) {
      history.addAll(old);
      _notify();
      return false;
    }
    _notify();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _operation?.cancel();
    super.dispose();
  }
}
