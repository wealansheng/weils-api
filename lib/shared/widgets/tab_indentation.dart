import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 为编辑器提供两空格缩进，Shift+Tab 继续用于焦点切换。
class TabIndentation extends StatelessWidget {
  const TabIndentation({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.child,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Widget child;

  /// 用两个空格替换当前选区并移动光标，清除输入法组合区后通知正文更新。
  void _insertIndent() {
    final value = controller.value;
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final end = value.selection.isValid
        ? value.selection.end
        : value.text.length;
    controller.value = value.copyWith(
      text: value.text.replaceRange(start, end, '  '),
      selection: TextSelection.collapsed(offset: start + 2),
      composing: TextRange.empty,
    );
    onChanged(controller.text);
  }

  /// 拦截 Tab 键并执行两空格缩进，使多行编辑保持当前输入焦点。
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.tab): _insertIndent},
    child: child,
  );
}
