import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_message.dart';
import '../../domain/entities/request_spec.dart';
import '../formatters/method_style.dart';
import 'history_detail.dart';
import 'view_models/history_view_model.dart';

class HistoryListPanel extends StatelessWidget {
  const HistoryListPanel({super.key, required this.viewModel});
  final HistoryViewModel viewModel;
  HistoryViewModel get c => viewModel;
  bool _matches(RequestSpec request) => c.matches(request);
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: c, builder: (context, _) => _list());
  Widget _list() {
    final records = c.history.where((h) => _matches(h.request)).toList();
    if (records.isEmpty) {
      return EmptyMessage(
        icon: c.history.isEmpty ? Icons.history_rounded : Icons.search_off,
        title: c.history.isEmpty ? '还没有请求历史' : '没有匹配的记录',
        subtitle: c.history.isEmpty ? '发送一次请求后会自动记录' : '试试其他名称或 URL',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final h = records[index];
        final showDate =
            index == 0 ||
            dateLabel(records[index - 1].time) != dateLabel(h.time);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 9),
                child: Text(
                  dateLabel(h.time),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            Material(
              color: c.selectedHistoryId == h.id
                  ? AppColors.selection
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => c.selectHistory(h),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            h.request.method,
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 10,
                              color: methodColor(h.request.method),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              h.request.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        h.request.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Text(
                            clockLabel(h.time),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            h.response.statusCode?.toString() ??
                                (h.response.cancelled ? '已取消' : '失败'),
                            style: TextStyle(
                              fontSize: 10,
                              color: h.response.success
                                  ? AppColors.green
                                  : h.response.cancelled
                                  ? AppColors.muted
                                  : AppColors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
