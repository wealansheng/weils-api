import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/core/models.dart';
import 'package:weils_api/core/storage.dart';
import 'package:weils_api/core/workspace_controller.dart';
import 'package:weils_api/main.dart';

class MemoryStorage extends WorkspaceStorage {
  MemoryStorage() : super(directory: Directory('test-workspace'));
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    this.data = data;
  }
}

class FailingStorage extends MemoryStorage {
  bool failRead = false, failWrite = false;
  @override
  Future<Map<String, dynamic>?> read() async {
    if (failRead) throw const FileSystemException('read blocked');
    return super.read();
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (failWrite) throw const FileSystemException('write blocked');
    await super.write(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final item in [
      ('Microsoft YaHei', 'C:/Windows/Fonts/msyh.ttc'),
      ('Segoe UI', 'C:/Windows/Fonts/segoeui.ttf'),
      ('Consolas', 'C:/Windows/Fonts/consola.ttf'),
    ]) {
      final file = File(item.$2);
      if (await file.exists()) {
        final loader = FontLoader(item.$1)
          ..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          );
        await loader.load();
      }
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<WorkspaceController> controller(WidgetTester tester) async {
    final c = WorkspaceController(storage: MemoryStorage());
    await tester.runAsync(c.initialize);
    addTearDown(() async {
      c.dispose();
    });
    return c;
  }

  Future<void> show(
    WidgetTester tester,
    WorkspaceController c,
    GlobalKey key,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: WeilsApp(controller: c),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('.impeccable/review');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'minimal home, unsaved tab close protection and input validation',
    (tester) async {
      final c = await controller(tester);
      final key = GlobalKey();
      await show(tester, c, key, const Size(1440, 800));
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('帮助文档'), findsOneWidget);
      expect(find.text('自动化测试'), findsNothing);
      expect(find.text('main'), findsNothing);
      await capture(tester, key, 'home-1440');
      await tester.tap(find.byKey(const ValueKey('create-request')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('request-name')),
        '我的接口',
      );
      await tester.enterText(
        find.byKey(const ValueKey('request-url')),
        'invalid',
      );
      await tester.tap(find.byKey(const ValueKey('send-request')));
      await tester.pump();
      expect(find.textContaining('请输入完整'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭标签页'));
      await tester.pumpAndSettle();
      expect(find.text('保存未完成的修改？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(c.drafts, hasLength(1));
      await tester.tap(find.byTooltip('关闭标签页'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();
      expect(c.drafts, isEmpty);
      await tester.runAsync(c.flush);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [const Size(1440, 800), const Size(1280, 720)]) {
    testWidgets(
      'request editor and immutable history replay at ${size.width.toInt()}px',
      (tester) async {
        final c = await controller(tester);
        final r = c.newRequest()
          ..name = '获取用户列表（演示）'
          ..url = 'https://api.example.com/api/v1/users';
        r.params.addAll([
          Entry(name: 'page', value: '1', description: '页码'),
          Entry(name: 'pageSize', value: '20', description: '每页条数'),
        ]);
        await tester.runAsync(() => c.save(r));
        final response = ResponseRecord(
          statusCode: 200,
          reason: 'OK',
          elapsedMs: 128,
          byteCount: 182,
          headers: {'content-type': 'application/json; charset=utf-8'},
          body: '{"code":0,"message":"success","data":{"list":[{"id":1001,"name":"张三","email":"zhangsan@example.com"}],"total":1,"page":1,"pageSize":20}}',
        );
        c.responses[r.id] = response;
        final record = HistoryRecord(
          request: r.copy(),
          response: response,
          time: DateTime(2026, 11, 3, 10, 24, 18),
        );
        c.history.add(record);
        final key = GlobalKey();
        await show(tester, c, key, size);
        expect(tester.takeException(), isNull);
        expect(find.text('200 OK'), findsOneWidget);
        await capture(tester, key, 'editor-${size.width.toInt()}');
        await tester.tap(find.text('Body').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('认证'));
        await tester.pumpAndSettle();
        expect(find.text('认证方式'), findsOneWidget);
        await tester.tap(find.text('请求历史'));
        await tester.pumpAndSettle();
        expect(find.text('历史快照'), findsOneWidget);
        expect(find.text('只读'), findsOneWidget);
        await capture(tester, key, 'history-${size.width.toInt()}');
        await tester.tap(find.byKey(const ValueKey('replay-history')));
        await tester.pumpAndSettle();
        expect(c.active!.id, isNot(record.request.id));
        expect(c.active!.name, endsWith('重发'));
        await tester.enterText(
          find.byKey(const ValueKey('request-name')),
          '修改后的接口',
        );
        expect(record.request.name, '获取用户列表（演示）');
        await tester.runAsync(c.flush);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'native close request prompts, saves and flushes before allowing exit',
    (tester) async {
      final c = await controller(tester);
      c.newRequest().name = '退出前保存';
      await show(tester, c, GlobalKey(), const Size(1280, 720));
      var closed = false;
      const channel = MethodChannel('weils/window');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'close') {
          expect(c.isDirty(c.active!), isFalse);
          expect((c.storage as MemoryStorage).data!['requests'], hasLength(1));
          closed = true;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final exit = tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'weils/window',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('closeRequested'),
        ),
        null,
      );
      await tester.pumpAndSettle();
      expect(find.text('保存未完成的修改？'), findsOneWidget);
      expect(closed, isFalse);
      await tester.tap(find.text('全部保存'));
      await tester.pumpAndSettle();
      await exit;
      expect(closed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final dirty in [false, true]) {
    testWidgets(
      'blocked initialization can cancel or explicitly exit, dirty=$dirty',
      (tester) async {
        final storage = FailingStorage()..failRead = true;
        final original = <String, dynamic>{'unreadable-original': true};
        storage.data = original;
        final c = WorkspaceController(storage: storage);
        await c.initialize();
        addTearDown(c.dispose);
        if (dirty) c.newRequest().name = '保留我的编辑';
        final key = GlobalKey();
        await show(tester, c, key, const Size(1280, 720));
        var closed = false;
        const channel = MethodChannel('weils/window');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async {
            closed = true;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        Future<void> requestExit() async {
          final event = tester.binding.defaultBinaryMessenger
              .handlePlatformMessage(
                'weils/window',
                const StandardMethodCodec().encodeMethodCall(
                  const MethodCall('closeRequested'),
                ),
                null,
              );
          await tester.pumpAndSettle();
          if (dirty) {
            await tester.tap(find.text('放弃修改'));
            await tester.pumpAndSettle();
          }
          expect(find.text('本地数据未能保存'), findsOneWidget);
          if (dirty) await capture(tester, key, 'recovery-exit');
          await tester.tap(find.text('取消退出'));
          await tester.pumpAndSettle();
          await event;
        }

        await requestExit();
        expect(closed, isFalse);
        if (dirty) expect(c.active!.name, '保留我的编辑');
        final event = tester.binding.defaultBinaryMessenger
            .handlePlatformMessage(
              'weils/window',
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall('closeRequested'),
              ),
              null,
            );
        await tester.pumpAndSettle();
        if (dirty) {
          await tester.tap(find.text('放弃修改'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('不保存并退出'));
        await tester.pumpAndSettle();
        await event;
        expect(closed, isTrue);
        expect(storage.data, same(original));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'write failure allows retry and saves before exit, dirty=$dirty',
      (tester) async {
        final storage = FailingStorage();
        final c = WorkspaceController(storage: storage);
        await c.initialize();
        addTearDown(c.dispose);
        if (dirty) c.newRequest().name = '重试保存的接口';
        storage.failWrite = true;
        final key = GlobalKey();
        await show(tester, c, key, const Size(1280, 720));
        var closed = false;
        const channel = MethodChannel('weils/window');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async {
            closed = true;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final event = tester.binding.defaultBinaryMessenger
            .handlePlatformMessage(
              'weils/window',
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall('closeRequested'),
              ),
              null,
            );
        await tester.pumpAndSettle();
        if (dirty) {
          await tester.tap(find.text('全部保存'));
          await tester.pumpAndSettle();
        }
        expect(find.text('本地数据未能保存'), findsOneWidget);
        expect(closed, isFalse);
        if (dirty) await capture(tester, key, 'recovery-retry');
        storage.failWrite = false;
        await tester.tap(find.text('重试保存'));
        await tester.pumpAndSettle();
        await event;
        expect(closed, isTrue);
        if (dirty) expect(storage.data!['requests'], hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('settings validates timeout and help opens actual content', (
    tester,
  ) async {
    final c = await controller(tester);
    await show(tester, c, GlobalKey(), const Size(1280, 720));
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();
    expect(find.text('请填写 1–300 之间的整数'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '45');
    await tester.tap(find.text('保存设置'));
    await tester.runAsync(c.flush);
    await tester.pumpAndSettle();
    expect(c.timeoutSeconds, 45);
    await tester.tap(find.text('帮助文档'));
    await tester.pumpAndSettle();
    expect(find.text('从历史继续调试'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
