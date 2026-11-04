import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:weils_api/app.dart';
import 'package:weils_api/features/workspace/data/data_sources/local_workspace_source.dart';
import 'package:weils_api/features/workspace/domain/use_cases/curl_codec.dart';

import '../test/support/workspace_fixture.dart';

/// 验证桌面原生剪贴板、实际网络发送和 cURL 草稿的磁盘恢复。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows: cURL import, clipboard export, HTTP/SSE and restart', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('weils-curl-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = <Map<String, Object?>>[];
    server.listen((request) async {
      received.add({
        'method': request.method,
        'tags': request.uri.queryParametersAll['tag'],
        'auth': request.headers.value('authorization'),
        'custom': request.headers.value('x-test'),
        'body': await utf8.decoder.bind(request).join(),
      });
      if (request.uri.path == '/events') {
        request.response.headers.set(
          'Content-Type',
          'text/event-stream; charset=utf-8',
        );
        request.response.write('event: update\nid: 1\ndata: 中文事件\n\n');
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"code":200,"data":"OK"}');
      }
      await request.response.close();
    });
    final fixture = WorkspaceFixture(
      nativeWindow: true,
      storage: LocalWorkspaceSource(directory: directory),
    );
    await fixture.initialize();

    /// 通过真实界面导入命令，确保导入本身不发送网络请求。
    Future<void> importCommand(String command) async {
      if (fixture.active == null) {
        await tester.tap(find.byKey(const ValueKey('import-curl-home')));
      } else {
        await tester.tap(find.byTooltip('新建接口、文件夹或导入 cURL'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('导入 cURL').last);
      }
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('curl-import-command')),
        command,
      );
      await tester.tap(find.byKey(const ValueKey('curl-import-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.dependencies.execution.running, false);
    }

    /// 点击发送后等待真实网络任务结束，超时则让测试明确失败。
    Future<void> send() async {
      await tester.tap(find.byKey(const ValueKey('send-request')));
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (!fixture.dependencies.execution.running) break;
      }
      expect(fixture.dependencies.execution.running, false);
      await tester.pumpAndSettle();
    }

    try {
      await tester.pumpWidget(WeilsApp(dependencies: fixture.dependencies));
      await tester.pumpAndSettle();
      const body = '{"name":"中文 😀","quote":"O\'Brien"}';
      final requestUrl = 'http://127.0.0.1:${server.port}/users?tag=a&tag=b';
      await importCommand(
        'curl "$requestUrl" -X POST '
        '-H "Content-Type: application/json" '
        '-H "Authorization: Bearer fixture-token" '
        '-H "X-Test: roundtrip" --data-raw \'${body.replaceAll("'", "'\"'\"'")}\'',
      );
      final imported = fixture.active!;
      expect(imported.body, body);
      expect(imported.authType, 'bearer');
      expect(received, isEmpty);
      for (final shell in CurlShell.values) {
        await tester.tap(find.byKey(const ValueKey('export-curl')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            ValueKey(
              shell == CurlShell.bash
                  ? 'export-curl-bash'
                  : 'export-curl-powershell',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
        final decoded = CurlCodec.parse(clipboard!.text!, shell: shell);
        expect(decoded.body, body);
        expect(decoded.token, 'fixture-token');
        expect(decoded.effectiveUri, imported.effectiveUri);
      }
      await send();
      expect(received.single, {
        'method': 'POST',
        'tags': ['a', 'b'],
        'auth': 'Bearer fixture-token',
        'custom': 'roundtrip',
        'body': body,
      });
      expect(fixture.history.single.response.statusCode, 200);
      await importCommand(
        'curl -N http://127.0.0.1:${server.port}/events '
        '-H "Accept: text/event-stream" --json \'{"question":"你好"}\'',
      );
      expect(fixture.active!.protocol, 'sse');
      expect(fixture.history, hasLength(1));
      await send();
      expect(fixture.history, hasLength(2));
      expect(fixture.history.first.response.body, contains('中文事件'));
      expect(await fixture.flush(), true);
      final restored = WorkspaceFixture(
        storage: LocalWorkspaceSource(directory: directory),
      );
      try {
        await restored.initialize();
        expect(restored.storageBlocked, false);
        expect(restored.drafts, hasLength(2));
        expect(restored.active!.protocol, 'sse');
        expect(restored.history, hasLength(2));
        expect(restored.latest(imported.id).body, body);
        expect(restored.replay(restored.history.first).protocol, 'sse');
      } finally {
        restored.dispose();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    } finally {
      fixture.dispose();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}
