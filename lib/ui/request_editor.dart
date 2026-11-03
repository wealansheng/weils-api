import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/request_headers.dart';
import '../core/workspace_controller.dart';
import 'anchored_select.dart';
import 'common.dart';
import 'theme.dart';

class RequestEditor extends StatefulWidget {
  const RequestEditor({
    super.key,
    required this.controller,
    required this.request,
    required this.onSave,
  });
  final WorkspaceController controller;
  final RequestSpec request;
  final VoidCallback onSave;
  @override
  State<RequestEditor> createState() => _RequestEditorState();
}

class _RequestEditorState extends State<RequestEditor> {
  late final TextEditingController _name, _url, _body, _token;
  String _tab = 'Params';
  double? _requestHeight;
  WorkspaceController get c => widget.controller;
  RequestSpec get r => widget.request;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: r.name);
    _url = TextEditingController(text: r.url);
    _body = TextEditingController(text: r.body);
    _token = TextEditingController(text: r.token);
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _body.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RequestEditor old) {
    super.didUpdateWidget(old);
    if (_name.text != r.name) _name.text = r.name;
  }

  void _insertBodyIndent() {
    final value = _body.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    _body.value = value.copyWith(
      text: value.text.replaceRange(start, end, '  '),
      selection: TextSelection.collapsed(offset: start + 2),
      composing: TextRange.empty,
    );
    // Controller updates do not invoke TextField.onChanged.
    r.body = _body.text;
    c.changed();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                width: 240,
                height: 34,
                child: TextField(
                  key: const ValueKey('request-name'),
                  controller: _name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '接口名称',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 7),
                  ),
                  onChanged: (v) {
                    r.name = v;
                    c.changed();
                  },
                ),
              ),
            ),
            if (c.isDirty(r))
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  '未保存',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            const Spacer(),
            Icon(Icons.folder_outlined, size: 15, color: AppColors.muted),
            const SizedBox(width: 5),
            AnchoredSelect(
              id: 'request-folder',
              label: '所属模块',
              value: r.folderId,
              width: 130,
              menuWidth: 220,
              options: c.folders
                  .map((f) => SelectOption(f.id, f.name))
                  .toList(),
              onChanged: (v) {
                r.folderId = v;
                c.changed();
              },
            ),
            const SizedBox(width: 16),
            Tooltip(
              message: '保存接口 · Ctrl + S',
              child: OutlinedButton(
                onPressed: widget.onSave,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
      Padding(
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
                          onChanged: (v) {
                            r.method = v;
                            c.changed();
                          },
                        ),
                      ),
                      Container(width: 1, height: 24, color: AppColors.line),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('request-url'),
                          controller: _url,
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
                          onChanged: (v) {
                            r.url = v;
                            c.changed();
                          },
                          onSubmitted: (_) {
                            c.send(r);
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
                  message: c.running && c.runningId != r.id
                      ? '另一个标签页正在发送请求'
                      : '发送请求 · Ctrl + Enter',
                  child: FilledButton(
                    key: const ValueKey('send-request'),
                    onPressed: c.running
                        ? (c.runningId == r.id ? c.cancel : null)
                        : () {
                            c.send(r);
                          },
                    child: Text(c.runningId == r.id ? '取消' : '发送'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (c.validationError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 20, 0),
          child: Text(
            c.validationError!,
            style: const TextStyle(fontSize: 12, color: AppColors.red),
          ),
        ),
      const SizedBox(height: 9),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maximum = (constraints.maxHeight - 150).clamp(
              120.0,
              double.infinity,
            );
            final height =
                (_requestHeight ?? (_tab == 'Headers' ? 260.0 : 184.0)).clamp(
                  120.0,
                  maximum,
                );
            return Column(
              children: [
                SizedBox(
                  height: height,
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
                          child: switch (_tab) {
                            'Params' => EntryTable(
                              key: ValueKey('${r.id}-params'),
                              entries: r.params,
                              onChanged: c.changed,
                              kind: '参数',
                            ),
                            'Headers' => EntryTable(
                              key: ValueKey('${r.id}-headers'),
                              entries: r.headers,
                              onChanged: c.changed,
                              kind: 'Header',
                              defaults: defaultRequestHeaders(r),
                              stickyAdd: true,
                            ),
                            'Body' => _bodyEditor(),
                            _ => _authEditor(),
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Semantics(
                  label: '拖动调整请求区与响应区高度',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) => setState(
                        () => _requestHeight = (height + details.delta.dy)
                            .clamp(120.0, maximum),
                      ),
                      child: SizedBox(
                        height: 12,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Divider(),
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: const Icon(
                                Icons.drag_handle_rounded,
                                size: 13,
                                color: Color(0xFFA0AEC1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ResponsePane(
                    response: c.responses[r.id],
                    running: c.runningId == r.id,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _bodyEditor() => Column(
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
                r.bodyType = v;
                c.changed();
              },
            ),
            const Spacer(),
            if (r.bodyType == 'json')
              TextButton(
                onPressed: () {
                  r.body = prettyJson(r.body);
                  _body.text = r.body;
                  c.changed();
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
                    r.body = v;
                    c.changed();
                  },
                ),
              ),
      ),
      const SizedBox(height: 6),
    ],
  );
  Widget _authEditor() => ListView(
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
              r.authType = v;
              c.changed();
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
            r.token = v;
            c.changed();
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

class EntryTable extends StatelessWidget {
  const EntryTable({
    super.key,
    required this.entries,
    required this.onChanged,
    required this.kind,
    this.defaults = const [],
    this.stickyAdd = false,
  });
  final List<Entry> entries;
  final VoidCallback onChanged;
  final String kind;
  final List<DefaultHeader> defaults;
  final bool stickyAdd;
  Widget _add() => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () {
        entries.add(Entry());
        onChanged();
      },
      icon: const Icon(Icons.add, size: 14),
      label: Text('添加$kind', style: const TextStyle(fontSize: 12)),
    ),
  );
  Widget _defaultRow(DefaultHeader header) => Container(
    key: ValueKey('default-header-${header.name.toLowerCase()}'),
    height: 36,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 36,
          child: Tooltip(
            message: '自动生成，添加同名 Header 可覆盖',
            child: Icon(Icons.check_rounded, size: 15, color: AppColors.muted),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SelectableText(
              header.name,
              maxLines: 1,
              style: codeStyle.copyWith(
                fontSize: 12,
                height: 1.2,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                header.value,
                maxLines: 1,
                style: codeStyle.copyWith(
                  fontSize: 12,
                  height: 1.2,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
        ),
        const Expanded(
          flex: 2,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '默认',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(width: 30),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 33,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 36),
            Expanded(
              flex: 3,
              child: Text(
                '$kind名',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
            const Expanded(
              flex: 4,
              child: Text(
                '值',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
            const Expanded(
              flex: 2,
              child: Text(
                '说明',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 30),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: defaults.length + entries.length + (stickyAdd ? 0 : 1),
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final automatic = defaults.indexWhere(
              (h) => 'default-header-${h.name.toLowerCase()}' == key.value,
            );
            if (automatic >= 0) return automatic;
            final custom = entries.indexWhere((e) => e.id == key.value);
            return custom >= 0 ? defaults.length + custom : null;
          },
          itemBuilder: (context, index) {
            if (index < defaults.length) return _defaultRow(defaults[index]);
            final customIndex = index - defaults.length;
            if (customIndex == entries.length) {
              return _add();
            }
            final e = entries[customIndex];
            Widget field(
              String key,
              String value,
              String hint,
              ValueChanged<String> update,
            ) => TextFormField(
              key: ValueKey('${e.id}-$key'),
              initialValue: value,
              style: codeStyle.copyWith(fontSize: 12, height: 1.2),
              decoration: InputDecoration(
                hintText: hint,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              onChanged: (v) {
                update(v);
                onChanged();
              },
            );
            return Container(
              key: ValueKey(e.id),
              height: 36,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Checkbox(
                      semanticLabel: '启用${e.name.isEmpty ? kind : e.name}',
                      value: e.enabled,
                      onChanged: (v) {
                        e.enabled = v ?? false;
                        onChanged();
                      },
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: field('name', e.name, '名称', (v) => e.name = v),
                  ),
                  Expanded(
                    flex: 4,
                    child: field('value', e.value, '值', (v) => e.value = v),
                  ),
                  Expanded(
                    flex: 2,
                    child: field(
                      'description',
                      e.description,
                      '可选',
                      (v) => e.description = v,
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: IconButton(
                      tooltip: '删除$kind',
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () {
                        entries.remove(e);
                        onChanged();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      if (stickyAdd) SizedBox(height: 34, child: _add()),
    ],
  );
}
