import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CodeView extends StatefulWidget {
  const CodeView({super.key, required this.text, this.syntax = false});
  final String text;
  final bool syntax;
  /// 创建代码预览的横向与纵向滚动状态。
  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  final _vertical = ScrollController(), _horizontal = ScrollController();
  /// 释放代码预览的两个方向滚动控制器。
  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  /// 按 JSON 键、字符串和字面量生成高亮片段，保留未匹配的原文。
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

  /// 构建可选择的双向滚动代码预览，限制单次渲染字符量以控制界面开销。
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
