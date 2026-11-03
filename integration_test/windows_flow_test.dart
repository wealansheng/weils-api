import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:weils_api/core/storage.dart';
import 'package:weils_api/core/workspace_controller.dart';
import 'package:weils_api/main.dart';

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
      final c = WorkspaceController(
        storage: WorkspaceStorage(directory: directory),
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
            child: WeilsApp(controller: c),
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
        await tester.tap(find.text('请求历史'));
        await tester.pumpAndSettle();
        expect(find.text('历史快照'), findsOneWidget);
        await capture('native-history');
        await tester.tap(find.byKey(const ValueKey('replay-history')));
        await tester.pumpAndSettle();
        expect(c.active!.id, isNot(c.history.single.request.id));
        await tester.enterText(
          find.byKey(const ValueKey('request-name')),
          '历史重发草稿',
        );
        await c.flush();
        final restored = WorkspaceController(
          storage: WorkspaceStorage(directory: directory),
        );
        await restored.initialize();
        expect(restored.requests.single.name, '本地集成测试');
        expect(restored.active!.name, '历史重发草稿');
        expect(restored.history.single.request.name, '本地集成测试');
        restored.dispose();
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
