import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:weils_api/app.dart';
import 'package:weils_api/features/workspace/data/data_sources/local_workspace_source.dart';
import 'package:weils_api/features/workspace/domain/entities/request_spec.dart';

import '../test/support/workspace_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows: real SSE POST, live view, stop and restore history', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'weils-native-sse-',
    );
    final source = LocalWorkspaceSource(directory: directory);
    final c = WorkspaceFixture(storage: source, nativeWindow: true);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final hold = Completer<void>();
    String? received;
    server.listen((request) async {
      try {
        received = await utf8.decoder.bind(request).join();
        request.response.bufferOutput = false;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'id: 1\nevent: delta\ndata: 原生 SSE 已连接\n\ndata: 流式响应持续接收中\n\n',
        );
        await request.response.flush();
        await hold.future;
        await request.response.close();
      } on HttpException {
        /* Stopping the client closes the connection. */
      } on SocketException {
        /* Stopping the client closes the connection. */
      }
    });
    try {
      await c.initialize();
      final request = c.create(
        RequestSpec(
          name: '本地 SSE 集成验证',
          protocol: 'sse',
          method: 'POST',
          url: 'http://127.0.0.1:${server.port}/events',
          bodyType: 'json',
          body: '{"stream":true}',
        ),
      );
      expect(await c.save(request), true);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: WeilsApp(dependencies: c.dependencies),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('send-request')));
      for (
        var i = 0;
        i < 100 &&
            c.dependencies.execution
                    .responseFor(request.id)
                    ?.sseEvents
                    .length !=
                2;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        c.dependencies.execution.responseFor(request.id)!.sseEvents,
        hasLength(2),
      );
      expect(c.dependencies.execution.running, true);
      expect(c.history, isEmpty);
      expect(received, '{"stream":true}');
      expect(find.text('原生 SSE 已连接'), findsOneWidget);
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = Directory(
        const String.fromEnvironment(
          'REVIEW_DIR',
          defaultValue: 'build/review',
        ),
      );
      await output.create(recursive: true);
      await File('${output.path}/native-sse.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      await tester.tap(find.text('拼接 data'));
      await tester.pump();
      expect(find.text('原生 SSE 已连接流式响应持续接收中'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('send-request')));
      for (var i = 0; i < 100 && c.dependencies.execution.running; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.dependencies.execution.running, false);
      expect(c.history, hasLength(1));
      expect(c.history.single.response.cancelled, true);
      expect(c.history.single.response.sseEvents, hasLength(2));
      final restored = WorkspaceFixture(
        storage: LocalWorkspaceSource(directory: directory),
      );
      try {
        await restored.initialize();
        expect(restored.requests.single.protocol, 'sse');
        expect(restored.history.single.response.sseData, '原生 SSE 已连接流式响应持续接收中');
      } finally {
        restored.dispose();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    } finally {
      c.dispose();
      hold.complete();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}
