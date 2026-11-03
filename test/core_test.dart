import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/core/models.dart';
import 'package:weils_api/core/request_executor.dart';
import 'package:weils_api/core/storage.dart';
import 'package:weils_api/core/workspace_controller.dart';

void main() {
  late Directory directory;
  late WorkspaceController c;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('weils-core-');
    c = WorkspaceController(storage: WorkspaceStorage(directory: directory));
    await c.initialize();
  });
  tearDown(() async {
    c.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'URL query overrides preserve duplicates, encoding, and disabled keys',
    () {
      final spec = RequestSpec(
        url: 'http://localhost/users?old=1&tag=a&tag=b&disabled=1#fragment',
        params: [
          Entry(name: 'old', value: '2'),
          Entry(name: 'q', value: '中文 & test'),
          Entry(name: 'disabled', value: '2', enabled: false),
          Entry(name: 'list', value: 'a'),
          Entry(name: 'list', value: 'b'),
        ],
      );
      expect(spec.validate(), isNull);
      expect(spec.effectiveUri.queryParametersAll, {
        'old': ['2'],
        'tag': ['a', 'b'],
        'q': ['中文 & test'],
        'list': ['a', 'b'],
      });
      spec.url = 'http://localhost/?old=1';
      spec.params
        ..clear()
        ..add(Entry(name: 'old', enabled: false));
      expect(spec.effectiveUri.queryParameters, isEmpty);
      expect(spec.effectiveUri.toString(), 'http://localhost/');
    },
  );

  test('JSON, scheme, and header injection fail validation before network', () {
    expect(RequestSpec(url: 'file:///local').validate(), isNotNull);
    expect(
      RequestSpec(
        url: 'https://example.com',
        bodyType: 'json',
        body: '{broken',
      ).validate(),
      isNotNull,
    );
    expect(
      RequestSpec(
        url: 'https://example.com',
        headers: [Entry(name: 'x-test', value: 'a\r\nb')],
      ).validate(),
      isNotNull,
    );
  });

  test('real HTTP request sends JSON, enabled query/headers and Bearer auth; persists immutable history', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<Map<String, dynamic>>();
    server.listen((request) async {
      received.complete({
        'method': request.method,
        'query': request.uri.queryParameters,
        'auth': request.headers.value('authorization'),
        'header': request.headers.value('x-test'),
        'ignored': request.headers.value('x-ignored'),
        'body': await utf8.decoder.bind(request).join(),
      });
      request.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..headers.set('x-reply', 'yes')
        ..write('{"ok":true,"message":"你好"}');
      await request.response.close();
    });
    try {
      final draft = c.newRequest()
        ..name = '本地测试'
        ..method = 'POST'
        ..url = 'http://127.0.0.1:${server.port}/users'
        ..bodyType = 'json'
        ..body = '{"name":"测试"}'
        ..authType = 'bearer'
        ..token = 'local-token';
      draft.params.add(Entry(name: 'page', value: '2'));
      draft.headers.addAll([
        Entry(name: 'x-test', value: 'yes'),
        Entry(name: 'x-ignored', value: 'no', enabled: false),
      ]);
      await c.send(draft);
      final actual = await received.future;
      expect(actual, {
        'method': 'POST',
        'query': {'page': '2'},
        'auth': 'Bearer local-token',
        'header': 'yes',
        'ignored': null,
        'body': '{"name":"测试"}',
      });
      expect(c.history.single.response.statusCode, 201);
      expect(c.history.single.response.body, contains('你好'));
      expect(c.history.single.response.headers['x-reply'], 'yes');
      expect(
        c.requests,
        isEmpty,
        reason: 'sending must not save the interface definition',
      );
      final original = c.history.single;
      final replay = c.replay(original)
        ..name = '重发修改'
        ..body = 'new body';
      expect(replay.id, isNot(original.request.id));
      expect(original.request.body, '{"name":"测试"}');
      expect(original.request.name, '本地测试');
      await c.flush();
      final reopened = WorkspaceController(
        storage: WorkspaceStorage(directory: directory),
      );
      await reopened.initialize();
      expect(reopened.history.single.response.statusCode, 201);
      expect(reopened.active!.name, '重发修改');
      reopened.dispose();
    } finally {
      await server.close(force: true);
    }
  });

  test('HTTP errors retain body; timeout and cancellation produce distinct results', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/error') {
        request.response
          ..statusCode = 422
          ..write('invalid input');
        await request.response.close();
      }
    });
    try {
      final executor = RequestExecutor();
      final base = 'http://127.0.0.1:${server.port}';
      final error = await executor
          .start(RequestSpec(url: '$base/error'))
          .result;
      expect(error.statusCode, 422);
      expect(error.body, 'invalid input');
      expect(error.error, isNull);
      final timeout = await executor
          .start(
            RequestSpec(url: '$base/wait'),
            timeout: const Duration(milliseconds: 80),
          )
          .result;
      expect(timeout.error, contains('超时'));
      final operation = executor.start(RequestSpec(url: '$base/wait'));
      operation.cancel();
      final cancelled = await operation.result;
      expect(cancelled.cancelled, isTrue);
      expect(cancelled.error, isNull);
    } finally {
      await server.close(force: true);
    }
  });

  test(
    'large response capture is bounded and visibly marked truncated',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.add(
          List.filled(RequestExecutor.maxBodyBytes + 4096, 65),
        );
        try {
          await request.response.close();
        } catch (_) {
          /* Client stops capture at limit. */
        }
      });
      try {
        final response = await RequestExecutor()
            .start(RequestSpec(url: 'http://127.0.0.1:${server.port}/large'))
            .result;
        expect(response.statusCode, 200);
        expect(response.truncated, isTrue);
        expect(response.body.length, RequestExecutor.maxBodyBytes);
      } finally {
        await server.close(force: true);
      }
    },
  );

  test(
    'saved definitions and dirty drafts survive restart independently',
    () async {
      final folder = c.addFolder('服务 A');
      final draft = c.newRequest(folderId: folder.id)
        ..name = '获取列表'
        ..url = 'https://example.com/users';
      expect(await c.save(draft), isTrue);
      expect(c.isDirty(draft), isFalse);
      draft.url = 'https://example.com/users?changed=1';
      c.changed();
      await c.flush();
      final reloaded = WorkspaceController(
        storage: WorkspaceStorage(directory: directory),
      );
      await reloaded.initialize();
      expect(reloaded.requests.single.url, 'https://example.com/users');
      expect(reloaded.active!.url, contains('changed=1'));
      expect(reloaded.isDirty(reloaded.active!), isTrue);
      expect(reloaded.folders.last.name, '服务 A');
      reloaded.deleteFolder(reloaded.folders.last);
      expect(reloaded.drafts, isEmpty);
      expect(reloaded.requests, isEmpty);
      await reloaded.flush();
      reloaded.dispose();
    },
  );

  test(
    'serialized writes keep valid data and recover corrupt file from backup',
    () async {
      c.newRequest().name = 'first';
      await c.flush();
      c.active!.name = 'second';
      await c.flush();
      await c.storage.file.writeAsString('{corrupt');
      final storage = WorkspaceStorage(directory: directory);
      final recovered = await storage.read();
      expect(recovered!['drafts'][0]['name'], 'first');
      expect(storage.recoveryNotice, contains('备份'));
      expect(
        await directory
            .list()
            .where((e) => e.path.contains('.corrupt-'))
            .length,
        1,
      );
    },
  );

  test(
    'persistence failure rolls back saved marker and leaves draft editable',
    () async {
      c.dispose();
      final blocked = File(
        '${directory.path}${Platform.pathSeparator}not-a-directory',
      );
      await blocked.writeAsString('keep');
      c = WorkspaceController(
        storage: WorkspaceStorage(directory: Directory(blocked.path)),
      );
      await c.initialize();
      final draft = c.newRequest()..name = '不能丢失';
      expect(await c.save(draft), isFalse);
      expect(c.isDirty(draft), isTrue);
      expect(c.notice, contains('保存失败'));
      expect(await blocked.readAsString(), 'keep');
    },
  );
}
