import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Inserts two spaces in an editor while leaving Shift+Tab for focus traversal.
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

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.tab): _insertIndent},
    child: child,
  );
}
