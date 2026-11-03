import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/app.dart';

import '../support/workspace_fixture.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      for (final item in [
        ('Microsoft YaHei', 'msyh.ttc'),
        ('Consolas', 'consola.ttf'),
        ('Segoe UI', 'segoeui.ttf'),
      ]) {
        final font = File('C:/Windows/Fonts/${item.$2}');
        if (await font.exists()) {
          final loader = FontLoader(item.$1)
            ..addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())),
            );
          await loader.load();
        }
      }
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
        .clearSnackBars();
    await tester.pumpAndSettle();
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

  Finder input(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  for (final size in [const Size(1440, 800), const Size(1280, 720)]) {
    testWidgets(
      'Mock editor, conditions, field table, preview, shortcuts and navigation at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = WorkspaceFixture(storage: MemoryStorage());
        await c.initialize();
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: WeilsApp(dependencies: c.dependencies),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock 管理').first);
        await tester.pumpAndSettle();
        expect(find.text('创建本地 Mock 接口'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('create-mock')));
        await tester.pumpAndSettle();
        await tester.enterText(input('接口名称'), '用户 Mock');
        await tester.enterText(input('路径'), '/users/:id');
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('mock-body')),
            matching: find.byType(TextField),
          ),
          '{"users|3-3":[{"id|+1":1,"name":"@cname"}]}',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('preview-mock')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('mock-preview')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('mock-field-builder')));
        await tester.pumpAndSettle();
        await tester.enterText(input('字段名'), 'success');
        await tester.enterText(input('值 / 模板'), 'true');
        await tester.tap(find.byKey(const ValueKey('apply-field-template')));
        await tester.pumpAndSettle();
        expect(find.text('替换响应模板？'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, '替换模板'));
        await tester.pumpAndSettle();
        expect(
          c.snapshot.activeMock!.scenarios.single.body,
          contains('"success": true'),
        );
        await tester.tap(find.byKey(const ValueKey('save-mock')));
        await tester.pumpAndSettle();
        expect(c.snapshot.mocks, hasLength(1));
        expect(c.snapshot.hasDirtyDrafts, false);
        await tester.tap(find.byKey(const ValueKey('add-mock-scenario')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('匹配条件'));
        await tester.pumpAndSettle();
        await tester.enterText(input('Header 名称'), 'X-Role');
        await tester.enterText(input('等于（文本）'), 'admin');
        await tester.tap(find.byKey(const ValueKey('add-mock-condition')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('mock-condition-1-trigger')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('mock-condition-1-option-body')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(input('JSON Pointer'), '/role');
        await tester.enterText(input('等于（JSON 值）'), '"admin"');
        await tester.tap(find.byKey(const ValueKey('save-mock')));
        await tester.pumpAndSettle();
        expect(c.snapshot.mocks.single.scenarios.last.conditions, hasLength(2));
        await capture(tester, key, 'mock-conditions-${size.width.toInt()}');
        await tester.tap(find.text('响应 Headers'));
        await tester.pumpAndSettle();
        await tester.enterText(input('响应 Headers（JSON）'), '{"X-Mock":"true"}');
        await tester.tap(find.text('响应正文'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('mock-body')),
            matching: find.byType(TextField),
          ),
          '{"data|3-3":[{"id|+1":1,"name":"@cname","email":"@email"}]}',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('preview-mock')));
        await tester.pumpAndSettle();
        await capture(tester, key, 'mock-editor-${size.width.toInt()}');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(c.snapshot.hasDirtyDrafts, false);
        await tester.tap(find.text('请求历史'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock 管理').first);
        await tester.pumpAndSettle();
        expect(c.snapshot.activeMock!.name, '用户 Mock');
        expect(find.text('用户 Mock'), findsWidgets);
        expect(c.history, isEmpty);
        final count = c.snapshot.mockDrafts.length;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(c.snapshot.mockDrafts, hasLength(count + 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      },
    );
  }

  testWidgets('Mock errors, exit protection, discard, and service ownership', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = FailingStorage();
    final c = WorkspaceFixture(storage: storage);
    await c.initialize();
    c.dependencies.mocking.create();
    final id = c.snapshot.activeMock!.id;
    c.repository.updateMockDraft(id, (d) => d.copyWith(path: '/exit'));
    await tester.pumpWidget(WeilsApp(dependencies: c.dependencies));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mock 管理').first);
    await tester.pumpAndSettle();
    storage.failWrite = true;
    await tester.tap(find.byKey(const ValueKey('save-mock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mock-error')), findsOneWidget);
    expect(c.snapshot.mocks, isEmpty);
    storage.failWrite = false;
    await tester.runAsync(() => c.dependencies.mocking.toggle('not a port'));
    await tester.pumpAndSettle();
    expect(find.text('端口须为 1–65535 的整数'), findsOneWidget);
    final window = c.dependencies.window as FakeDesktopWindow;
    window.events.add(null);
    await tester.pumpAndSettle();
    expect(find.textContaining('含 Mock'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(window.closes, 0);
    window.events.add(null);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '全部保存'));
    await tester.pumpAndSettle();
    expect(window.closes, 1);
    expect(c.snapshot.mocks.single.path, '/exit');
    c.repository.updateMockDraft(id, (d) => d.copyWith(name: 'discard this'));
    window.events.add(null);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '放弃修改'));
    await tester.pumpAndSettle();
    expect(window.closes, 2);
    expect((storage.data!['mockDrafts'] as List?) ?? [], isEmpty);
    final server = c.dependencies.mockServer;
    await tester.runAsync(() => server.start(0, () => c.snapshot.mocks));
    expect(server.running, true);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    expect(server.running, false);
  });
}
