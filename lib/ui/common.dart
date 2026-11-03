import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import 'theme.dart';

class ApiMark extends StatelessWidget {
  const ApiMark({super.key, this.size = 26});
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '{',
        style: TextStyle(
          fontFamily: 'Consolas',
          fontSize: size * 1.5,
          color: AppColors.primary,
          height: 1,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(
          'API',
          style: TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: size * .64,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
      Text(
        '}',
        style: TextStyle(
          fontFamily: 'Consolas',
          fontSize: size * 1.5,
          color: AppColors.primary,
          height: 1,
        ),
      ),
    ],
  );
}

class WorkTab extends StatelessWidget {
  const WorkTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 3, top: 7),
    child: Material(
      color: selected ? AppColors.selection : Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    ),
  );
}

class SectionTabs extends StatelessWidget {
  const SectionTabs({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.trailing,
  });
  final List<String> tabs;
  final String value;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        for (final tab in tabs)
          InkWell(
            onTap: () => onChanged(tab),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: value == tab
                        ? AppColors.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 13,
                  color: value == tab ? AppColors.primary : AppColors.muted,
                  fontWeight: value == tab ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    ),
  );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: const Color(0xFF9CAAC0)),
            const SizedBox(height: 17),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 9),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}

String prettyJson(String input) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(input));
  } catch (_) {
    return input;
  }
}

class CodeView extends StatefulWidget {
  const CodeView({super.key, required this.text, this.syntax = false});
  final String text;
  final bool syntax;
  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  final _vertical = ScrollController(), _horizontal = ScrollController();
  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  List<TextSpan> _spans(String text) {
    if (!widget.syntax) return [TextSpan(text: text)];
    final pattern = RegExp(
      r'"(?:\\.|[^"\\])*"\s*:|"(?:\\.|[^"\\])*"|\b(?:true|false|null|-?\d+(?:\.\d+)?)\b',
    );
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in pattern.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(start, match.start)));
      final token = match.group(0)!;
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: token.endsWith(':')
                ? const Color(0xFF4665A0)
                : token.startsWith('"')
                ? AppColors.green
                : const Color(0xFF986B28),
          ),
        ),
      );
      start = match.end;
    }
    spans.add(TextSpan(text: text.substring(start)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text.length > 200000
        ? widget.text.substring(0, 200000)
        : widget.text;
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        thumbVisibility: true,
        controller: _vertical,
        child: SingleChildScrollView(
          controller: _vertical,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Scrollbar(
            controller: _horizontal,
            notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: (constraints.maxWidth - 40).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: SelectableText.rich(
                  TextSpan(children: _spans(text)),
                  style: codeStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResponsePane extends StatefulWidget {
  const ResponsePane({super.key, this.response, this.running = false});
  final ResponseRecord? response;
  final bool running;
  @override
  State<ResponsePane> createState() => _ResponsePaneState();
}

class _ResponsePaneState extends State<ResponsePane> {
  String _tab = 'Body';
  bool _pretty = true;
  String _formatted = '';
  @override
  void initState() {
    super.initState();
    _formatted = prettyJson(widget.response?.body ?? '');
  }

  @override
  void didUpdateWidget(ResponsePane old) {
    super.didUpdateWidget(old);
    if (!identical(old.response, widget.response)) {
      _formatted = prettyJson(widget.response?.body ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.response;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 0),
          child: Row(
            children: [
              const Text(
                '响应结果',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (widget.running)
                const Text(
                  '请求进行中…',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              if (!widget.running && r != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (r.success
                                ? AppColors.green
                                : r.cancelled
                                ? AppColors.muted
                                : AppColors.red)
                            .withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: r.success
                          ? AppColors.green
                          : r.cancelled
                          ? AppColors.muted
                          : AppColors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${r.elapsedMs} ms',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(width: 16),
                Text(
                  r.sizeLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionTabs(
            tabs: const ['Body', 'Headers'],
            value: _tab,
            onChanged: (v) => setState(() => _tab = v),
            trailing: Row(
              children: [
                if (r != null && r.body.isNotEmpty && _tab == 'Body')
                  TextButton(
                    onPressed: () => setState(() => _pretty = !_pretty),
                    child: Text(
                      _pretty ? '格式化' : '原文',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                IconButton(
                  tooltip: '复制响应',
                  onPressed: r == null
                      ? null
                      : () {
                          final content = _tab == 'Body'
                              ? r.body
                              : r.headers.entries
                                    .map((e) => '${e.key}: ${e.value}')
                                    .join('\n');
                          Clipboard.setData(ClipboardData(text: content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已复制响应'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                  icon: const Icon(Icons.copy_outlined, size: 16),
                ),
              ],
            ),
          ),
        ),
        if (r?.truncated == true || (r?.body.length ?? 0) > 200000)
          Container(
            color: AppColors.shell,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              r!.truncated
                  ? '响应超过 2 MB，已截断捕获；大小表示已接收的数据。'
                  : '长响应仅预览前 200,000 个字符；复制可获取完整捕获内容。',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        Expanded(
          child: widget.running
              ? Column(
                  children: [
                    const LinearProgressIndicator(minHeight: 2),
                    const Expanded(
                      child: EmptyMessage(
                        icon: Icons.swap_vert_rounded,
                        title: '正在等待服务器响应',
                        subtitle: '可以随时取消本次请求',
                      ),
                    ),
                  ],
                )
              : r == null
              ? const EmptyMessage(
                  icon: Icons.data_object_rounded,
                  title: '响应将在这里显示',
                  subtitle: '编辑请求后，点击发送或按 Ctrl + Enter',
                )
              : r.error != null || r.cancelled
              ? EmptyMessage(
                  icon: r.cancelled
                      ? Icons.stop_circle_outlined
                      : Icons.cloud_off_outlined,
                  title: r.cancelled ? '请求已取消' : '请求未完成',
                  subtitle: r.error ?? '编辑内容已保留，可以重新发送。',
                )
              : _tab == 'Headers'
              ? CodeView(
                  text: r.headers.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                )
              : r.body.isEmpty
              ? const EmptyMessage(
                  icon: Icons.data_object_rounded,
                  title: '响应正文为空',
                  subtitle: '状态码与响应头仍可查看',
                )
              : CodeView(text: _pretty ? _formatted : r.body, syntax: _pretty),
        ),
      ],
    );
  }
}
