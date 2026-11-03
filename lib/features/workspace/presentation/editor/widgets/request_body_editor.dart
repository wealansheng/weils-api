import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/json_format.dart';
import '../../../domain/entities/request_spec.dart';
import '../../../../../shared/widgets/anchored_select.dart';

class RequestBodyEditor extends StatefulWidget {
  const RequestBodyEditor({
    super.key,
    required this.request,
    required this.onChanged,
    required this.onTypeChanged,
  });
  final RequestSpec request;
  final ValueChanged<String> onChanged, onTypeChanged;
  @override
  State<RequestBodyEditor> createState() => _RequestBodyEditorState();
}

class _RequestBodyEditorState extends State<RequestBodyEditor> {
  late final TextEditingController _body = TextEditingController(
    text: widget.request.body,
  );
  RequestSpec get r => widget.request;
  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _insertBodyIndent() {
    final value = _body.value;
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final end = value.selection.isValid
        ? value.selection.end
        : value.text.length;
    _body.value = value.copyWith(
      text: value.text.replaceRange(start, end, '  '),
      selection: TextSelection.collapsed(offset: start + 2),
      composing: TextRange.empty,
    );
    widget.onChanged(_body.text);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 38,
        child: Row(
          children: [
            AnchoredSelect(
              id: 'request-body-type',
              label: '正文类型',
              value: r.bodyType,
              width: 120,
              menuWidth: 160,
              options: const [
                SelectOption('none', '无 Body'),
                SelectOption('json', 'JSON'),
                SelectOption('text', '原始文本'),
              ],
              onChanged: (v) {
                widget.onTypeChanged(v);
              },
            ),
            const Spacer(),
            if (r.bodyType == 'json')
              TextButton(
                onPressed: () {
                  _body.text = prettyJson(r.body);
                  widget.onChanged(_body.text);
                },
                child: const Text('格式化'),
              ),
          ],
        ),
      ),
      Expanded(
        child: r.bodyType == 'none'
            ? const Center(
                child: Text(
                  '此请求不发送正文',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              )
            : CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.tab):
                      _insertBodyIndent,
                },
                child: TextField(
                  key: const ValueKey('request-body'),
                  controller: _body,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: codeStyle,
                  decoration: InputDecoration(
                    hintText: r.bodyType == 'json'
                        ? '{\n  "key": "value"\n}'
                        : '输入请求正文',
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: (v) {
                    widget.onChanged(v);
                  },
                ),
              ),
      ),
      const SizedBox(height: 6),
    ],
  );
}
