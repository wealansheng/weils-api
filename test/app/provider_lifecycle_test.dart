import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:weils_api/app.dart';
import 'package:weils_api/app/dependencies/app_dependencies.dart';
import 'package:weils_api/app/navigation/app_navigation.dart';
import 'package:weils_api/features/workspace/data/repositories/local_workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/presentation/editor/request_editor.dart';
import 'package:weils_api/features/workspace/presentation/editor/view_models/request_editor_view_model.dart';
import 'package:weils_api/features/workspace/presentation/history/view_models/history_view_model.dart';

import '../support/controlled_gateway.dart';
import '../support/workspace_fixture.dart';

void main() {
  testWidgets(
    'scoped editor disposes while request and history selection survive page changes',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage();
      final repository = LocalWorkspaceRepository(storage);
      await repository.initialize();
      final first = repository.newRequest();
      repository.updateDraft(
        first.id,
        (r) => r.copyWith(
          name: 'First',
          url: 'https://example.com/before',
          body: 'draft body',
        ),
      );
      final oldHistory = HistoryRecord(
        request: first,
        response: ResponseRecord(statusCode: 204),
      );
      repository.appendHistory(oldHistory);
      final gateway = ControlledGateway();
      final window = FakeDesktopWindow();
      final dependencies = AppDependencies(
        workspace: repository,
        gateway: gateway,
        window: window,
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(WeilsApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      final firstEditor = tester
          .element(find.byType(RequestEditor))
          .read<RequestEditorViewModel>();
      final navigation = tester
          .element(find.byType(RequestEditor))
          .read<AppNavigation>();
      final history = tester
          .element(find.byType(RequestEditor))
          .read<HistoryViewModel>();
      history.activate();
      final sending = dependencies.execution.send(firstEditor.request);
      firstEditor.setUrl('https://example.com/edited-during-send');
      final second = repository.newRequest();
      await tester.pumpAndSettle();
      expect(() => firstEditor.addListener(() {}), throwsFlutterError);
      expect(dependencies.execution.runningId, first.id);
      final secondEditor = tester
          .element(find.byType(RequestEditor))
          .read<RequestEditorViewModel>();
      expect(secondEditor.requestId, second.id);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('send-request')))
            .onPressed,
        isNull,
      );
      navigation.select(AppDestination.history);
      await tester.pumpAndSettle();
      expect(() => secondEditor.addListener(() {}), throwsFlutterError);
      gateway.result.complete(
        ResponseRecord(statusCode: 200, body: 'completed away from editor'),
      );
      await sending;
      await tester.pumpAndSettle();
      expect(repository.state.snapshot.history, hasLength(2));
      expect(
        repository.state.snapshot.history.first.request.url,
        'https://example.com/before',
      );
      expect(history.selectedHistory, same(oldHistory));
      expect(dependencies.execution.running, isFalse);
      expect(
        dependencies.execution.responseFor(first.id)!.body,
        'completed away from editor',
      );
      repository.selectTab(first.id);
      navigation.select(AppDestination.workspace);
      await tester.pumpAndSettle();
      final restoredEditor = tester
          .element(find.byType(RequestEditor))
          .read<RequestEditorViewModel>();
      expect(
        restoredEditor.request.url,
        'https://example.com/edited-during-send',
      );
      expect(restoredEditor.request.body, 'draft body');
      expect(find.text('completed away from editor'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(() => restoredEditor.addListener(() {}), throwsFlutterError);
      expect(() => history.addListener(() {}), throwsFlutterError);
      // Injected application dependencies remain owned by the test, not Provider.
      repository.newRequest();
      expect((await repository.flush()).succeeded, isTrue);
      expect(gateway.cancellations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'application dependencies release the active request and platform once',
    () async {
      final repository = LocalWorkspaceRepository(MemoryStorage());
      await repository.initialize();
      final draft = repository.newRequest();
      repository.updateDraft(
        draft.id,
        (r) => r.copyWith(url: 'https://example.com'),
      );
      final gateway = ControlledGateway();
      final window = FakeDesktopWindow();
      final dependencies = AppDependencies(
        workspace: repository,
        gateway: gateway,
        window: window,
      );
      final sending = dependencies.execution.send(
        repository.state.snapshot.active!,
      );
      dependencies.dispose();
      dependencies.dispose();
      await sending;
      expect(gateway.cancellations, 1);
      expect(window.events.isClosed, isTrue);
      expect(
        repository.state.snapshot.history.single.response.cancelled,
        isTrue,
      );
    },
  );
}
