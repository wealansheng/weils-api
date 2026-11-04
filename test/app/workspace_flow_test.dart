import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/core/platform/runtime_info.dart';

import '../support/workspace_fixture.dart';

import 'package:weils_api/app.dart';
import 'package:weils_api/features/workspace/presentation/editor/widgets/response_pane.dart';
import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/features/workspace/data/models/workspace_json.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // 系统字体只在截图（CAPTURE_UI）时加载：CI 上不存在 C:/Windows/Fonts，
    // 若默认加载会让本地与 CI 的排版度量不一致，导致同一断言两端结果相反。
    if (const bool.fromEnvironment('CAPTURE_UI')) {
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
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<WorkspaceFixture> controller(WidgetTester tester) async {
    final c = WorkspaceFixture(nativeWindow: true, storage: MemoryStorage());
    await tester.runAsync(c.initialize);
    addTearDown(() async {
      c.dispose();
    });
    return c;
  }

  Future<void> show(
    WidgetTester tester,
    WorkspaceFixture c,
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
        child: WeilsApp(dependencies: c.dependencies),
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

  for (final width in [1440.0, 1280.0, 1000.0]) {
    testWidgets('select menus stay anchored across selections at $width', (
      tester,
    ) async {
      final c = await controller(tester);
      final second = c.addFolder('用户服务');
      final lastFolder = c.addFolder('这是一段很长的模块名称，用于验证菜单宽度和省略显示');
      final r = c.newRequest();
      final key = GlobalKey();
      await show(tester, c, key, Size(width, width == 1000 ? 650 : 800));
      final method = find.byKey(const ValueKey('request-method-trigger'));
      final methodTrigger = tester.getRect(method);
      Rect? methodRow;
      for (final value in ['PATCH', 'OPTIONS', 'GET']) {
        await tester.tap(method);
        await tester.pumpAndSettle();
        final first = tester.getRect(
          find.byKey(const ValueKey('request-method-option-GET')),
        );
        expect(first.top, greaterThanOrEqualTo(methodTrigger.bottom + 4));
        expect(first.left, closeTo(methodTrigger.left + 5, 1));
        expect(first.width, closeTo(146, 1));
        if (methodRow != null) expect(first, methodRow);
        methodRow = first;
        if (value == 'GET' && width != 1000) {
          await capture(tester, key, 'dropdown-method-${width.toInt()}');
        }
        await tester.tap(find.byKey(ValueKey('request-method-option-$value')));
        await tester.pumpAndSettle();
        expect(c.latest(r.id).method, value);
        expect(tester.getRect(method), methodTrigger);
        expect(find.byType(MenuItemButton), findsNothing);
      }
      final folder = find.byKey(const ValueKey('request-folder-trigger'));
      final folderTrigger = tester.getRect(folder);
      Rect? folderRow;
      for (final value in [second.id, lastFolder.id, 'default']) {
        await tester.tap(folder);
        await tester.pumpAndSettle();
        final first = tester.getRect(
          find.byKey(const ValueKey('request-folder-option-default')),
        );
        expect(first.top, greaterThanOrEqualTo(folderTrigger.bottom + 4));
        expect(first.width, closeTo(210, 1));
        if (folderRow != null) expect(first, folderRow);
        folderRow = first;
        if (value == 'default' && width != 1000) {
          await capture(tester, key, 'dropdown-folder-${width.toInt()}');
        }
        await tester.tap(find.byKey(ValueKey('request-folder-option-$value')));
        await tester.pumpAndSettle();
        expect(c.latest(r.id).folderId, value);
        expect(tester.getRect(folder), folderTrigger);
      }
      await tester.tap(method);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      await tester.tap(folder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('request-url')));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(c.flush);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final width in [1440.0, 1000.0]) {
    testWidgets(
      'mouse reorders tabs and selection preserves typography at $width',
      (tester) async {
        final c = await controller(tester);
        final first = c.create(RequestSpec(name: '用户列表'));
        final second = c.create(RequestSpec(name: '创建用户'));
        final third = c.create(RequestSpec(name: '这是一个很长的接口标签名称，需要显示省略号'));
        final key = GlobalKey();
        await show(tester, c, key, Size(width, 720));
        Finder tab(RequestSpec r) =>
            find.byKey(ValueKey('request-tab-${r.id}'));
        Finder label(RequestSpec r) =>
            find.descendant(of: tab(r), matching: find.text(r.name));
        final originalRects = [
          for (final r in [first, second, third]) tester.getRect(tab(r)),
        ];
        final inactiveStyle = tester.widget<Text>(label(first)).style!;
        await tester.tap(label(first));
        await tester.pumpAndSettle();
        expect(c.active, same(first));
        final activeStyle = tester.widget<Text>(label(first)).style!;
        expect(activeStyle.fontSize, inactiveStyle.fontSize);
        expect(activeStyle.fontWeight, inactiveStyle.fontWeight);
        expect(activeStyle.fontFamily, inactiveStyle.fontFamily);
        expect(activeStyle.height, inactiveStyle.height);
        for (var i = 0; i < 3; i++) {
          expect(
            tester.getRect(tab([first, second, third][i])),
            originalRects[i],
          );
        }
        await tester.tap(label(first));
        await tester.pumpAndSettle();
        expect(tester.getRect(tab(first)), originalRects.first);

        Future<void> move(
          RequestSpec from,
          RequestSpec to, {
          required bool right,
        }) async {
          final start = tester.getCenter(label(from));
          final target = tester.getRect(tab(to));
          final end = Offset(
            right ? target.right - 8 : target.left + 8,
            start.dy,
          );
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
        }

        await move(first, third, right: true);
        expect(c.drafts, [second, third, first]);
        expect(c.active, same(first));
        await capture(tester, key, 'tabs-reordered-${width.toInt()}');
        await move(first, second, right: false);
        expect(c.drafts, [first, second, third]);
        await move(second, first, right: false);
        expect(c.drafts, [second, first, third]);
        expect(c.active, same(first));
        await tester.tap(
          find.descendant(of: tab(second), matching: find.byTooltip('关闭标签页')),
        );
        await tester.pumpAndSettle();
        expect(find.text('保存未完成的修改？'), findsOneWidget);
        await tester.tap(find.text('放弃修改'));
        await tester.pumpAndSettle();
        expect(c.drafts, [first, third]);
        expect(c.active, same(first));
        expect(tester.takeException(), isNull);
        await tester.runAsync(c.flush);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('overflowing tab bar scrolls and still allows mouse reordering', (
    tester,
  ) async {
    final c = await controller(tester);
    final drafts = [
      for (var i = 0; i < 12; i++) c.create(RequestSpec(name: '接口标签 $i')),
    ];
    await show(tester, c, GlobalKey(), const Size(1000, 650));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byKey(const ValueKey('request-tabs'))),
        scrollDelta: const Offset(1600, 0),
      ),
    );
    await tester.pumpAndSettle();
    final lastLabel = find.descendant(
      of: find.byKey(ValueKey('request-tab-${drafts.last.id}')),
      matching: find.text(drafts.last.name),
    );
    expect(lastLabel.hitTestable(), findsOneWidget);
    final start = tester.getCenter(lastLabel);
    final gesture = await tester.startGesture(
      start,
      kind: ui.PointerDeviceKind.mouse,
    );
    for (var step = 1; step <= 16; step++) {
      await gesture.moveTo(start - Offset(180 * step / 16, 0));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(const Duration(milliseconds: 350));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.drafts.indexOf(drafts.last), lessThan(11));
    expect(c.active, same(drafts.last));
    expect(c.drafts.map((r) => r.id).toSet(), drafts.map((r) => r.id).toSet());
    expect(tester.takeException(), isNull);
    await tester.runAsync(c.flush);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Body and authentication selects support keyboard selection', (
    tester,
  ) async {
    final c = await controller(tester);
    final r = c.newRequest();
    await show(tester, c, GlobalKey(), const Size(1280, 720));
    await tester.tap(find.text('Body').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('request-body-type-trigger')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(c.latest(r.id).bodyType, 'json');
    expect(find.byKey(const ValueKey('request-body')), findsOneWidget);
    await tester.tap(find.text('认证'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('request-auth-type-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('request-auth-type-option-bearer')),
    );
    await tester.pumpAndSettle();
    expect(c.latest(r.id).authType, 'bearer');
    expect(find.text('Token'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(c.flush);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [1440.0, 1000.0]) {
    testWidgets(
      'response header table wraps, scrolls, copies and appears in history at $width',
      (tester) async {
        final c = await controller(tester);
        final r = c.create(RequestSpec(name: '响应头展示'));
        final longName = 'x-${'long-header-name-' * 6}';
        final headers = {
          'content-type': 'application/json; charset=utf-8',
          longName: 'test-value',
          'set-cookie':
              'session=example; HttpOnly; SameSite=Lax\nlocale=zh-CN; Path=/',
          'cache-control':
              'private, no-cache, max-age=0, must-revalidate; ' * 8,
          'x-empty': '',
          for (var i = 0; i < 30; i++) 'x-debug-$i': 'value-$i',
        };
        final response = ResponseRecord(
          statusCode: 200,
          reason: 'OK',
          headers: headers,
        );
        c.responses[r.id] = response;
        c.appendHistory(
          HistoryRecord(request: c.latest(r.id), response: response),
        );
        final key = GlobalKey();
        await show(tester, c, key, Size(width, 720));
        Future<void> showHeaders() async {
          await tester.tap(
            find.descendant(
              of: find.byType(ResponsePane),
              matching: find.text('Headers'),
            ),
          );
          await tester.pumpAndSettle();
        }

        await showHeaders();
        final table = find.byKey(const ValueKey('response-headers-table'));
        expect(table, findsOneWidget);
        expect(
          find.descendant(of: table, matching: find.text('名称')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: table, matching: find.text('值')),
          findsOneWidget,
        );
        expect(find.text(headers['content-type']!), findsOneWidget);
        final longNameRect = tester.getRect(
          find.byKey(ValueKey('response-header-name-$longName')),
        );
        expect(longNameRect.height, greaterThan(18));
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'response-headers-${width.toInt()}');
        final headingPosition = tester.getTopLeft(
          find.descendant(of: table, matching: find.text('名称')),
        );
        await tester.drag(
          find.byKey(const ValueKey('response-headers-rows')),
          const Offset(0, -2500),
        );
        await tester.pumpAndSettle();
        final last = find.byKey(
          const ValueKey('response-header-value-x-debug-29'),
        );
        expect(last.hitTestable(), findsOneWidget);
        expect(
          tester.getTopLeft(
            find.descendant(of: table, matching: find.text('名称')),
          ),
          headingPosition,
        );
        var copied = '';
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
        await tester.tap(find.byTooltip('复制响应'));
        await tester.pumpAndSettle();
        expect(
          copied,
          headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
        );
        await tester.tap(find.text('请求历史'));
        await tester.pumpAndSettle();
        await showHeaders();
        expect(table, findsOneWidget);
        expect(find.text(headers['content-type']!), findsOneWidget);
        expect(response.headers, headers);
        expect(tester.takeException(), isNull);
        await tester.runAsync(c.flush);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('empty response headers have an explicit empty state', (
    tester,
  ) async {
    final c = await controller(tester);
    final r = c.newRequest();
    c.responses[r.id] = ResponseRecord(statusCode: 204, reason: 'No Content');
    await show(tester, c, GlobalKey(), const Size(1000, 650));
    await tester.tap(
      find.descendant(
        of: find.byType(ResponsePane),
        matching: find.text('Headers'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无响应头'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(c.flush);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('many modules scroll within a bounded menu', (tester) async {
    final c = await controller(tester);
    final folders = [for (var i = 0; i < 30; i++) c.addFolder('模块 $i')];
    final r = c.newRequest();
    await show(tester, c, GlobalKey(), const Size(1000, 650));
    final trigger = find.byKey(const ValueKey('request-folder-trigger'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final last = find.byKey(
      ValueKey('request-folder-option-${folders.last.id}'),
    );
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    expect(tester.getRect(last).bottom, lessThan(650));
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(c.latest(r.id).folderId, folders.last.id);
    expect(tester.takeException(), isNull);
    await tester.runAsync(c.flush);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final bodyType in ['json', 'text']) {
    testWidgets(
      'Body Tab inserts two spaces and preserves focus/selection for $bodyType',
      (tester) async {
        final c = await controller(tester);
        final r = c.create(RequestSpec(bodyType: bodyType));
        await show(tester, c, GlobalKey(), const Size(1280, 720));
        await tester.tap(find.text('Body').first);
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('request-body'));
        await tester.enterText(field, 'abc');
        final textController = tester.widget<TextField>(field).controller!;
        final editable = tester.widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        textController.selection = const TextSelection.collapsed(offset: 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(textController.text, 'a  bc');
        expect(
          textController.selection,
          const TextSelection.collapsed(offset: 3),
        );
        expect(editable.focusNode.hasFocus, isTrue);
        expect(c.latest(r.id).body, 'a  bc');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(textController.text, 'a    bc');
        textController.selection = const TextSelection(
          baseOffset: 5,
          extentOffset: 1,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(textController.text, 'a  bc');
        expect(
          textController.selection,
          const TextSelection.collapsed(offset: 3),
        );
        expect(editable.focusNode.hasFocus, isTrue);

        await tester.enterText(field, '');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(textController.text, '  ');
        expect(c.latest(r.id).body, '  ');
        await tester.runAsync(c.flush);
        expect((c.storage as MemoryStorage).data!['drafts'][0]['body'], '  ');

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(
          editable.focusNode.hasFocus,
          isFalse,
          reason: 'Shift+Tab remains available for keyboard navigation',
        );
        expect(textController.text, '  ');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final size in [const Size(1440, 800), const Size(1280, 720)]) {
    testWidgets(
      'default headers are gray, custom rows normal, overrides keep focus at ${size.width.toInt()}px',
      (tester) async {
        final c = await controller(tester);
        final r = c.create(
          RequestSpec(name: 'Header 展示', url: 'https://api.example.com/users'),
        );
        final custom = Entry(name: 'X-Client', value: 'weils-local');
        c.edit(r, (r) => r.copyWith(headers: [custom]));
        final key = GlobalKey();
        await show(tester, c, key, size);
        await tester.tap(find.text('Headers').first);
        await tester.pumpAndSettle();
        final hostRow = find.byKey(const ValueKey('default-header-host'));
        final hostText = tester.widget<SelectableText>(
          find
              .descendant(of: hostRow, matching: find.byType(SelectableText))
              .first,
        );
        expect(hostText.style!.color, AppColors.muted);
        expect(find.text('api.example.com'), findsOneWidget);
        expect(find.text(defaultUserAgent), findsOneWidget);
        expect(find.text('gzip'), findsOneWidget);
        final customName = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(ValueKey('${custom.id}-name')),
            matching: find.byType(EditableText),
          ),
        );
        expect(customName.style.color, AppColors.ink);
        await capture(tester, key, 'headers-${size.width.toInt()}');
        await tester.tap(find.text('添加Header'));
        await tester.pumpAndSettle();
        final override = c.latest(r.id).headers.last;
        final nameField = find.byKey(ValueKey('${override.id}-name'));
        await tester.ensureVisible(nameField);
        await tester.enterText(nameField, 'user-agent');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('default-header-user-agent')),
          findsNothing,
        );
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: nameField,
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        final check = find.descendant(
          of: find.byKey(ValueKey(override.id)),
          matching: find.byType(Checkbox),
        );
        await tester.ensureVisible(check);
        await tester.tap(check);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('default-header-user-agent')),
          findsOneWidget,
        );
        expect(
          c.latest(r.id).headers,
          hasLength(2),
          reason: 'automatic rows are not saved as custom headers',
        );
        expect(tester.takeException(), isNull);
        await tester.runAsync(c.flush);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'request editor and immutable history replay at ${size.width.toInt()}px',
      (tester) async {
        final c = await controller(tester);
        final r = c.create(
          RequestSpec(
            name: '获取用户列表（演示）',
            url: 'https://api.example.com/api/v1/users',
          ),
        );
        c.edit(
          r,
          (r) => r.copyWith(
            params: [
              Entry(name: 'page', value: '1', description: '页码'),
              Entry(name: 'pageSize', value: '20', description: '每页条数'),
            ],
          ),
        );
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
          request: c.latest(r.id),
          response: response,
          time: DateTime(2026, 11, 3, 10, 24, 18),
        );
        c.appendHistory(record);
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
      c.create(RequestSpec(name: '退出前保存'));
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
        final c = WorkspaceFixture(nativeWindow: true, storage: storage);
        await c.initialize();
        addTearDown(c.dispose);
        if (dirty) c.create(RequestSpec(name: '保留我的编辑'));
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
        final c = WorkspaceFixture(nativeWindow: true, storage: storage);
        await c.initialize();
        addTearDown(c.dispose);
        if (dirty) c.create(RequestSpec(name: '重试保存的接口'));
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
    await tester.enterText(
      find.byKey(const ValueKey('request-timeout-seconds')),
      '0',
    );
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();
    expect(find.text('请填写 1–300 之间的整数'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('request-timeout-seconds')),
      '45',
    );
    await tester.tap(find.text('保存设置'));
    await tester.runAsync(c.flush);
    await tester.pumpAndSettle();
    expect(c.timeoutSeconds, 45);
    await tester.tap(find.text('帮助文档'));
    await tester.pumpAndSettle();
    // 帮助内容较长，最后一条在 720 高的窗口下需要滚动才能看到；
    // ListView 是懒构建的，滚动前该条根本不在 widget 树里。
    await tester.scrollUntilVisible(
      find.text('从历史继续调试'),
      120,
      scrollable: find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('从历史继续调试'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [1440.0, 1000.0]) {
    testWidgets(
      'settings stages folder selection and commits only on save at $width',
      (tester) async {
        final storage = RelocatingMemoryStorage();
        final c = WorkspaceFixture(nativeWindow: true, storage: storage);
        await c.initialize();
        addTearDown(c.dispose);
        c.create(RequestSpec(name: '保留的接口'));
        final key = GlobalKey();
        await show(tester, c, key, Size(width, width == 1000 ? 650 : 800));
        const channel = MethodChannel('weils/window');
        final pending = Completer<String?>();
        var pickerCalls = 0;
        const selected = r'C:\开发资料\接口调试工具\个人项目\工作区数据';
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            expect(call.method, 'selectDirectory');
            expect(call.arguments, storage.directoryPath);
            pickerCalls++;
            if (pickerCalls == 1) return await pending.future;
            return selected;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.tap(find.text('设置'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('choose-data-directory')));
        await tester.pump();
        expect(find.text('选择中…'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('保存设置'), findsOneWidget);
        pending.complete(null);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SelectableText>(
                find.byKey(const ValueKey('data-directory-path')),
              )
              .data,
          storage.directoryPath,
        );
        await tester.tap(find.byKey(const ValueKey('choose-data-directory')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SelectableText>(
                find.byKey(const ValueKey('data-directory-path')),
              )
              .data,
          selected,
        );
        expect(storage.relocations, 0);
        await capture(tester, key, 'settings-directory-${width.toInt()}');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(storage.relocations, 0);
        await tester.tap(find.text('设置'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SelectableText>(
                find.byKey(const ValueKey('data-directory-path')),
              )
              .data,
          storage.directoryPath,
        );
        await tester.tap(find.byKey(const ValueKey('choose-data-directory')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('request-timeout-seconds')),
          '45',
        );
        await tester.tap(find.text('保存设置'));
        await tester.pumpAndSettle();
        expect(find.text('保存设置'), findsNothing);
        expect(storage.directoryPath, selected);
        expect(storage.relocations, 1);
        expect(c.timeoutSeconds, 45);
        expect(storage.data!['drafts'][0]['name'], '保留的接口');
        expect(tester.takeException(), isNull);
        await tester.runAsync(c.flush);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final size in [const Size(1440, 800), const Size(1280, 720)]) {
    testWidgets(
      'settings loads an existing workspace and resets cloned request editors at $size',
      (tester) async {
        final storage = RelocatingMemoryStorage();
        final c = WorkspaceFixture(nativeWindow: true, storage: storage);
        await c.initialize();
        addTearDown(c.dispose);
        final old = c.create(
          RequestSpec(name: '旧工作区接口', url: 'http://old.example'),
        );
        c.responses[old.id] = ResponseRecord(body: '旧工作区响应');
        final loaded = old.copyWith(
          name: '目标工作区接口',
          url: 'http://new.example',
          protocol: 'sse',
        );
        storage.existingWorkspace = WorkspaceJson.encode(
          WorkspaceSnapshot(
            requests: [loaded],
            drafts: [loaded],
            activeId: loaded.id,
            timeoutSeconds: 57,
            sseMaxResponseMb: 8,
          ),
        );
        const selected = r'D:\已有工作区';
        const channel = MethodChannel('weils/window');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => selected,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final key = GlobalKey();
        await show(tester, c, key, size);
        expect(c.dependencies.execution.responseFor(old.id), isNotNull);
        await tester.tap(find.text('设置'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('choose-data-directory')));
        await tester.pumpAndSettle();
        await capture(
          tester,
          key,
          'settings-load-workspace-${size.width.toInt()}',
        );
        await tester.tap(find.text('保存设置'));
        await tester.pumpAndSettle();
        expect(find.text('保存设置'), findsNothing);
        expect(c.active!.name, '目标工作区接口');
        expect(c.timeoutSeconds, 57);
        expect(c.snapshot.sseMaxResponseMb, 8);
        expect(storage.directoryPath, selected);
        expect(c.dependencies.execution.responseFor(old.id), isNull);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('request-url')))
              .controller!
              .text,
          'http://new.example',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'directory picker and migration failures remain recoverable in settings',
    (tester) async {
      final storage = RelocatingMemoryStorage()..failRelocation = true;
      final c = WorkspaceFixture(nativeWindow: true, storage: storage);
      await c.initialize();
      addTearDown(c.dispose);
      final key = GlobalKey();
      await show(tester, c, key, const Size(1000, 650));
      var pickerFails = true;
      const channel = MethodChannel('weils/window');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (pickerFails) throw PlatformException(code: 'directory_picker');
        return r'D:\工作区数据';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-data-directory')));
      await tester.pumpAndSettle();
      expect(find.text('无法打开目录选择器，请重试。'), findsOneWidget);
      pickerFails = false;
      await tester.tap(find.byKey(const ValueKey('choose-data-directory')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('request-timeout-seconds')),
        '70',
      );
      await tester.tap(find.text('保存设置'));
      await tester.pumpAndSettle();
      expect(find.text('所选目录的工作区无法加载，请检查 workspace.json 及备份文件。'), findsOneWidget);
      expect(storage.relocations, 0);
      expect(c.timeoutSeconds, 30);
      await capture(tester, key, 'settings-directory-error');
      storage.failRelocation = false;
      await tester.tap(find.text('保存设置'));
      await tester.pumpAndSettle();
      expect(storage.directoryPath, r'D:\工作区数据');
      expect(c.timeoutSeconds, 70);
      expect(find.text('保存设置'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
