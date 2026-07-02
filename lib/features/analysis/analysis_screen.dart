import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(portfolioAnalysisProvider);
    final retirement = ref.watch(retirementProjectionProvider);
    final newsAsync = ref.watch(portfolioNewsProvider);

    return AppScaffold(
      title: 'Analysis',
      body: analysisAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (analysis) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(portfolioAnalysisProvider);
              ref.invalidate(portfolioNewsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.2),
                        AppColors.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'คะแนนพอร์ต',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            '${analysis.score}/100',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: AppColors.profit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'เป้าหมายเกษียณ'),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _infoRow('อายุ', '${retirement.currentAge} ปี'),
                      _infoRow('เกษียณ', '${retirement.retirementAge} ปี'),
                      _infoRow(
                        'เงินเป้าหมาย',
                        formatThb(retirement.targetAmount),
                      ),
                      _infoRow(
                        'คาดว่าจะถึง',
                        'ปี ${retirement.projectedYear}',
                        highlight: true,
                      ),
                      const SizedBox(height: 12),
                      GoalProgressCard(
                        progress: retirement.progressPercent,
                        currentAmount: retirement.currentAmount,
                        targetAmount: retirement.targetAmount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Statistics'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    StatCard(
                      label: 'Sharpe',
                      value: analysis.sharpe.toStringAsFixed(2),
                    ),
                    StatCard(
                      label: 'Beta',
                      value: analysis.beta.toStringAsFixed(2),
                    ),
                    StatCard(
                      label: 'Drawdown',
                      value: '${analysis.maxDrawdown.toStringAsFixed(1)}%',
                      valueColor: AppColors.loss,
                    ),
                    StatCard(
                      label: 'Volatility',
                      value: '${analysis.volatility.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'News'),
                newsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('ไม่สามารถโหลดข่าวได้'),
                  data: (news) {
                    if (news.isEmpty) {
                      return const Text('ไม่มีข่าว');
                    }
                    final grouped = <String, List<dynamic>>{};
                    for (final item in news) {
                      grouped.putIfAbsent(item.symbol, () => []).add(item);
                    }
                    return Column(
                      children: grouped.entries.map((entry) {
                        final symbol = entry.key;
                        final items = entry.value;
                        final displayName =
                            AppConstants.assetDisplayNames[symbol] ?? symbol;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$displayName — ${items.length} ข่าว',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...items.take(3).map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• ${item.title}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
