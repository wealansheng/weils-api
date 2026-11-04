import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/app.dart';
import 'package:weils_api/features/workspace/domain/entities/request_spec.dart';
import 'package:weils_api/features/workspace/domain/use_cases/curl_codec.dart';

import '../support/workspace_fixture.dart';

/// 仅截图时加载本机字体，普通 CI 不依赖 Windows 字体文件。
Future<void> loadFonts() async {
  if (const bool.fromEnvironment('CAPTURE_UI')) {
    for (final font in [
      ('Microsoft YaHei', 'msyh.ttc'),
      ('Consolas', 'consola.ttf'),
      ('Segoe UI', 'segoeui.ttf'),
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
}

/// 保存当前测试界面，供一次性检查桌面尺寸和错误提示布局。
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

void main() {
  setUpAll(loadFonts);
  for (final size in [
    const Size(1440, 800),
    const Size(1280, 720),
    const Size(1000, 650),
  ]) {
    testWidgets(
      'cURL import errors, draft isolation and both export menus at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = WorkspaceFixture(storage: MemoryStorage());
        await fixture.initialize();
        addTearDown(fixture.dispose);
        final old = fixture.create(
          RequestSpec(name: '保留原草稿', bodyType: 'text', body: '尚未保存的内容'),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: WeilsApp(dependencies: fixture.dependencies),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('新建接口、文件夹或导入 cURL'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('导入 cURL'));
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('curl-import-command'));
        await tester.enterText(
          input,
          'curl https://example.com --proxy http://localhost',
        );
        await tester.tap(find.byKey(const ValueKey('curl-import-confirm')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('curl-import-error')), findsOneWidget);
        expect(fixture.drafts, hasLength(1));
        await capture(tester, key, 'curl-error-${size.width.toInt()}');
        const command =
            "curl 'https://example.com/users?tag=a&tag=b' -H 'Content-Type: application/json' -H 'Authorization: Bearer token' --data-raw '{\"name\":\"中文\"}'";
        await tester.enterText(input, command);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('curl-import-error')), findsNothing);
        await capture(tester, key, 'curl-import-${size.width.toInt()}');
        await tester.tap(find.byKey(const ValueKey('curl-import-confirm')));
        await tester.pumpAndSettle();
        expect(fixture.drafts, hasLength(2));
        expect(fixture.latest(old.id).body, '尚未保存的内容');
        expect(fixture.requests, isEmpty);
        expect(fixture.history, isEmpty);
        expect(fixture.dependencies.execution.running, false);
        expect(fixture.active!.method, 'POST');
        expect(fixture.active!.bodyType, 'json');
        expect(fixture.active!.token, 'token');
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('request-url')))
              .controller!
              .text,
          startsWith('https://example.com/users'),
        );
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
        for (final shell in CurlShell.values) {
          ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
              .clearSnackBars();
          await tester.tap(find.byKey(const ValueKey('export-curl')));
          await tester.pumpAndSettle();
          await capture(
            tester,
            key,
            'curl-export-${shell.name}-${size.width.toInt()}',
          );
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
          expect(copied, isNotNull);
          final restored = CurlCodec.parse(copied!, shell: shell);
          expect(restored.body, fixture.active!.body);
          expect(restored.token, 'token');
          expect(restored.effectiveUri.queryParametersAll['tag'], ['a', 'b']);
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(fixture.flush);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'empty home import can cancel, select PowerShell and retain raw text',
    (tester) async {
      final fixture = WorkspaceFixture(storage: MemoryStorage());
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(WeilsApp(dependencies: fixture.dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('import-curl-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(fixture.drafts, isEmpty);
      await tester.tap(find.byKey(const ValueKey('import-curl-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('curl-import-shell-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('curl-import-shell-option-powerShell')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('curl-import-command')),
        "curl.exe 'https://example.com' --data-raw 'O''Brien \$value'",
      );
      await tester.tap(find.byKey(const ValueKey('curl-import-confirm')));
      await tester.pumpAndSettle();
      expect(fixture.active!.body, "O'Brien \$value");
      await tester.runAsync(fixture.flush);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('export errors preserve draft and report clipboard failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = WorkspaceFixture(storage: MemoryStorage());
    await fixture.initialize();
    addTearDown(fixture.dispose);
    final draft = fixture.newRequest();
    var clipboardWrites = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardWrites++;
          throw PlatformException(code: 'clipboard_unavailable');
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
    await tester.pumpWidget(WeilsApp(dependencies: fixture.dependencies));
    await tester.pumpAndSettle();

    /// 使用当前草稿的导出入口，失败后仍可修正并重试。
    Future<void> export() async {
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
          .clearSnackBars();
      await tester.tap(find.byKey(const ValueKey('export-curl')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-curl-bash')));
      await tester.pumpAndSettle();
    }

    await export();
    expect(clipboardWrites, 0);
    expect(find.textContaining('URL 须为完整'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('request-url')),
      'https://example.com',
    );
    await export();
    expect(clipboardWrites, 1);
    expect(find.text('无法写入剪贴板，请重试。'), findsOneWidget);
    expect(fixture.active!.id, draft.id);
    expect(fixture.active!.url, 'https://example.com');
    expect(fixture.history, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.runAsync(fixture.flush);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
