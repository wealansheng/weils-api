import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/features/workspace/domain/entities/response_record.dart';
import 'package:weils_api/shared/widgets/empty_message.dart';
import 'package:weils_api/shared/widgets/section_tabs.dart';

import '../../formatters/workspace_messages.dart';
import 'response_headers_table.dart';

class SseResponsePane extends StatefulWidget {
  const SseResponsePane({
    super.key,
    required this.response,
    required this.running,
  });
  final ResponseRecord? response;
  final bool running;
  /// 创建 SSE 视图切换及各文本视图独立的滚动跟随状态。
  @override
  State<SseResponsePane> createState() => _SseResponsePaneState();
}

class _SseResponsePaneState extends State<SseResponsePane> {
  String _tab = '事件';
  final _controllers = <String, ScrollController>{};
  final _follow = <String, bool>{};
  ResponseRecord? get r => widget.response;

  /// 为事件、拼接 data 和原文建立滚动控制器，用户离开底部时暂停自动跟随。
  @override
  void initState() {
    super.initState();
    for (final tab in ['事件', '拼接 data', '原文']) {
      final controller = ScrollController();
      _controllers[tab] = controller;
      _follow[tab] = true;
      controller.addListener(() {
        if (controller.hasClients) {
          _follow[tab] = controller.position.extentAfter < 40;
        }
      });
    }
  }

  /// 新请求清空旧响应时恢复默认事件视图和底部跟随。
  @override
  void didUpdateWidget(SseResponsePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (r == null && oldWidget.response != null) {
      _tab = '事件';
      _follow.updateAll((_, _) => true);
    }
  }

  /// 释放 SSE 各视图持有的滚动控制器。
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 返回当前视图的完整复制内容，独立于界面预览截断。
  String _copyText(String tab) => switch (tab) {
    'Headers' =>
      r!.headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
    '原文' => r!.body,
    '拼接 data' => r!.sseData,
    _ =>
      r!.sseEvents.indexed
          .map(
            (item) =>
                '#${item.$1 + 1} event: ${item.$2.type}\nid: ${item.$2.id}\ndata:\n${item.$2.data}',
          )
          .join('\n\n'),
  };

  /// 根据连接、停止、错误和截断状态生成当前 SSE 连接说明。
  String get _state {
    if (widget.running) {
      return r == null
          ? '正在连接…'
          : r!.isSse
          ? '接收中'
          : '正在读取响应…';
    }
    if (r == null) return '等待发送';
    if (r!.cancelled) return '已停止';
    if (r!.hasError) return r!.isSse ? '连接中断' : '连接失败';
    if (r!.truncated) return '达到捕获上限';
    return r!.isSse ? '连接已结束' : '未建立 SSE 流';
  }

  /// 展示 SSE 连接信息和四种视图，保留部分响应，并仅在用户停留底部时跟随新内容。
  @override
  Widget build(BuildContext context) {
    final fallback = r != null && !r!.isSse;
    final tabs = fallback
        ? const ['原文', 'Headers']
        : const ['事件', '拼接 data', '原文', 'Headers'];
    final tab = tabs.contains(_tab) ? _tab : tabs.first;
    final controller = _controllers[tab];
    if (controller != null && _follow[tab] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients && _follow[tab] == true) {
          controller.jumpTo(controller.position.maxScrollExtent);
        }
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 4),
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'SSE 响应',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                _state,
                key: const ValueKey('sse-state'),
                style: TextStyle(
                  color: r?.hasError == true
                      ? AppColors.red
                      : widget.running
                      ? AppColors.primary
                      : AppColors.muted,
                  fontSize: 12,
                ),
              ),
              if (r?.statusCode != null)
                Text(
                  '${r!.statusCode} ${r!.reason}'.trim(),
                  style: const TextStyle(fontSize: 12),
                ),
              if (r?.isSse == true)
                Text(
                  '${r!.sseEvents.length} 个事件',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              if (r != null)
                Text(
                  '${r!.elapsedMs} ms · ${r!.sizeLabel}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionTabs(
            tabs: tabs,
            value: tab,
            onChanged: (v) => setState(() => _tab = v),
            trailing: IconButton(
              key: const ValueKey('copy-sse-response'),
              tooltip: '复制当前视图',
              onPressed: r == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: _copyText(tab)));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制响应'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
              icon: const Icon(Icons.copy_outlined, size: 16),
            ),
          ),
        ),
        if (widget.running) const LinearProgressIndicator(minHeight: 2),
        if (r?.truncated == true ||
            r?.error != null ||
            (fallback && !widget.running))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              r!.truncated
                  ? '已达到 ${(r!.captureLimitBytes ?? 2 * 1024 * 1024) ~/ (1024 * 1024)} MB 捕获上限，连接已停止，已收内容保留。'
                  : r!.error ?? '响应不是 HTTP 200 的 text/event-stream，以下保留实际响应内容。',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        Expanded(
          child: r == null
              ? const EmptyMessage(
                  icon: Icons.swap_vert_rounded,
                  title: '等待 SSE 响应',
                  subtitle: '发送后将持续显示事件，可以随时停止',
                )
              : tab == 'Headers'
              ? ResponseHeadersTable(headers: r!.headers)
              : tab == '事件'
              ? _events(controller!)
              : _text(tab, controller!),
        ),
      ],
    );
  }

  /// 惰性构建事件列表，展示序号、类型、id 与 data；长事件仅截断界面预览。
  Widget _events(ScrollController controller) {
    if (r!.sseEvents.isEmpty) {
      return const EmptyMessage(
        icon: Icons.data_object_rounded,
        title: '尚未收到完整事件',
        subtitle: '心跳和未完成的事件可在原文中查看',
      );
    }
    return Scrollbar(
      controller: controller,
      child: ListView.builder(
        key: const ValueKey('sse-events'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        itemCount: r!.sseEvents.length,
        itemBuilder: (context, index) {
          final event = r!.sseEvents[index];
          return Padding(
            key: ValueKey('sse-event-$index'),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  '#${index + 1}  event: ${event.type}${event.id.isEmpty ? '' : '  id: ${event.id}'}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  event.data.length > 200000
                      ? '${event.data.substring(0, 200000)}\n…事件预览已截断，复制可获取完整内容'
                      : event.data,
                  style: codeStyle,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 展示原文或直接拼接的 data；长内容只预览末尾片段，复制仍保留全文。
  Widget _text(String tab, ScrollController controller) {
    final full = tab == '原文' ? r!.body : r!.sseData;
    if (full.isEmpty) {
      return const EmptyMessage(
        icon: Icons.data_object_rounded,
        title: '尚无内容',
        subtitle: '收到数据后会实时追加',
      );
    }
    final text = full.length <= 200000
        ? full
        : '…仅预览最近 200,000 个字符；复制可获取完整捕获内容\n${full.substring(full.length - 200000)}';
    return Scrollbar(
      controller: controller,
      child: SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SelectableText(
          text,
          key: ValueKey(tab == '原文' ? 'sse-raw' : 'sse-data'),
          style: codeStyle,
        ),
      ),
    );
  }
}
