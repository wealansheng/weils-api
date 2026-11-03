import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/core/errors/app_failure.dart';
import 'package:weils_api/features/workspace/data/models/workspace_json.dart';
import 'package:weils_api/features/workspace/data/repositories/local_workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/use_cases/replay_history.dart';
import 'package:weils_api/features/workspace/presentation/editor/view_models/request_editor_view_model.dart';
import 'package:weils_api/features/workspace/presentation/history/view_models/history_view_model.dart';
import 'package:weils_api/features/workspace/presentation/library/view_models/library_view_model.dart';
import 'package:weils_api/features/workspace/presentation/tabs/view_models/tabs_view_model.dart';
import 'package:weils_api/features/workspace/presentation/formatters/workspace_messages.dart';

import '../../support/workspace_fixture.dart';

void main() {
  test(
    'history selection stays stable on arrival and recovers after clearing',
    () async {
      final repository = LocalWorkspaceRepository(MemoryStorage());
      await repository.initialize();
      final history = HistoryViewModel(repository, ReplayHistory(repository));
      final first = HistoryRecord(
        request: RequestSpec(),
        response: ResponseRecord(statusCode: 200),
      );
      repository.appendHistory(first);
      history.activate();
      final second = HistoryRecord(
        request: RequestSpec(),
        response: ResponseRecord(statusCode: 201),
      );
      repository.appendHistory(second);
      expect(history.selectedHistory, same(first));
      await repository.clearHistory();
      expect(history.selectedHistory, isNull);
      repository.appendHistory(second);
      history.activate();
      expect(history.selectedHistory, same(second));
      history.dispose();
      repository.dispose();
    },
  );

  test('entities detach input collections and expose immutable snapshots', () {
    final rows = [Entry(name: 'x-test', value: 'before')];
    final headers = {'x-reply': 'before'};
    final request = RequestSpec(headers: rows);
    final response = ResponseRecord(headers: headers);
    final drafts = [request];
    final snapshot = WorkspaceSnapshot(drafts: drafts);
    rows.clear();
    headers.clear();
    drafts.clear();
    expect(request.headers.single.value, 'before');
    expect(response.headers['x-reply'], 'before');
    expect(snapshot.drafts.single, same(request));
    expect(() => request.headers.clear(), throwsUnsupportedError);
    expect(() => response.headers.clear(), throwsUnsupportedError);
    expect(() => snapshot.drafts.clear(), throwsUnsupportedError);
    expect(
      request
          .copyWith(headers: [request.headers.single.copyWith(value: 'after')])
          .headers
          .single
          .value,
      'after',
    );
    expect(request.headers.single.value, 'before');
  });

  test(
    'complete legacy v1 workspace round trips without field or value changes',
    () {
      final legacy = jsonDecode(
        File('test/fixtures/workspace_v1.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final decoded = WorkspaceJson.decode(legacy);
      expect(decoded.isDirty(decoded.active!), isTrue);
      expect(decoded.history.first.response.legacyError, contains('超时'));
      expect(decoded.history.last.response.cancelled, isTrue);
      expect(WorkspaceJson.encode(decoded), legacy);
      final timeout = ResponseRecord(
        failure: const AppFailure(FailureCode.timeout, seconds: 30),
      );
      expect(WorkspaceJson.responseJson(timeout)['error'], timeout.error);
    },
  );

  test('module state listens only to its data and cancels subscriptions on dispose', () async {
    final repository = LocalWorkspaceRepository(MemoryStorage());
    await repository.initialize();
    final draft = repository.newRequest();
    final library = LibraryViewModel(repository);
    final history = HistoryViewModel(repository, ReplayHistory(repository));
    final tabs = TabsViewModel(repository);
    final editor = RequestEditorViewModel(repository, draft.id, 'test');
    var libraryChanges = 0,
        historyChanges = 0,
        tabChanges = 0,
        editorChanges = 0;
    library.addListener(() => libraryChanges++);
    history.addListener(() => historyChanges++);
    tabs.addListener(() => tabChanges++);
    editor.addListener(() => editorChanges++);
    editor.setUrl('https://example.com/edited');
    expect(
      (libraryChanges, historyChanges, tabChanges, editorChanges),
      (0, 0, 1, 1),
    );
    final before = editor.request;
    repository.appendHistory(
      HistoryRecord(request: before, response: ResponseRecord(statusCode: 200)),
    );
    expect(
      (libraryChanges, historyChanges, tabChanges, editorChanges),
      (0, 1, 1, 1),
    );
    await repository.saveDraft(draft.id);
    expect(editor.dirty, isFalse);
    editor.setBody('unsaved');
    expect(repository.state.snapshot.requests.single.body, isEmpty);
    expect(repository.state.snapshot.history.single.request, same(before));
    library.dispose();
    history.dispose();
    tabs.dispose();
    editor.dispose();
    final counts = (libraryChanges, historyChanges, tabChanges, editorChanges);
    repository.renameFolder('default', 'renamed after disposal');
    repository.updateDraft(draft.id, (r) => r.copyWith(name: 'new name'));
    expect((libraryChanges, historyChanges, tabChanges, editorChanges), counts);
    repository.dispose();
  });
}
