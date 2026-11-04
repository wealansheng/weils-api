import 'package:flutter/material.dart';

import 'package:weils_api/shared/widgets/tab_indentation.dart';

/// 同步外部模板更新与文本编辑，避免每次输入都重置光标选区。
class MockInput extends StatefulWidget {
  const MockInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.hint,
    this.lines = 1,
    this.expand = false,
    this.monospace = false,
    this.enabled = true,
    this.indentOnTab = false,
  });
  final String value, label;
  final String? hint;
  final ValueChanged<String> onChanged;
  final int lines;
  final bool expand, monospace, enabled, indentOnTab;
  /// 创建 Mock 输入框的文本控制状态。
  @override
  State<MockInput> createState() => _MockInputState();
}

class _MockInputState extends State<MockInput> {
  late final _controller = TextEditingController(text: widget.value);
  /// 外部值变化时同步输入内容，避免每次重建都覆盖用户光标。
  @override
  void didUpdateWidget(MockInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  /// 释放当前输入框持有的文本控制器。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 根据行数与代码样式构建输入框，多行编辑复用 Tab 两空格缩进逻辑。
  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      maxLines: widget.expand ? null : widget.lines,
      minLines: widget.expand ? null : widget.lines,
      expands: widget.expand,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(
        fontSize: 13,
        fontFamily: widget.monospace ? 'Consolas' : null,
        height: 1.5,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        alignLabelWithHint: true,
      ),
    );
    return widget.indentOnTab
        ? TabIndentation(
            controller: _controller,
            onChanged: widget.onChanged,
            child: field,
          )
        : field;
  }
}
