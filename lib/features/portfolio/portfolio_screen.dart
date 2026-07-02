import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final watchlistAsync = ref.watch(watchlistQuotesProvider);

    return AppScaffold(
      title: AppConstants.portfolioName,
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (summary) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(portfolioSummaryProvider);
              ref.invalidate(watchlistQuotesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    formatExchangeRate(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'มูลค่าพอร์ต',
                        value: formatThbCompact(summary.totalValueThb),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'กำไรรวม',
                        value: formatPercent(summary.totalReturnPercent),
                        valueColor: summary.totalReturnPercent >= 0
                            ? AppColors.profit
                            : AppColors.loss,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'สินทรัพย์ที่ถือ'),
                ...summary.holdings.map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: HoldingCard(
                      holding: h,
                      onTap: () => context.push('/asset/${h.holding.symbol}'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Watchlist'),
                watchlistAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('ไม่สามารถโหลด Watchlist'),
                  data: (quotes) => Column(
                    children: quotes.map((q) {
                      final isUp = q.changesPercentage >= 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      q.name ?? q.symbol,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PriceSourceBadge(
                                    isLive: q.isLive,
                                    compact: true,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatUsd(q.price),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  formatPercent(q.changesPercentage),
                                  style: TextStyle(
                                    color: isUp
                                        ? AppColors.profit
                                        : AppColors.loss,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
