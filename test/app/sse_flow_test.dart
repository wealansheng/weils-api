import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/app.dart';
import 'package:weils_api/app/dependencies/app_dependencies.dart';
import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/features/workspace/data/repositories/local_workspace_repository.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/repositories/request_gateway.dart';
import 'package:weils_api/features/workspace/presentation/editor/widgets/response_pane.dart';
import 'package:weils_api/features/workspace/presentation/editor/widgets/sse_response_pane.dart';

import '../support/workspace_fixture.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      for (final font in [
        ('Microsoft YaHei', 'msyh.ttc'),
        ('Segoe UI', 'segoeui.ttf'),
        ('Consolas', 'consola.ttf'),
      ]) {
        final file = File('C:/Windows/Fonts/${font.$2}');
        if (await file.exists()) {
          await (FontLoader(font.$1)..addFont(
                Future.value(ByteData.sublistView(await file.readAsBytes())),
              ))
              .load();
        }
      }
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('.impeccable/review').create(recursive: true);
      await File('.impeccable/review/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [const Size(1440, 800), const Size(1280, 720)]) {
    testWidgets('SSE mode, live views, copy, navigation and stop at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage();
      final repository = LocalWorkspaceRepository(storage);
      await repository.initialize();
      final draft = repository.newRequest();
      repository.updateDraft(
        draft.id,
        (r) => r.copyWith(name: '实时事件', url: 'http://localhost/events'),
      );
      final gateway = _StreamingGateway();
      final window = FakeDesktopWindow();
      final dependencies = AppDependencies(
        workspace: repository,
        gateway: gateway,
        window: window,
      );
      addTearDown(dependencies.dispose);
      addTearDown(gateway.dispose);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: WeilsApp(dependencies: dependencies),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('request-protocol-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('request-protocol-option-sse')),
      );
      await tester.pumpAndSettle();
      expect(repository.state.snapshot.active!.protocol, 'sse');
      await tester.tap(find.byKey(const ValueKey('send-request')));
      await tester.pump();
      expect(gateway.sent!.protocol, 'sse');
      expect(find.text('停止'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('request-protocol-trigger')),
            )
            .onPressed,
        isNull,
      );
      const raw = 'id: 7\nevent: delta\ndata: hello\n\ndata: world\n\n';
      gateway.emit(raw);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('event: delta'), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('2 个事件'), findsOneWidget);
      await capture(tester, key, 'sse-events-${size.width.toInt()}');
      await tester.tap(find.byKey(const ValueKey('copy-sse-response')));
      await tester.pump();
      expect(copied, contains('event: delta'));
      await tester.tap(find.text('拼接 data'));
      await tester.pump();
      expect(find.text('helloworld'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('copy-sse-response')));
      await tester.pump();
      expect(copied, 'helloworld');
      await tester.tap(find.text('原文'));
      await tester.pump();
      expect(find.byKey(const ValueKey('sse-raw')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('copy-sse-response')));
      await tester.pump();
      expect(copied, raw);
      final responseHeaders = find.descendant(
        of: find.byType(SseResponsePane),
        matching: find.text('Headers'),
      );
      await tester.tap(responseHeaders);
      await tester.pump();
      expect(find.text('text/event-stream'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('copy-sse-response')));
      await tester.pump();
      expect(copied, 'content-type: text/event-stream');
      await tester.tap(find.text('请求历史'));
      await tester.pump();
      expect(dependencies.execution.running, true);
      gateway.emit('${raw}data: again\n\n');
      await tester.pump();
      await tester.tap(find.text('接口管理').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('3 个事件'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('send-request')));
      await tester.pumpAndSettle();
      expect(find.text('已停止'), findsOneWidget);
      expect(repository.state.snapshot.history, hasLength(1));
      expect(
        repository.state.snapshot.history.single.response.sseData,
        'helloworldagain',
      );
      expect(find.text('again'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'SSE prevents closing an active tab and saves partial history on exit',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = LocalWorkspaceRepository(MemoryStorage());
      await repository.initialize();
      final request = repository.newRequest();
      repository.updateDraft(
        request.id,
        (r) => r.copyWith(protocol: 'sse', url: 'http://localhost/events'),
      );
      await repository.saveDraft(request.id);
      final gateway = _StreamingGateway();
      final window = FakeDesktopWindow();
      final dependencies = AppDependencies(
        workspace: repository,
        gateway: gateway,
        window: window,
      );
      addTearDown(dependencies.dispose);
      addTearDown(gateway.dispose);
      await tester.pumpWidget(WeilsApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('send-request')));
      gateway.emit('data: retained before exit\n\n');
      await tester.pump();
      await tester.tap(find.byTooltip('关闭标签页'));
      await tester.pump();
    expect(find.text('请先停止当前请求，再关闭标签页'), findsOneWidget);
      expect(repository.state.snapshot.draft(request.id), isNotNull);
      window.events.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('当前请求仍在进行，退出将取消这次请求。'), findsOneWidget);
      await tester.tap(find.text('继续退出'));
      await tester.pumpAndSettle();
      expect(window.closes, 1);
      expect(
        repository.state.snapshot.history.single.response.sseData,
        'retained before exit',
      );
      expect(repository.state.snapshot.history.single.response.cancelled, true);
      expect(dependencies.execution.running, false);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('SSE capture setting validates range, saves and cancels edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = WorkspaceFixture(storage: MemoryStorage());
    addTearDown(fixture.dispose);
    await fixture.initialize();
    await tester.pumpWidget(WeilsApp(dependencies: fixture.dependencies));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('sse-max-response-mb'));
    for (final value in ['0', '51']) {
      await tester.enterText(field, value);
      await tester.tap(find.text('保存设置'));
      await tester.pumpAndSettle();
      expect(find.text('请填写 1–50 之间的整数'), findsOneWidget);
      expect(fixture.snapshot.sseMaxResponseMb, 2);
    }
    await tester.enterText(field, '8');
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();
    expect(fixture.snapshot.sseMaxResponseMb, 8);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).controller!.text, '8');
    await tester.enterText(field, '20');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(fixture.snapshot.sseMaxResponseMb, 8);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'SSE fallback, truncation and failure leave raw content accessible',
    (tester) async {
      for (final response in [
        ResponseRecord(
          statusCode: 401,
          body: '{"error":"unauthorized"}',
          sseRequested: true,
        ),
        ResponseRecord(
          statusCode: 200,
          body: 'data: retained\n\n',
          sseRequested: true,
          isSse: true,
          truncated: true,
          captureLimitBytes: 8 * 1024 * 1024,
        ),
        ResponseRecord(
          statusCode: 200,
          body: 'data: retained\n\n',
          sseRequested: true,
          isSse: true,
          legacyError: '连接中断',
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            home: Scaffold(body: ResponsePane(response: response)),
          ),
        );
        await tester.pumpAndSettle();
        if (response.truncated) {
          expect(find.textContaining('8 MB 捕获上限'), findsOneWidget);
        }
        if (response.isSse) {
          await tester.tap(find.text('原文'));
          await tester.pump();
        }
        expect(
          tester
              .widget<SelectableText>(find.byKey(const ValueKey('sse-raw')))
              .data,
          response.body,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'SSE follows the end and preserves scroll position when reading older events',
    (tester) async {
      ResponseRecord response(int count) => ResponseRecord(
        statusCode: 200,
        isSse: true,
        sseRequested: true,
        body: List.generate(count, (i) => 'data: event $i\n\n').join(),
      );
      final value = ValueNotifier(response(80));
      addTearDown(value.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: value,
              builder: (_, r, _) =>
                  SseResponsePane(response: r, running: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('sse-events'));
      final controller = tester.widget<ListView>(list).controller!;
      expect(controller.offset, greaterThan(0));
      value.value = response(81);
      await tester.pumpAndSettle();
      expect(controller.position.extentAfter, lessThan(40));
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      value.value = response(82);
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _StreamingGateway implements RequestGateway {
  final _updates = StreamController<ResponseRecord>(sync: true);
  final _result = Completer<ResponseRecord>();
  RequestSpec? sent;
  String _body = '';
  int _limit = 2 * 1024 * 1024;
  ResponseRecord record({bool cancelled = false}) => ResponseRecord(
    statusCode: 200,
    reason: 'OK',
    body: _body,
    isSse: true,
    sseRequested: true,
    headers: const {'content-type': 'text/event-stream'},
    byteCount: utf8.encode(_body).length,
    captureLimitBytes: _limit,
    cancelled: cancelled,
  );
  void emit(String body) {
    _body = body;
    _updates.add(record());
  }

  @override
  RequestTask<ResponseRecord> start(
    RequestSpec request, {
    required Duration timeout,
    int sseMaxResponseMb = 2,
  }) {
    sent = request;
    _limit = sseMaxResponseMb * 1024 * 1024;
    return RequestTask(
      () {
        if (!_result.isCompleted) _result.complete(record(cancelled: true));
      },
      _result.future,
      updates: _updates.stream,
    );
  }

  void dispose() {
    unawaited(_updates.close());
  }
}
