import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:weils_api/features/workspace/data/data_sources/local_workspace_source.dart';

import '../test/support/workspace_fixture.dart';

import 'package:weils_api/app.dart';
import 'package:weils_api/features/workspace/domain/entities/request_spec.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows: create, save, send real request, inspect history and restore after restart',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'weils-windows-flow-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 0,
            'message': 'success',
            'data': {
              'list': [
                {'id': 1001, 'name': '本地测试用户'},
              ],
              'total': 1,
            },
          }),
        );
        await request.response.close();
      });
      final c = WorkspaceFixture(
        nativeWindow: true,
        storage: LocalWorkspaceSource(directory: directory),
      );
      await c.initialize();
      final key = GlobalKey();
      Future<void> capture(String name) async {
        final messenger = ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold)),
        );
        messenger.clearSnackBars();
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory(
          const String.fromEnvironment(
            'REVIEW_DIR',
            defaultValue: '.impeccable/review',
          ),
        );
        await output.create(recursive: true);
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }

      try {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: WeilsApp(dependencies: c.dependencies),
          ),
        );
        await capture('native-home');
        await tester.tap(find.byKey(const ValueKey('create-request')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('request-name')),
          '本地集成测试',
        );
        await tester.enterText(
          find.byKey(const ValueKey('request-url')),
          'http://127.0.0.1:${server.port}/users',
        );
        final original = c.active!;
        final extra = c.create(RequestSpec(name: '用户详情'));
        final extraLast = c.create(RequestSpec(name: '更新用户'));
        c.selectTab(original.id);
        await tester.pumpAndSettle();
        final originalTab = find.byKey(ValueKey('request-tab-${original.id}'));
        final originalLabel = find.descendant(
          of: originalTab,
          matching: find.text(original.name),
        );
        final start = tester.getCenter(originalLabel);
        final lastRect = tester.getRect(
          find.byKey(ValueKey('request-tab-${extraLast.id}')),
        );
        final end = Offset(lastRect.right - 8, start.dy);
        final gesture = await tester.startGesture(
          start,
          kind: ui.PointerDeviceKind.mouse,
        );
        for (var step = 1; step <= 16; step++) {
          await gesture.moveTo(Offset.lerp(start, end, step / 16)!);
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.pump(const Duration(milliseconds: 350));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(c.drafts, [extra, extraLast, original]);
        expect(c.active, same(original));
        await capture('native-tabs-reordered');
        await c.flush();
        final reordered = WorkspaceFixture(
          nativeWindow: true,
          storage: LocalWorkspaceSource(directory: directory),
        );
        await reordered.initialize();
        expect(reordered.drafts.map((r) => r.id), [
          extra.id,
          extraLast.id,
          original.id,
        ]);
        expect(reordered.active!.id, original.id);
        reordered.dispose();
        c.closeDraft(extra.id);
        c.closeDraft(extraLast.id);
        await tester.pumpAndSettle();
        final method = find.byKey(const ValueKey('request-method-trigger'));
        Rect? firstMethodRow;
        for (final value in ['OPTIONS', 'GET']) {
          await tester.tap(method);
          await tester.pumpAndSettle();
          final first = tester.getRect(
            find.byKey(const ValueKey('request-method-option-GET')),
          );
          expect(first.top, greaterThan(tester.getRect(method).bottom));
          if (firstMethodRow != null) expect(first, firstMethodRow);
          firstMethodRow = first;
          if (value == 'GET') await capture('native-dropdown-method');
          await tester.tap(
            find.byKey(ValueKey('request-method-option-$value')),
          );
          await tester.pumpAndSettle();
          expect(c.active!.method, value);
        }
        final folder = c.addFolder('用户服务');
        await tester.pumpAndSettle();
        final folderTrigger = find.byKey(
          const ValueKey('request-folder-trigger'),
        );
        await tester.tap(folderTrigger);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('request-folder-option-${folder.id}')),
        );
        await tester.pumpAndSettle();
        expect(c.active!.folderId, folder.id);
        await tester.tap(folderTrigger);
        await tester.pumpAndSettle();
        await capture('native-dropdown-folder');
        await tester.tap(
          find.byKey(const ValueKey('request-folder-option-default')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Headers').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('添加Header'));
        await tester.pumpAndSettle();
        final header = c.active!.headers.last;
        await tester.enterText(
          find.byKey(ValueKey('${header.id}-name')),
          'X-Client',
        );
        await tester.enterText(
          find.byKey(ValueKey('${header.id}-value')),
          'weils-local',
        );
        await tester.pumpAndSettle();
        await capture('native-headers');
        await tester.tap(find.text('Params'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        await c.flush();
        expect(c.requests.single.name, '本地集成测试');
        await tester.tap(find.byKey(const ValueKey('send-request')));
        for (var i = 0; i < 60 && c.history.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(c.history.single.response.statusCode, 200);
        expect(c.history.single.response.body, contains('本地测试用户'));
        await capture('native-editor');
        await tester.tap(find.text('Headers').last);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('response-headers-table')),
          findsOneWidget,
        );
        expect(find.text('application/json; charset=utf-8'), findsOneWidget);
        await capture('native-response-headers');
        await tester.tap(find.text('请求历史'));
        await tester.pumpAndSettle();
        expect(find.text('历史快照'), findsOneWidget);
        await capture('native-history');
        await tester.tap(find.text('Headers').last);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('response-headers-table')),
          findsOneWidget,
        );
        expect(find.text('application/json; charset=utf-8'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('replay-history')));
        await tester.pumpAndSettle();
        expect(c.active!.id, isNot(c.history.single.request.id));
        await tester.enterText(
          find.byKey(const ValueKey('request-name')),
          '历史重发草稿',
        );
        await c.flush();
        final restored = WorkspaceFixture(
          nativeWindow: true,
          storage: LocalWorkspaceSource(directory: directory),
        );
        await restored.initialize();
        expect(restored.requests.single.name, '本地集成测试');
        expect(restored.active!.name, '历史重发草稿');
        expect(restored.history.single.request.name, '本地集成测试');
        restored.dispose();
        final sourceFile = (c.storage as LocalWorkspaceSource).file;
        final originalData = await sourceFile.readAsString();
        final target = await Directory('${directory.path}/移动后的 数据').create();
        const windowChannel = MethodChannel('weils/window');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          windowChannel,
          (call) async {
            expect(call.method, 'selectDirectory');
            return target.path;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            windowChannel,
            null,
          ),
        );
        await tester.tap(find.text('设置'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('choose-data-directory')));
        await tester.pumpAndSettle();
        await capture('native-settings-directory');
        await tester.tap(find.text('保存设置'));
        for (
          var i = 0;
          i < 100 && find.text('保存设置').evaluate().isNotEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('保存设置'), findsNothing);
        expect(c.storage.directoryPath, await target.resolveSymbolicLinks());
        expect(await sourceFile.readAsString(), originalData);
        final relocated = WorkspaceFixture(
          nativeWindow: true,
          storage: LocalWorkspaceSource(directory: directory),
        );
        try {
          await relocated.initialize();
          expect(
            relocated.storage.directoryPath,
            await target.resolveSymbolicLinks(),
          );
          expect(relocated.active!.name, '历史重发草稿');
          expect(relocated.requests.single.name, '本地集成测试');
          expect(relocated.history.single.response.statusCode, 200);
        } finally {
          relocated.dispose();
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } finally {
        c.dispose();
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );
}
