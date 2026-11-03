import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/core/models.dart';
import 'package:weils_api/core/request_executor.dart';
import 'package:weils_api/core/request_headers.dart';
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

  test('generated headers follow URL, UTF-8 body and enabled case-insensitive overrides', () {
    final r = RequestSpec(
      url: 'https://example.com:8443/users',
      method: 'POST',
      bodyType: 'json',
      body: '{"name":"中文"}',
    );
    Map<String, String> defaults() => {
      for (final h in defaultRequestHeaders(r)) h.name.toLowerCase(): h.value,
    };
    expect(defaults()['host'], 'example.com:8443');
    expect(defaults()['user-agent'], defaultUserAgent);
    expect(defaults()['content-length'], utf8.encode(r.body).length.toString());
    expect(defaults()['content-type'], ContentType.json.toString());
    final custom = Entry(name: 'uSeR-aGeNt', value: 'MyClient');
    r.headers.add(custom);
    expect(defaults().containsKey('user-agent'), isFalse);
    custom.enabled = false;
    expect(defaults()['user-agent'], defaultUserAgent);
    r.url = 'http://[::1]:8080/users';
    expect(defaults()['host'], '[::1]:8080');
    r.url = 'https://example.com:443/users';
    expect(defaults()['host'], 'example.com');
    expect(
      r.headers,
      hasLength(1),
      reason: 'generated rows must not become custom/persisted rows',
    );
  });

  test(
    'wire headers match preview and custom headers replace automatic values',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = <Map<String, String>>[];
      server.listen((request) async {
        final headers = <String, String>{};
        request.headers.forEach(
          (key, values) => headers[key] = values.join(', '),
        );
        received.add(headers);
        await request.drain<void>();
        request.response.write('ok');
        await request.response.close();
      });
      try {
        final r = RequestSpec(
          url: 'http://127.0.0.1:${server.port}/users',
          method: 'POST',
          bodyType: 'json',
          body: '{"text":"中文"}',
          authType: 'bearer',
          token: 'auto-token',
        );
        final expected = defaultRequestHeaders(r);
        final result = await RequestExecutor().start(r).result;
        expect(result.statusCode, 200);
        for (final h in expected) {
          expect(received.last[h.name.toLowerCase()], h.value, reason: h.name);
        }
        r.headers.addAll([
          Entry(name: 'USER-AGENT', value: 'Custom/1'),
          Entry(name: 'Accept-Encoding', value: 'identity'),
          Entry(name: 'CONTENT-TYPE', value: 'application/custom'),
          Entry(name: 'Authorization', value: 'Custom token'),
        ]);
        expect((await RequestExecutor().start(r).result).statusCode, 200);
        expect(received.last['user-agent'], 'Custom/1');
        expect(received.last['accept-encoding'], 'identity');
        expect(received.last['content-type'], 'application/custom');
        expect(received.last['authorization'], 'Custom token');
        r.headers.first.enabled = false;
        expect((await RequestExecutor().start(r).result).statusCode, 200);
        expect(received.last['user-agent'], defaultUserAgent);
      } finally {
        await server.close(force: true);
      }
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
    'tab order persists without changing active request or draft content',
    () async {
      final first = c.newRequest()..name = 'first';
      final second = c.newRequest()..name = 'second';
      final third = c.newRequest()..name = 'third';
      for (final draft in [first, second, third]) {
        await c.save(draft);
      }
      first.body = 'unsaved body';
      c.reorderDraft(0, 2);
      expect(c.drafts, [second, third, first]);
      expect(c.active, same(third));
      expect(c.isDirty(first), isTrue);
      c.reorderDraft(2, 0);
      expect(c.drafts, [first, second, third]);
      c.reorderDraft(2, 1);
      c.reorderDraft(1, 1);
      await c.flush();
      final restored = WorkspaceController(
        storage: WorkspaceStorage(directory: directory),
      );
      try {
        await restored.initialize();
        expect(restored.drafts.map((r) => r.id), [
          first.id,
          third.id,
          second.id,
        ]);
        expect(restored.active!.id, third.id);
        expect(restored.drafts.first.body, 'unsaved body');
        expect(restored.requests.map((r) => r.id), [
          first.id,
          second.id,
          third.id,
        ]);
        expect(restored.requests.first.body, isEmpty);
      } finally {
        restored.dispose();
      }
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
    'changing data directory preserves current workspace and restart location',
    () async {
      final draft = c.newRequest()..name = '保存的接口';
      await c.save(draft);
      draft.body = '尚未保存的正文';
      final response = ResponseRecord(statusCode: 200, body: 'history body');
      c.history.add(HistoryRecord(request: draft.copy(), response: response));
      await c.flush();
      final original = c.storage.file;
      final before = await original.readAsString();
      final target = await Directory('${directory.path}/新的 数据目录').create();
      expect(
        await c.updateSettings(timeout: 45, directoryPath: target.path),
        isTrue,
      );
      expect(c.storage.directory.path, await target.resolveSymbolicLinks());
      expect(await original.readAsString(), before);
      final restored = WorkspaceController(
        storage: WorkspaceStorage(directory: directory),
      );
      try {
        await restored.initialize();
        expect(restored.storageBlocked, isFalse);
        expect(
          restored.storage.directory.path,
          await target.resolveSymbolicLinks(),
        );
        expect(restored.timeoutSeconds, 45);
        expect(restored.requests.single.body, isEmpty);
        expect(restored.active!.body, '尚未保存的正文');
        expect(restored.history.single.response.body, 'history body');
        restored.active!.name = '切换后的修改';
        await restored.flush();
        expect((await c.storage.read())!['drafts'][0]['name'], '切换后的修改');
        expect(await original.readAsString(), before);
      } finally {
        restored.dispose();
      }
    },
  );

  for (final suffix in ['', '.bak']) {
    test('existing destination workspace$suffix is never replaced', () async {
      c.newRequest().name = '源工作区';
      await c.flush();
      final original = await c.storage.file.readAsString();
      final target = await Directory('${directory.path}/occupied').create();
      final occupied = File('${target.path}/workspace.json$suffix');
      await occupied.writeAsString('keep this exact content');
      expect(
        await c.updateSettings(timeout: 80, directoryPath: target.path),
        isFalse,
      );
      expect(c.settingsError, contains('已有工作区'));
      expect(c.timeoutSeconds, 30);
      expect(c.storage.directory.path, directory.path);
      expect(await occupied.readAsString(), 'keep this exact content');
      expect(await c.storage.file.readAsString(), original);
      expect(await c.storage.locationFile.exists(), isFalse);
    });
  }

  test('location pointer failure rolls back new data and retains original settings', () async {
    final location = File('${directory.path}/config/location.json');
    final local = WorkspaceController(
      storage: WorkspaceStorage(directory: directory, locationFile: location),
    );
    try {
      await local.initialize();
      local.newRequest().name = '保留的接口';
      await local.flush();
      final source = local.storage.file;
      final before = await source.readAsString();
      await File('${directory.path}/config')
          .writeAsString('blocks config directory');
      final target = await Directory('${directory.path}/destination').create();
      expect(
        await local.updateSettings(timeout: 60, directoryPath: target.path),
        isFalse,
      );
      expect(local.storage.directory.path, directory.path);
      expect(local.timeoutSeconds, 30);
      expect(await source.readAsString(), before);
      expect(await File('${target.path}/workspace.json').exists(), isFalse);
      local.active!.name = '继续保存';
      expect(await local.flush(), isTrue);
      expect((await local.storage.read())!['drafts'][0]['name'], '继续保存');
    } finally {
      local.dispose();
    }
  });

  test('a file cannot be selected as the data directory', () async {
    final target = File('${directory.path}/ordinary-file');
    await target.writeAsString('unchanged');
    expect(
      await c.updateSettings(timeout: 60, directoryPath: target.path),
      isFalse,
    );
    expect(c.settingsError, contains('文件夹不存在'));
    expect(c.timeoutSeconds, 30);
    expect(await target.readAsString(), 'unchanged');
  });

  test(
    'queued saves during relocation use the committed directory and timeout',
    () async {
      final draft = c.newRequest()..name = 'before migration';
      await c.flush();
      final target = await Directory('${directory.path}/queued-destination')
          .create();
      final migration = c.updateSettings(
        timeout: 55,
        directoryPath: target.path,
      );
      draft.name = 'updated while saving settings';
      c.changed();
      final flush = c.flush();
      expect(await migration, isTrue);
      expect(await flush, isTrue);
      final data = await c.storage.read();
      expect(data!['timeoutSeconds'], 55);
      expect(data['drafts'][0]['name'], 'updated while saving settings');
    },
  );

  test('selecting the current directory updates settings without migration conflict', () async {
    c.newRequest();
    await c.flush();
    expect(
      await c.updateSettings(timeout: 75, directoryPath: '${directory.path}/.'),
      isTrue,
    );
    expect(c.timeoutSeconds, 75);
    expect((await c.storage.read())!['timeoutSeconds'], 75);
  });

  test('missing selected directory blocks startup instead of falling back and overwriting', () async {
    c.newRequest().name = '原始数据';
    await c.flush();
    final source = c.storage.file;
    final original = await source.readAsString();
    final target = await Directory('${directory.path}/selected').create();
    expect(
      await c.updateSettings(timeout: 40, directoryPath: target.path),
      isTrue,
    );
    await target.rename('${directory.path}/selected-moved');
    final restored = WorkspaceController(
      storage: WorkspaceStorage(directory: directory),
    );
    try {
      await restored.initialize();
      expect(restored.storageBlocked, isTrue);
      expect(await restored.flush(), isFalse);
      expect(await source.readAsString(), original);
    } finally {
      restored.dispose();
    }
  });

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
