import 'dart:async';
import 'dart:io';

import 'package:weils_api/app/dependencies/app_dependencies.dart';
import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/features/settings/presentation/formatters/settings_messages.dart';
import 'package:weils_api/core/network/http_transport.dart';
import 'package:weils_api/core/platform/desktop_window.dart';
import 'package:weils_api/features/workspace/data/data_sources/workspace_data_source.dart';
import 'package:weils_api/features/workspace/data/repositories/http_request_gateway.dart';
import 'package:weils_api/features/workspace/data/repositories/local_workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/use_cases/replay_history.dart';
import 'package:weils_api/features/workspace/presentation/formatters/workspace_messages.dart';

/// Test composition only: all edits still pass through the production repository.
class WorkspaceFixture {
  WorkspaceFixture({required this.storage, this.nativeWindow = false})
    : repository = LocalWorkspaceRepository(storage);
  final WorkspaceDataSource storage;
  final LocalWorkspaceRepository repository;
  final bool nativeWindow;
  final responses = <String, ResponseRecord>{};
  AppDependencies? _dependencies;
  AppDependencies get dependencies => _dependencies ??= AppDependencies(
    workspace: repository,
    gateway: HttpRequestGateway(IoHttpTransport()),
    window: nativeWindow ? MethodChannelDesktopWindow() : FakeDesktopWindow(),
    initialResponses: responses,
  );
  WorkspaceSnapshot get snapshot => repository.state.snapshot;
  RequestSpec? get active => snapshot.active;
  List<RequestSpec> get drafts => snapshot.drafts;
  List<RequestSpec> get requests => snapshot.requests;
  List<Folder> get folders => snapshot.folders;
  List<HistoryRecord> get history => snapshot.history;
  bool get storageBlocked => repository.state.storageBlocked;
  String? get notice => workspaceNoticeMessage(repository.state.notice);
  int get timeoutSeconds => snapshot.timeoutSeconds;
  String? settingsError;
  Future<void> initialize() => repository.initialize();
  RequestSpec create(RequestSpec spec) {
    repository.openRequest(spec);
    return spec;
  }

  RequestSpec newRequest({String? folderId}) =>
      repository.newRequest(folderId: folderId);
  RequestSpec latest(String id) => snapshot.draft(id)!;
  void edit(RequestSpec spec, RequestSpec Function(RequestSpec) update) =>
      repository.updateDraft(spec.id, update);
  Folder addFolder(String name) => repository.addFolder(name);
  void deleteFolder(Folder folder) => repository.deleteFolder(folder.id);
  void selectTab(String id) => repository.selectTab(id);
  void closeDraft(String id) => repository.closeDraft(id);
  void reorderDraft(int oldIndex, int newIndex) =>
      repository.reorderDraft(oldIndex, newIndex);
  bool isDirty(RequestSpec spec) => snapshot.isDirty(latest(spec.id));
  Future<bool> save(RequestSpec spec) async =>
      (await repository.saveDraft(spec.id)).succeeded;
  Future<bool> flush({bool discardDirtyDrafts = false}) async =>
      (await repository.flush(discardDirtyDrafts: discardDirtyDrafts))
          .succeeded;
  Future<void> send(RequestSpec spec) =>
      dependencies.execution.send(latest(spec.id));
  RequestSpec replay(HistoryRecord record) => ReplayHistory(repository)(record);
  void appendHistory(HistoryRecord record) => repository.appendHistory(record);
  Future<bool> updateSettings({
    required int timeout,
    String? directoryPath,
  }) async {
    final result = await repository.updateSettings(
      timeout: timeout,
      directoryPath: directoryPath,
    );
    settingsError = settingsFailureMessage(result.failure);
    return result.succeeded;
  }

  void dispose() {
    if (_dependencies case final dependencies?) {
      dependencies.dispose();
    } else {
      repository.dispose();
    }
  }
}

class FakeDesktopWindow implements DesktopWindow {
  final events = StreamController<void>.broadcast(sync: true);
  int closes = 0;
  @override
  Stream<void> get closeRequests => events.stream;
  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<String?> selectDirectory(String initialPath) async => null;
  @override
  void dispose() {
    unawaited(events.close());
  }
}

class MemoryStorage implements WorkspaceDataSource {
  Map<String, dynamic>? data;
  @override
  String get directoryPath => 'test-workspace';
  @override
  WorkspaceNotice? get recoveryNotice => null;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    this.data = data;
  }

  @override
  Future<void> relocate(String path, Map<String, dynamic> data) async =>
      write(data);
}

class FailingStorage extends MemoryStorage {
  bool failRead = false, failWrite = false;
  @override
  Future<Map<String, dynamic>?> read() async {
    if (failRead) throw const FileSystemException('read blocked');
    return super.read();
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (failWrite) throw const FileSystemException('write blocked');
    await super.write(data);
  }
}

class RelocatingMemoryStorage extends MemoryStorage {
  String? selectedPath;
  bool failRelocation = false;
  int relocations = 0;
  @override
  String get directoryPath => selectedPath ?? super.directoryPath;
  @override
  Future<void> relocate(String path, Map<String, dynamic> data) async {
    if (failRelocation) throw const AppFailure(FailureCode.conflict);
    await write(data);
    selectedPath = path;
    relocations++;
  }
}
