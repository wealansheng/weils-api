import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/anchored_select.dart';
import '../../../shared/widgets/input_dialogs.dart';
import '../../../shared/widgets/section_tabs.dart';
import '../domain/entities/mock_definition.dart';
import '../domain/use_cases/generate_mock.dart';
import 'view_models/mock_view_model.dart';
import 'widgets/mock_field_builder.dart';
import 'widgets/mock_input.dart';

class MockWorkspace extends StatefulWidget {
  const MockWorkspace({super.key, required this.viewModel});
  final MockViewModel viewModel;
  @override
  State<MockWorkspace> createState() => _MockWorkspaceState();
}

class _MockWorkspaceState extends State<MockWorkspace> {
  late String _port = '${widget.viewModel.snapshot.mockPort}';
  String? _selectedScenario;
  MockViewModel get vm => widget.viewModel;
  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );
  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast('已复制');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final definition = vm.active;
      final scenario =
          definition?.scenarios
              .where((s) => s.id == _selectedScenario)
              .firstOrNull ??
          definition?.scenarios.firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: MockInput(
                    key: const ValueKey('mock-port'),
                    value: _port,
                    label: '端口',
                    enabled: !vm.running && !vm.busy,
                    onChanged: (v) => _port = v,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const ValueKey('toggle-mock-server'),
                  onPressed: vm.busy ? null : () => vm.toggle(_port),
                  icon: Icon(
                    vm.running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 17,
                  ),
                  label: Text(
                    vm.busy
                        ? '处理中…'
                        : vm.running
                        ? '停止服务'
                        : '启动服务',
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.circle,
                  size: 7,
                  color: vm.running ? AppColors.green : AppColors.muted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    vm.running ? vm.address : '未启动 · 仅本机访问',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: vm.running ? AppColors.green : AppColors.muted,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '复制服务地址',
                  onPressed: vm.running ? () => _copy(vm.address) : null,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                ),
              ],
            ),
          ),
          if (vm.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                vm.error!,
                key: const ValueKey('mock-error'),
                style: const TextStyle(fontSize: 12, color: AppColors.red),
              ),
            ),
          if (definition == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.dns_outlined,
                      size: 35,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      '创建本地 Mock 接口',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '配置路径与响应，为本机前端提供模拟数据',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: vm.create,
                      child: const Text('新建 Mock 接口'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: MockInput(
                      key: ValueKey('mock-name-${definition.id}'),
                      value: definition.name,
                      label: '接口名称',
                      onChanged: (v) => vm.update((d) => d.copyWith(name: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Checkbox(
                    value: definition.enabled,
                    onChanged: (v) => vm.update((d) => d.copyWith(enabled: v)),
                  ),
                  const Text('启用', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    key: const ValueKey('save-mock'),
                    onPressed: vm.busy
                        ? null
                        : () async {
                            if (await vm.save() && mounted) {
                              _toast('Mock 已保存并生效');
                            }
                          },
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: Text(
                      vm.snapshot.isMockDirty(definition) ? '保存 •' : '已保存',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  AnchoredSelect(
                    id: 'mock-method',
                    label: 'HTTP 方法',
                    value: definition.method,
                    width: 108,
                    height: 44,
                    monospace: true,
                    options: [
                      for (final method in ['GET', 'POST', 'PUT', 'DELETE'])
                        SelectOption(method, method),
                    ],
                    onChanged: (v) => vm.update((d) => d.copyWith(method: v)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MockInput(
                      key: ValueKey('mock-path-${definition.id}'),
                      value: definition.path,
                      label: '路径',
                      hint: '/users/:id',
                      monospace: true,
                      onChanged: (v) => vm.update((d) => d.copyWith(path: v)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  const Text('响应场景', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  if (scenario != null)
                    AnchoredSelect(
                      id: 'mock-scenario',
                      label: '响应场景',
                      value: scenario.id,
                      width: 200,
                      options: [
                        for (final s in definition.scenarios)
                          SelectOption(
                            s.id,
                            '${s.name}${s.isDefault ? '（默认）' : ''}',
                          ),
                      ],
                      onChanged: (v) => setState(() => _selectedScenario = v),
                    ),
                  IconButton(
                    tooltip: '场景上移',
                    onPressed:
                        scenario == null ||
                            definition.scenarios.indexOf(scenario) == 0
                        ? null
                        : () {
                            final items = [...definition.scenarios];
                            final index = items.indexOf(scenario);
                            items.removeAt(index);
                            items.insert(index - 1, scenario);
                            vm.update((d) => d.copyWith(scenarios: items));
                          },
                    icon: const Icon(Icons.arrow_upward, size: 16),
                  ),
                  IconButton(
                    tooltip: '场景下移',
                    onPressed:
                        scenario == null ||
                            definition.scenarios.indexOf(scenario) ==
                                definition.scenarios.length - 1
                        ? null
                        : () {
                            final items = [...definition.scenarios];
                            final index = items.indexOf(scenario);
                            items.removeAt(index);
                            items.insert(index + 1, scenario);
                            vm.update((d) => d.copyWith(scenarios: items));
                          },
                    icon: const Icon(Icons.arrow_downward, size: 16),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const ValueKey('add-mock-scenario'),
                    onPressed: () {
                      final added = MockScenario(
                        name: '场景 ${definition.scenarios.length + 1}',
                        conditions: [const MockCondition()],
                      );
                      vm.update(
                        (d) => d.copyWith(scenarios: [...d.scenarios, added]),
                      );
                      setState(() => _selectedScenario = added.id);
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加场景'),
                  ),
                  IconButton(
                    tooltip: '删除场景',
                    onPressed:
                        definition.scenarios.length < 2 || scenario == null
                        ? null
                        : () async {
                            if (await confirmAction(
                              context,
                              title: '删除响应场景？',
                              detail: '将删除“${scenario.name}”的条件与响应，保存接口后生效。',
                              action: '删除',
                            )) {
                              vm.update(
                                (d) => d.copyWith(
                                  scenarios: d.scenarios
                                      .where((s) => s.id != scenario.id)
                                      .toList(),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_outline, size: 16),
                  ),
                ],
              ),
            ),
            if (scenario != null)
              Expanded(
                child: _ScenarioEditor(
                  key: ValueKey(scenario.id),
                  scenario: scenario,
                  onChanged: (change) => vm.updateScenario(scenario.id, change),
                ),
              ),
          ],
        ],
      );
    },
  );
}

class _ScenarioEditor extends StatefulWidget {
  const _ScenarioEditor({
    super.key,
    required this.scenario,
    required this.onChanged,
  });
  final MockScenario scenario;
  final void Function(MockScenario Function(MockScenario)) onChanged;
  @override
  State<_ScenarioEditor> createState() => _ScenarioEditorState();
}

class _ScenarioEditorState extends State<_ScenarioEditor> {
  String _tab = '响应正文', _preview = '';
  String? _error;
  MockScenario get s => widget.scenario;
  void _previewBody() {
    try {
      setState(() {
        _preview = s.bodyType == 'json'
            ? MockGenerator().generate(s.body)
            : s.body;
        _error = null;
      });
    } on Object catch (e) {
      setState(() {
        _error = e.toString();
        _preview = '';
      });
    }
  }

  @override
  void didUpdateWidget(_ScenarioEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (s.body != oldWidget.scenario.body ||
        s.bodyType != oldWidget.scenario.bodyType) {
      _preview = '';
      _error = null;
    }
  }

  Future<void> _fields() async {
    final template = await openMockFieldBuilder(context);
    if (template == null || !mounted) return;
    if (s.body.trim().isNotEmpty &&
        !await confirmAction(
          context,
          title: '替换响应模板？',
          detail: '字段表生成的模板将替换当前响应正文。',
          action: '替换模板',
        )) {
      return;
    }
    if (mounted) {
      widget.onChanged((s) => s.copyWith(body: template, bodyType: 'json'));
    }
  }

  void _condition(int index, MockCondition Function(MockCondition) update) =>
      widget.onChanged(
        (s) => s.copyWith(
          conditions: [
            for (var i = 0; i < s.conditions.length; i++)
              i == index ? update(s.conditions[i]) : s.conditions[i],
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MockInput(
                value: s.name,
                label: '场景名称',
                onChanged: (v) => widget.onChanged((s) => s.copyWith(name: v)),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: MockInput(
                value: '${s.statusCode}',
                label: '状态码',
                onChanged: (v) => widget.onChanged(
                  (s) => s.copyWith(statusCode: int.tryParse(v) ?? 0),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 125,
              child: MockInput(
                value: '${s.delayMs}',
                label: '延迟（毫秒）',
                onChanged: (v) => widget.onChanged(
                  (s) => s.copyWith(delayMs: int.tryParse(v) ?? -1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SectionTabs(
          tabs: const ['响应正文', '匹配条件', '响应 Headers'],
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_tab) {
            '匹配条件' => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '条件全部满足时命中；按场景顺序选择，无条件的默认响应最后匹配。',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: s.conditions.isEmpty
                      ? const Center(
                          child: Text(
                            '默认响应 · 无需匹配条件',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : ListView(
                          children: [
                            for (var i = 0; i < s.conditions.length; i++)
                              Padding(
                                key: ValueKey('${s.id}-$i'),
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnchoredSelect(
                                      id: 'mock-condition-$i',
                                      label: '条件来源',
                                      value: s.conditions[i].source.name,
                                      width: 124,
                                      height: 44,
                                      options: const [
                                        SelectOption('header', 'Header'),
                                        SelectOption('body', 'JSON Body'),
                                      ],
                                      onChanged: (v) => _condition(
                                        i,
                                        (c) => c.copyWith(
                                          source: MockConditionSource.values
                                              .byName(v),
                                          key: '',
                                          expected: v == 'body' ? 'null' : '',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: MockInput(
                                        value: s.conditions[i].key,
                                        label:
                                            s.conditions[i].source ==
                                                MockConditionSource.header
                                            ? 'Header 名称'
                                            : 'JSON Pointer',
                                        hint:
                                            s.conditions[i].source ==
                                                MockConditionSource.header
                                            ? 'X-Role'
                                            : '/user/id',
                                        onChanged: (v) => _condition(
                                          i,
                                          (c) => c.copyWith(key: v),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: MockInput(
                                        value: s.conditions[i].expected,
                                        label:
                                            s.conditions[i].source ==
                                                MockConditionSource.header
                                            ? '等于（文本）'
                                            : '等于（JSON 值）',
                                        hint:
                                            s.conditions[i].source ==
                                                MockConditionSource.header
                                            ? 'admin'
                                            : '"admin" 或 1',
                                        onChanged: (v) => _condition(
                                          i,
                                          (c) => c.copyWith(expected: v),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '删除条件',
                                      onPressed: () => widget.onChanged(
                                        (s) => s.copyWith(
                                          conditions: [...s.conditions]
                                            ..removeAt(i),
                                        ),
                                      ),
                                      icon: const Icon(Icons.close, size: 16),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('add-mock-condition'),
                    onPressed: () => widget.onChanged(
                      (s) => s.copyWith(
                        conditions: [...s.conditions, const MockCondition()],
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加等值条件'),
                  ),
                ),
              ],
            ),
            '响应 Headers' => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '填写 JSON 对象，例如 {"X-Mock": "true"}。Content-Length、连接及 CORS 响应头由服务管理。',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: MockInput(
                    value: s.headersText,
                    label: '响应 Headers（JSON）',
                    monospace: true,
                    expand: true,
                    onChanged: (v) =>
                        widget.onChanged((s) => s.copyWith(headersText: v)),
                  ),
                ),
              ],
            ),
            _ => Column(
              children: [
                Row(
                  children: [
                    AnchoredSelect(
                      id: 'mock-body-type',
                      label: '正文类型',
                      value: s.bodyType,
                      width: 124,
                      options: const [
                        SelectOption('json', 'JSON 模板'),
                        SelectOption('text', '文本'),
                      ],
                      onChanged: (v) =>
                          widget.onChanged((s) => s.copyWith(bodyType: v)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const ValueKey('mock-field-builder'),
                      onPressed: _fields,
                      child: const Text('字段表生成'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const _TemplateHelp(),
                      ),
                      child: const Text('模板语法'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('preview-mock'),
                      onPressed: _previewBody,
                      child: Text(_preview.isEmpty ? '生成预览' : '重新生成'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 3,
                  child: MockInput(
                    key: const ValueKey('mock-body'),
                    value: s.body,
                    label: s.bodyType == 'json' ? '响应 JSON 模板' : '响应文本',
                    expand: true,
                    monospace: true,
                    onChanged: (v) =>
                        widget.onChanged((s) => s.copyWith(body: v)),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  ),
                if (_preview.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text(
                        '生成预览',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '复制生成结果',
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: _preview)),
                        icon: const Icon(Icons.copy_outlined, size: 15),
                      ),
                    ],
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      key: const ValueKey('mock-preview'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: AppColors.shell,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _preview.length > 200000
                              ? '${_preview.substring(0, 200000)}\n…预览已截断，复制可获取完整内容'
                              : _preview,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          },
        ),
      ],
    ),
  );
}

class _TemplateHelp extends StatelessWidget {
  const _TemplateHelp();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('JSON 模板语法'),
    content: const SizedBox(
      width: 590,
      height: 380,
      child: SingleChildScrollView(
        child: SelectableText(
          '使用合法 JSON，生成规则写在字段名的 | 后。\n\n'
          '{\n  "users|5-5": [{\n    "id|+1": 1,\n    "name": "@cname",\n    "age": "@integer(18, 60)",\n    "email": "@email",\n    "role": "@pick([\\"admin\\", \\"user\\"])"\n  }]\n}\n\n'
          '常用占位符：@integer(min,max)、@natural(min,max)、@float(min,max,dmin,dmax)、@boolean、@string、@name、@cname、@email、@guid、@date、@time、@datetime、@pick([…])。\n\n'
          '完整占位符保留类型，嵌入文本则转换为字符串。数组 |1 抽取一个元素；|1-1 生成单项数组。支持字符串重复、数字范围、小数位数、递增、布尔概率与对象属性抽取。\n\n'
          '每次请求或预览独立生成，递增在本次生成内累计。深度最多 32 层、数组最多 1000 项、生成正文最多 2 MB。不支持 JavaScript、函数、正则生成、字段引用或其他占位符。普通文本中的 @单词 也会识别为占位符。',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('知道了'),
      ),
    ],
  );
}
