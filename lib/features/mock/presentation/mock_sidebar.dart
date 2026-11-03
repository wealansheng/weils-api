import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/input_dialogs.dart';
import 'view_models/mock_view_model.dart';

class MockSidebar extends StatelessWidget {
  const MockSidebar({super.key, required this.viewModel});
  final MockViewModel viewModel;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 10, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mock 管理',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: const ValueKey('create-mock'),
                  tooltip: '新建 Mock · Ctrl + N',
                  onPressed: viewModel.busy ? null : viewModel.create,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              key: const ValueKey('mock-search'),
              onChanged: viewModel.filter,
              decoration: const InputDecoration(
                hintText: '搜索名称或路径',
                prefixIcon: Icon(Icons.search, size: 17),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: viewModel.definitions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        viewModel.search.isEmpty ? '暂无 Mock 接口' : '未找到匹配的接口',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final d in viewModel.definitions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Material(
                            color: d.id == viewModel.active?.id
                                ? AppColors.selection
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            child: InkWell(
                              onTap: () => viewModel.select(d.id),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 5, 0, 5),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      child: Text(
                                        d.method,
                                        style: TextStyle(
                                          fontFamily: 'Consolas',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: d.enabled
                                              ? AppColors.primary
                                              : AppColors.muted,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${d.name}${viewModel.snapshot.isMockDirty(d) ? ' •' : ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            d.path,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Consolas',
                                              fontSize: 11,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '删除 Mock',
                                      onPressed: viewModel.busy
                                          ? null
                                          : () async {
                                              if (await confirmAction(
                                                context,
                                                title: '删除 Mock 接口？',
                                                detail:
                                                    '将删除“${d.name}”及其草稿。保存成功后，该路由将立即停止提供响应。',
                                                action: '删除',
                                              )) {
                                                await viewModel.delete(d.id);
                                              }
                                            },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '仅已保存且启用的接口参与响应',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}
