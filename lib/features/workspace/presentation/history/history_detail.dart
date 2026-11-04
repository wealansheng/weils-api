import 'package:flutter/material.dart';

import '../../domain/entities/workspace_entities.dart';
import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/core/utils/json_format.dart';
import 'package:weils_api/shared/widgets/code_view.dart';
import 'package:weils_api/shared/widgets/section_tabs.dart';
import '../editor/widgets/response_pane.dart';
import '../formatters/method_style.dart';

/// 将时间格式化为补零的时分秒，用于历史记录显示。
String clockLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
/// 生成历史记录的日期分组标签。
String dateLabel(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

class HistoryDetail extends StatefulWidget {
  const HistoryDetail({
    super.key,
    required this.record,
    required this.onReplay,
  });
  final HistoryRecord record;
  final VoidCallback onReplay;
  /// 创建历史详情中的请求分区选择状态。
  @override
  State<HistoryDetail> createState() => _HistoryDetailState();
}

class _HistoryDetailState extends State<HistoryDetail> {
  String _tab = 'Params';
  /// 展示历史请求快照与最终响应，提供复制和重新编辑入口。
  @override
  Widget build(BuildContext context) {
    final r = widget.record.request;
    /// 按分区生成历史请求的参数、启用的自定义 Headers、正文或隐藏 Token 的认证摘要。
    String requestText() => switch (_tab) {
      'Params' =>
        r.effectiveUri.queryParametersAll.entries
            .map((e) => '${e.key}: ${e.value.join(', ')}')
            .join('\n'),
      'Headers' =>
        r.headers
            .where((e) => e.enabled && e.name.isNotEmpty)
            .map((e) => '${e.name}: ${e.value}')
            .join('\n'),
      'Body' =>
        r.bodyType == 'none'
            ? ''
            : r.bodyType == 'json'
            ? prettyJson(r.body)
            : r.body,
      _ =>
        r.authType == 'bearer'
            ? 'Bearer Token：${r.token.isEmpty ? '未填写' : '已配置（隐藏）'}'
            : '无认证',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: const Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: AppColors.muted),
              SizedBox(width: 8),
              Text(
                '历史快照',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              Spacer(),
              Text(
                '只读',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${dateLabel(widget.record.time)}  ${clockLabel(widget.record.time)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('replay-history'),
                onPressed: widget.onReplay,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('编辑并重发'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(7),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                Text(
                  r.method,
                  style: codeStyle.copyWith(
                    color: methodColor(r.method),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      r.effectiveUri.toString(),
                      style: codeStyle.copyWith(height: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                SizedBox(
                  height: (constraints.maxHeight * .33).clamp(130.0, 220.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        SectionTabs(
                          tabs: const ['Params', 'Headers', 'Body', '认证'],
                          value: _tab,
                          onChanged: (v) => setState(() => _tab = v),
                        ),
                        Expanded(
                          child: requestText().isEmpty
                              ? Center(
                                  child: Text(
                                    '没有${_tab == 'Body'
                                        ? '请求正文'
                                        : _tab == 'Params'
                                        ? '查询参数'
                                        : '自定义 Header'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                )
                              : CodeView(
                                  text: requestText(),
                                  syntax:
                                      _tab == 'Body' && r.bodyType == 'json',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Expanded(child: ResponsePane(response: widget.record.response)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
