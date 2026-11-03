import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_tabs.dart';
import '../../domain/entities/workspace_entities.dart';
import '../formatters/workspace_messages.dart';
import 'view_models/request_editor_view_model.dart';
import 'view_models/request_execution_view_model.dart';
import 'widgets/entry_table.dart';
import 'widgets/request_identity_bar.dart';
import 'widgets/request_url_bar.dart';
import 'widgets/request_body_editor.dart';
import 'widgets/request_auth_editor.dart';
import 'widgets/response_pane.dart';

class RequestEditor extends StatefulWidget {
  const RequestEditor({
    super.key,
    required this.viewModel,
    required this.execution,
    required this.onSave,
  });
  final RequestEditorViewModel viewModel;
  final RequestExecutionViewModel execution;
  final VoidCallback onSave;
  @override
  State<RequestEditor> createState() => _RequestEditorState();
}

class _RequestEditorState extends State<RequestEditor> {
  late final _name = TextEditingController(text: c.request.name);
  late final _url = TextEditingController(text: c.request.url);
  String _tab = 'Params';
  double? _requestHeight;
  RequestEditorViewModel get c => widget.viewModel;
  RequestExecutionViewModel get execution => widget.execution;
  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, execution]),
    builder: (context, _) {
      final r = c.request;
      if (_name.text != r.name) _name.text = r.name;
      final validation = validationMessage(execution.validationFor(r.id));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RequestIdentityBar(
            request: r,
            nameController: _name,
            dirty: c.dirty,
            folders: c.folders,
            onNameChanged: c.setName,
            onFolderChanged: c.setFolder,
            onSave: widget.onSave,
          ),
          RequestUrlBar(
            request: r,
            urlController: _url,
            onMethodChanged: c.setMethod,
            onUrlChanged: c.setUrl,
            onSend: () => execution.send(c.request),
            onCancel: execution.cancel,
            running: execution.running,
            runningId: execution.runningId,
          ),
          if (validation != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 20, 0),
              child: Text(
                validation,
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
                    (_requestHeight ?? (_tab == 'Headers' ? 260.0 : 184.0))
                        .clamp(120.0, maximum);
                Widget table(EntryKind kind, List<Entry> entries) => EntryTable(
                  key: ValueKey('${r.id}-${kind.name}'),
                  entries: entries,
                  onAdd: () => c.addEntry(kind),
                  onUpdate: (id, update) => c.updateEntry(kind, id, update),
                  onDelete: (id) => c.deleteEntry(kind, id),
                  kind: kind == EntryKind.params ? '参数' : 'Header',
                  defaults: kind == EntryKind.headers
                      ? c.defaultHeaders
                      : const [],
                  stickyAdd: kind == EntryKind.headers,
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
                                'Params' => table(EntryKind.params, r.params),
                                'Headers' => table(
                                  EntryKind.headers,
                                  r.headers,
                                ),
                                'Body' => RequestBodyEditor(
                                  request: r,
                                  onChanged: c.setBody,
                                  onTypeChanged: c.setBodyType,
                                ),
                                _ => RequestAuthEditor(
                                  request: r,
                                  onChanged: c.setToken,
                                  onTypeChanged: c.setAuthType,
                                ),
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
                        response: execution.responseFor(r.id),
                        running: execution.runningId == r.id,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    },
  );
}
