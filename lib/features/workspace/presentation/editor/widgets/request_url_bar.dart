import 'package:flutter/material.dart';

import 'package:weils_api/core/theme/app_theme.dart';
import 'package:weils_api/features/workspace/domain/entities/request_spec.dart';
import 'package:weils_api/shared/widgets/anchored_select.dart';
import '../../formatters/method_style.dart';

class RequestUrlBar extends StatelessWidget {
  const RequestUrlBar({
    super.key,
    required this.request,
    required this.urlController,
    required this.onMethodChanged,
    required this.onUrlChanged,
    required this.onSend,
    required this.onCancel,
    required this.running,
    required this.runningId,
  });
  final RequestSpec request;
  final TextEditingController urlController;
  final ValueChanged<String> onMethodChanged, onUrlChanged;
  final VoidCallback onSend, onCancel;
  final bool running;
  final String? runningId;
  RequestSpec get r => request;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnchoredSelect(
                      id: 'request-method',
                      label: '请求方式',
                      value: r.method,
                      width: 103,
                      height: 38,
                      menuWidth: 156,
                      monospace: true,
                      options: [
                        for (final m in [
                          'GET',
                          'POST',
                          'PUT',
                          'PATCH',
                          'DELETE',
                          'HEAD',
                          'OPTIONS',
                        ])
                          SelectOption(m, m, color: methodColor(m)),
                      ],
                      onChanged: onMethodChanged,
                    ),
                  ),
                  Container(width: 1, height: 24, color: AppColors.line),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('request-url'),
                      controller: urlController,
                      style: codeStyle.copyWith(height: 1.2),
                      decoration: const InputDecoration(
                        hintText: 'https://api.example.com/users',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 12,
                        ),
                      ),
                      onChanged: onUrlChanged,
                      onSubmitted: (_) {
                        onSend();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 91,
            height: 40,
            child: Tooltip(
              message: running && runningId != r.id
                  ? '另一个标签页正在发送请求'
                  : '发送请求 · Ctrl + Enter',
              child: FilledButton(
                key: const ValueKey('send-request'),
                onPressed: running
                    ? (runningId == r.id ? onCancel : null)
                    : () {
                        onSend();
                      },
                child: Text(runningId == r.id ? '取消' : '发送'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
