import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/core/utils/json_format.dart';
import 'package:weils_api/features/workspace/domain/entities/request_spec.dart';
import 'package:weils_api/shared/widgets/anchored_select.dart';
import 'package:weils_api/shared/widgets/tab_indentation.dart';

class RequestBodyEditor extends StatefulWidget {
  const RequestBodyEditor({
    super.key,
    required this.request,
    required this.onChanged,
    required this.onTypeChanged,
  });
  final RequestSpec request;
  final ValueChanged<String> onChanged, onTypeChanged;
  /// 创建正文编辑所需的文本输入状态。
  @override
  State<RequestBodyEditor> createState() => _RequestBodyEditorState();
}

class _RequestBodyEditorState extends State<RequestBodyEditor> {
  late final TextEditingController _body = TextEditingController(
    text: widget.request.body,
  );
  RequestSpec get r => widget.request;
  /// 释放正文编辑区域的文本输入控制器。
  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  /// 展示正文类型与文本编辑器，复用 Tab 两空格缩进并支持 JSON 格式化。
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
            : TabIndentation(
                controller: _body,
                onChanged: widget.onChanged,
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
