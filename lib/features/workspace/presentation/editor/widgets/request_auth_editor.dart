import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/request_spec.dart';
import '../../../../../shared/widgets/anchored_select.dart';

class RequestAuthEditor extends StatefulWidget {
  const RequestAuthEditor({
    super.key,
    required this.request,
    required this.onChanged,
    required this.onTypeChanged,
  });
  final RequestSpec request;
  final ValueChanged<String> onChanged, onTypeChanged;
  @override
  State<RequestAuthEditor> createState() => _RequestAuthEditorState();
}

class _RequestAuthEditorState extends State<RequestAuthEditor> {
  late final TextEditingController _token = TextEditingController(
    text: widget.request.token,
  );
  RequestSpec get r => widget.request;
  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(top: 12),
    children: [
      Row(
        children: [
          const SizedBox(
            width: 82,
            child: Text('认证方式', style: TextStyle(fontSize: 12)),
          ),
          AnchoredSelect(
            id: 'request-auth-type',
            label: '认证方式',
            value: r.authType,
            width: 154,
            menuWidth: 180,
            options: const [
              SelectOption('none', '无认证'),
              SelectOption('bearer', 'Bearer Token'),
            ],
            onChanged: (v) {
              widget.onTypeChanged(v);
            },
          ),
        ],
      ),
      if (r.authType == 'bearer') ...[
        const SizedBox(height: 15),
        TextField(
          controller: _token,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          style: codeStyle,
          decoration: const InputDecoration(
            labelText: 'Token',
            hintText: '填写 Token，无需 Bearer 前缀',
          ),
          onChanged: (v) {
            widget.onChanged(v);
          },
        ),
        const SizedBox(height: 8),
        const Text(
          '发送时自动添加 Authorization Header。',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ],
  );
}
