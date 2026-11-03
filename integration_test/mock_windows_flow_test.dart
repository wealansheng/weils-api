import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:weils_api/app.dart';
import 'package:weils_api/features/workspace/data/data_sources/local_workspace_source.dart';

import '../test/support/workspace_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows: configure Mock, call real service, publish saved edits and restart',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'weils-native-mock-',
      );
      var fixture = WorkspaceFixture(
        storage: LocalWorkspaceSource(directory: directory),
      );
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close(force: true);
      final client = HttpClient();
      Finder input(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      Future<void> settleService(bool running) async {
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (fixture.dependencies.mockServer.running == running &&
              !fixture.dependencies.mocking.busy) {
            break;
          }
        }
        await tester.pumpAndSettle();
        expect(fixture.dependencies.mockServer.running, running);
      }

      Future<Map<String, dynamic>> call([String tail = '42']) async {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/users/$tail'),
        );
        final response = await request.close();
        expect(response.statusCode, 200);
        return jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
      }

      try {
        await fixture.initialize();
        await tester.pumpWidget(WeilsApp(dependencies: fixture.dependencies));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mock 管理').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('create-mock')));
        await tester.pumpAndSettle();
        await tester.enterText(input('接口名称'), 'Windows 本地 Mock');
        await tester.enterText(input('路径'), '/users/*');
        await tester.enterText(
          input('响应 JSON 模板'),
          '{"version":1,"tail":"{{path.*}}","users|2-2":[{"id|+1":1,"name":"@cname"}]}',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('save-mock')));
        await tester.pumpAndSettle();
        expect(fixture.snapshot.mocks, hasLength(1));
        await tester.enterText(input('端口'), '$port');
        await tester.tap(find.byKey(const ValueKey('toggle-mock-server')));
        await settleService(true);
        final first = await call('42/details');
        expect(first['version'], 1);
        expect(first['tail'], '42/details');
        expect(first['users'], hasLength(2));
        await tester.enterText(input('响应 JSON 模板'), '{"version":2}');
        await tester.pump();
        expect((await call())['version'], 1);
        await tester.tap(find.byKey(const ValueKey('save-mock')));
        await tester.pumpAndSettle();
        expect((await call())['version'], 2);
        await tester.tap(find.text('请求历史'));
        await tester.pumpAndSettle();
        expect(fixture.history, isEmpty);
        await tester.tap(find.text('Mock 管理').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('toggle-mock-server')));
        await settleService(false);
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
        fixture = WorkspaceFixture(
          storage: LocalWorkspaceSource(directory: directory),
        );
        await fixture.initialize();
        expect(fixture.snapshot.mocks.single.name, 'Windows 本地 Mock');
        expect(fixture.snapshot.mockPort, port);
        expect(fixture.dependencies.mockServer.running, false);
        final replacement = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        await replacement.close(force: true);
      } finally {
        client.close(force: true);
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
