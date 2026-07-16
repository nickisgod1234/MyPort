import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/portfolio_models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/portfolio_chart.dart';
import '../../shared/widgets/trial_banner.dart';

class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({super.key, required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final historicalAsync = ref.watch(assetHistoricalProvider(symbol));
    final chartPeriod = ref.watch(chartPeriodProvider);
    final displayName = AppConstants.assetDisplayNames[symbol] ?? symbol;
    final usdThbRate = ref.watch(usdThbRateProvider);

    return Scaffold(
      appBar: AppBar(
        title: summaryAsync.maybeWhen(
          data: (summary) {
            final match = summary.holdings
                .where((h) => h.holding.symbol == symbol)
                .toList();
            final isLive = match.isNotEmpty && match.first.isLive;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(displayName, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                PriceSourceBadge(isLive: isLive, compact: true),
              ],
            );
          },
          orElse: () => Text(displayName),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TrialBanner(pageName: 'รายละเอียดสินทรัพย์'),
          Expanded(
            child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (summary) {
          final matches = summary.holdings
              .where((h) => h.holding.symbol == symbol)
              .toList();

          if (matches.isEmpty) {
            return const Center(child: Text('ไม่พบสินทรัพย์นี้ในพอร์ต'));
          }

          final hv = matches.first;
          final isThaiFund = hv.holding.isThaiFund;
          final isProfit = hv.returnPercent >= 0;
          final profitColor =
              isProfit ? AppColors.profit : AppColors.loss;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StatCard(
                label: 'มูลค่าปัจจุบัน',
                value: formatThbCompact(hv.marketValueThb),
                subtitle: hv.marketValueUsd != null
                    ? formatUsdApprox(hv.marketValueUsd!)
                    : 'กองทุนไทย · อัปเดต NAV',
                valueColor: profitColor,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'กำไร/ขาดทุน',
                      value: formatProfitThb(hv.profitThb),
                      valueColor: profitColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'ผลตอบแทน',
                      value: formatPercent(hv.returnPercent),
                      valueColor: profitColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: isThaiFund ? 'ต้นทุนเฉลี่ย' : 'Average Cost',
                      value: isThaiFund
                          ? formatThbCompact(
                              hv.holding.fixedCostThb ??
                                  hv.holding.shares * hv.holding.averageCost,
                            )
                          : '\$${hv.holding.averageCost.toStringAsFixed(2)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'สัดส่วนพอร์ต',
                      value: formatAllocationPercent(hv.allocation),
                    ),
                  ),
                ],
              ),
              if (!isThaiFund) ...[
                const SizedBox(height: 12),
                StatCard(
                  label: 'Current Price',
                  value: '\$${hv.currentPrice.toStringAsFixed(2)} USD',
                ),
              ],
              const SizedBox(height: 20),
              if (!isThaiFund)
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
                      const SectionHeader(title: 'Chart'),
                      ChartPeriodSelector(
                        selected: chartPeriod,
                        onChanged: (p) =>
                            ref.read(chartPeriodProvider.notifier).state = p,
                      ),
                      const SizedBox(height: 12),
                      historicalAsync.when(
                        loading: () => const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, __) => const Text('ไม่สามารถโหลดกราฟได้'),
                        data: (historical) {
                          final prices = historical
                              .map((e) => (e['close'] as num).toDouble())
                              .toList();
                          return PortfolioChart(data: prices);
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _infoMessage(hv, usdThbRate),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  String _infoMessage(HoldingValue hv, double usdThbRate) {
    if (hv.holding.isThaiFund) {
      return 'กองทุนไทย — ใช้มูลค่า NAV ที่บันทึกไว้ (Mock) อัปเดตเองใน Settings ภายหลัง';
    }
    if (hv.isLive) {
      return 'ราคา Live · แปลงเป็น THB ที่ ${usdThbRate.toStringAsFixed(2)} (FMP หรือ Yahoo Finance)';
    }
    return 'ราคา Mock — ไม่สามารถดึงข้อมูลได้ชั่วคราว';
  }
}
