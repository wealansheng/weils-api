import 'package:flutter/material.dart';

import '../../../../shared/widgets/tab_indentation.dart';

/// Keeps external template updates and text editing in sync without resetting
/// the selection on every keystroke.
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
  @override
  State<MockInput> createState() => _MockInputState();
}

class _MockInputState extends State<MockInput> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(MockInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
