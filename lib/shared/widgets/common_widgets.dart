import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'trial_banner.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/portfolio_models.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({
    super.key,
    required this.progress,
    required this.currentAmount,
    required this.targetAmount,
  });

  final double progress;
  final double currentAmount;
  final double targetAmount;

  @override
  Widget build(BuildContext context) {
    final pct = (progress / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎯', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'เป้าหมาย',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: AppColors.border,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
              Text(
                '${(currentAmount / 1000000).toStringAsFixed(1)} / ${(targetAmount / 1000000).toStringAsFixed(0)} ล้านบาท',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PriceSourceBadge extends StatelessWidget {
  const PriceSourceBadge({
    super.key,
    required this.isLive,
    this.compact = false,
  });

  final bool isLive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isLive ? AppColors.profit : AppColors.warning;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            isLive ? 'Live' : 'Mock',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class HoldingCard extends StatelessWidget {
  const HoldingCard({
    super.key,
    required this.holding,
    required this.onTap,
  });

  final HoldingValue holding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final symbol = holding.holding.symbol;
    final colorValue = AppColors.surfaceElevated;
    final accentColor = Color(
      AppConstants.assetColors[symbol] ?? 0xFF2962FF,
    );
    final displayName = AppConstants.assetDisplayNames[symbol] ??
        holding.holding.displayName ??
        symbol;
    final isProfit = holding.returnPercent >= 0;
    final isNeutral = holding.returnPercent.abs() < 0.005;
    final profitColor = isNeutral
        ? AppColors.textSecondary
        : (isProfit ? AppColors.profit : AppColors.loss);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorValue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  displayName.substring(0, 1),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PriceSourceBadge(
                        isLive: holding.isLive,
                        compact: true,
                      ),
                    ],
                  ),
                  Text(
                    formatAllocationPercent(holding.allocation),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatThbCompact(holding.marketValueThb),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (holding.marketValueUsd != null)
                  Text(
                    formatUsdApprox(holding.marketValueUsd!),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${formatPercent(holding.returnPercent)} (${formatProfitThb(holding.profitThb)})',
                  style: TextStyle(
                    color: profitColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MarketRow extends StatelessWidget {
  const MarketRow({
    super.key,
    required this.label,
    required this.changePercent,
    this.isLive = false,
  });

  final String label;
  final double changePercent;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final isUp = changePercent >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                PriceSourceBadge(isLive: isLive, compact: true),
              ],
            ),
          ),
          Text(
            formatPercent(changePercent),
            style: TextStyle(
              color: isUp ? AppColors.profit : AppColors.loss,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.trialPageName,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final String? trialPageName;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (trialPageName != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrialBanner(pageName: trialPageName!),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: content,
    );
  }
}
