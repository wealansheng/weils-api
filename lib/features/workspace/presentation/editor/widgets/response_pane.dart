import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/json_format.dart';
import '../../../domain/entities/response_record.dart';
import '../../formatters/workspace_messages.dart';
import '../../../../../shared/widgets/code_view.dart';
import '../../../../../shared/widgets/section_tabs.dart';
import '../../../../../shared/widgets/empty_message.dart';
import 'response_headers_table.dart';

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
              ? ResponseHeadersTable(
                  key: const ValueKey('response-headers-table'),
                  headers: r.headers,
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
