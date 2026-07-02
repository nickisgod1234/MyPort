import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/portfolio_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final marketAsync = ref.watch(marketQuotesProvider);
    final retirement = ref.watch(retirementProjectionProvider);
    final chartPeriod = ref.watch(chartPeriodProvider);

    return AppScaffold(
      title: AppConstants.appName,
      trialPageName: 'Dashboard',
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (summary) {
          final chartData = ref
              .read(portfolioServiceProvider)
              .generateChartData(30, summary.totalValueThb);
          final isProfit = summary.totalReturnPercent >= 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(portfolioSummaryProvider);
              ref.invalidate(marketQuotesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_special_outlined,
                          color: AppColors.accent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        AppConstants.portfolioName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatExchangeRate(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StatCard(
                  label: 'มูลค่าพอร์ตทั้งหมด',
                  value: formatThbCompact(summary.totalValueThb),
                  subtitle:
                      '${formatPercent(summary.totalReturnPercent)} · ${formatUsdApprox(summary.totalValueUsd)}',
                  valueColor: isProfit ? AppColors.profit : AppColors.loss,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'กำไร',
                        value: formatProfitThb(summary.totalProfitThb),
                        valueColor: summary.totalProfitThb >= 0
                            ? AppColors.profit
                            : AppColors.loss,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'ลงทุนสะสม',
                        value: formatThbCompact(summary.totalInvestedThb),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChartPeriodSelector(
                        selected: chartPeriod,
                        onChanged: (p) =>
                            ref.read(chartPeriodProvider.notifier).state = p,
                      ),
                      const SizedBox(height: 12),
                      PortfolioChart(data: chartData),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GoalProgressCard(
                  progress: retirement.progressPercent,
                  currentAmount: summary.totalValueThb,
                  targetAmount: retirement.targetAmount,
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'Portfolio',
                  action: Text(
                    '${summary.holdings.length} สินทรัพย์',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                ...summary.holdings.map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: HoldingCard(
                      holding: h,
                      onTap: () => context.push('/asset/${h.holding.symbol}'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'วันนี้ตลาด'),
                      marketAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (_, __) =>
                            const Text('ไม่สามารถโหลดข้อมูลตลาดได้'),
                        data: (quotes) => Column(
                          children: quotes.map((q) {
                            final label =
                                AppConstants.assetDisplayNames[q.symbol] ??
                                    q.symbol;
                            return MarketRow(
                              label: label,
                              changePercent: q.changesPercentage,
                              isLive: q.isLive,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
