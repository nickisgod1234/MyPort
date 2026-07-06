import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/withdrawal_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/withdrawal_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class WithdrawalPlannerScreen extends ConsumerWidget {
  const WithdrawalPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final simulation = ref.watch(withdrawalSimulationProvider);
    final settings = ref.watch(withdrawalSettingsProvider);
    final storage = ref.watch(storageServiceProvider);
    final monthlyWithdrawal = settings.initialized
        ? settings.monthlyWithdrawal
        : (simulation?.recommendedMonthly ?? settings.monthlyWithdrawal);

    return AppScaffold(
      title: 'Withdrawal Planner',
      trialPageName: 'เกษียณ',
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (summary) {
          if (simulation == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HeroCard(
                portfolio: summary.totalValueThb,
                age: storage.retirementAge,
                simulation: simulation,
              ),
              const SizedBox(height: 12),
              _MonthlyWithdrawalCard(
                simulation: simulation,
                monthlyWithdrawal: monthlyWithdrawal,
                onChanged: (v) => ref
                    .read(withdrawalSettingsProvider.notifier)
                    .setMonthlyWithdrawal(v),
              ),
              const SizedBox(height: 12),
              _OutcomeCard(
                simulation: simulation,
                monthlyWithdrawal: monthlyWithdrawal,
              ),
              const SizedBox(height: 12),
              _SourceCard(
                simulation: simulation,
                monthly: monthlyWithdrawal,
              ),
              const SizedBox(height: 12),
              _CashReserveCard(
                cashReserve: simulation.cashReserveMonths * monthlyWithdrawal,
                months: simulation.cashReserveMonths,
              ),
              const SizedBox(height: 12),
              _PortfolioChartCard(simulation: simulation),
              const SizedBox(height: 12),
              _PrincipalProfitCard(simulation: simulation),
              const SizedBox(height: 12),
              _UsedRemainingCard(simulation: simulation),
              const SizedBox(height: 12),
              _TimelineCard(simulation: simulation),
              const SizedBox(height: 12),
              _WithdrawalModeCard(
                settings: settings,
                simulation: simulation,
                onModeChanged: (m) =>
                    ref.read(withdrawalSettingsProvider.notifier).setMode(m),
                onRateChanged: (r) => ref
                    .read(withdrawalSettingsProvider.notifier)
                    .setWithdrawalRate(r),
              ),
              const SizedBox(height: 12),
              _MarketCrashCard(
                enabled: settings.simulateMarketCrash,
                simulation: simulation,
                onChanged: (v) => ref
                    .read(withdrawalSettingsProvider.notifier)
                    .setSimulateMarketCrash(v),
              ),
              if (simulation.aiInsight != null) ...[
                const SizedBox(height: 12),
                _AiInsightCard(insight: simulation.aiInsight!),
              ],
              const SizedBox(height: 12),
              _RetireTodayButton(
                simulation: simulation,
                monthlyWithdrawal: monthlyWithdrawal,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.portfolio,
    required this.age,
    required this.simulation,
  });

  final double portfolio;
  final int age;
  final WithdrawalSimulation simulation;

  @override
  Widget build(BuildContext context) {
    final safety = simulation.safety;
    final (label, color) = switch (safety) {
      SafetyLevel.safe => ('🟢 ปลอดภัย', AppColors.profit),
      SafetyLevel.warning => ('⚠ เสี่ยง', AppColors.warning),
      SafetyLevel.critical => ('🔴 อันตราย', AppColors.loss),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.22),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏖️ แผนถอนเงิน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _heroRow('พอร์ตปัจจุบัน', formatThbCompact(portfolio)),
          _heroRow('อายุ', '$age ปี'),
          _heroRow('อยู่ได้ถึง', '${simulation.lastsUntilAge} ปี'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _heroRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}

class _MonthlyWithdrawalCard extends StatelessWidget {
  const _MonthlyWithdrawalCard({
    required this.simulation,
    required this.monthlyWithdrawal,
    required this.onChanged,
  });

  final WithdrawalSimulation simulation;
  final double monthlyWithdrawal;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final rate = simulation.withdrawalRatePercent.clamp(0, 10);
    final progress = rate / 10;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เดือนนี้ถอนเท่าไรดี', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Text('แนะนำ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(
            formatThbCompact(simulation.recommendedMonthly),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.accent),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.accent,
            ),
          ),
          Text(
            '${rate.toStringAsFixed(1)}%',
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Slider(
            value: monthlyWithdrawal.clamp(20000, 80000),
            min: 20000,
            max: 80000,
            divisions: 12,
            label: formatThbCompact(monthlyWithdrawal),
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('20,000', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              Text('80,000', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.simulation,
    required this.monthlyWithdrawal,
  });

  final WithdrawalSimulation simulation;
  final double monthlyWithdrawal;

  @override
  Widget build(BuildContext context) {
    final color = switch (simulation.safety) {
      SafetyLevel.safe => AppColors.profit,
      SafetyLevel.warning => AppColors.warning,
      SafetyLevel.critical => AppColors.loss,
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ถ้าถอนแบบนี้', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('ถอน', style: TextStyle(color: color.withValues(alpha: 0.9))),
          Text(
            formatThbCompact(monthlyWithdrawal),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 8),
          _infoRow('เงินจะอยู่ถึง', '${simulation.lastsUntilAge} ปี'),
          _infoRow('โอกาสสำเร็จ', '${(simulation.successProbability * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 4),
          Text('★' * simulation.starRating + '☆' * (5 - simulation.starRating),
              style: TextStyle(color: color, fontSize: 18)),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.simulation, required this.monthly});

  final WithdrawalSimulation simulation;
  final double monthly;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ถอนจากอะไร', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('เดือนนี้ ${formatThbCompact(monthly)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          const Text('ระบบแนะนำ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ...simulation.sources.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(s.recommended ? '✓' : '❌',
                        style: TextStyle(
                          color: s.recommended ? AppColors.profit : AppColors.loss,
                        )),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.name)),
                    if (s.recommended)
                      Text(formatThbCompact(s.amount),
                          style: const TextStyle(fontWeight: FontWeight.w600))
                    else
                      const Text('ไม่แนะนำขาย',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          const Text('เพราะยังเป็นสินทรัพย์เติบโต',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _CashReserveCard extends StatelessWidget {
  const _CashReserveCard({required this.cashReserve, required this.months});

  final double cashReserve;
  final double months;

  @override
  Widget build(BuildContext context) {
    final isLow = months < 6;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เงินสดสำรอง', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(formatThbCompact(cashReserve),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _infoRow('ใช้ได้', '${months.toStringAsFixed(0)} เดือน'),
          const SizedBox(height: 4),
          Text(
            isLow ? '⚠ เติมเงินสด' : '🟢 เพียงพอ',
            style: TextStyle(
              color: isLow ? AppColors.warning : AppColors.profit,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioChartCard extends StatelessWidget {
  const _PortfolioChartCard({required this.simulation});

  final WithdrawalSimulation simulation;

  @override
  Widget build(BuildContext context) {
    final points = simulation.chartPoints;
    if (points.length < 2) return const SizedBox.shrink();

    final portfolioSpots = points
        .map((p) => FlSpot(p.age.toDouble(), p.portfolio / 1e6))
        .toList();
    final withdrawalSpots = points
        .map((p) => FlSpot(p.age.toDouble(), p.cumulativeWithdrawal / 1e6))
        .toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('กราฟมูลค่าพอร์ต', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Row(
            children: [
              _LegendDot(AppColors.accent, 'มูลค่าพอร์ต'),
              SizedBox(width: 12),
              _LegendDot(AppColors.loss, 'ถอนสะสม'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}M',
                        style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: portfolioSpots,
                    isCurved: true,
                    color: AppColors.accent,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: withdrawalSpots,
                    isCurved: true,
                    color: AppColors.loss,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _PrincipalProfitCard extends StatelessWidget {
  const _PrincipalProfitCard({required this.simulation});

  final WithdrawalSimulation simulation;

  @override
  Widget build(BuildContext context) {
    final total = simulation.principal + simulation.profit;
    final principalPct = (total > 0 ? simulation.principal / total : 0).toDouble();
    final profitPct = (total > 0 ? simulation.profit / total : 0).toDouble();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เงินต้น vs กำไร', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('พอร์ต ${(total / 1e6).toStringAsFixed(1)} ล้าน',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const Divider(color: AppColors.border),
          _barRow('เงินต้น', simulation.principal, principalPct, AppColors.textSecondary),
          const SizedBox(height: 8),
          _barRow('กำไร', simulation.profit, profitPct, AppColors.profit),
        ],
      ),
    );
  }

  Widget _barRow(String label, double amount, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${formatThbCompact(amount)} (${(pct * 100).toStringAsFixed(0)}%)'),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: AppColors.border,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _UsedRemainingCard extends StatelessWidget {
  const _UsedRemainingCard({required this.simulation});

  final WithdrawalSimulation simulation;

  @override
  Widget build(BuildContext context) {
    final total = simulation.principal + simulation.profit;
    final usedPct = (total > 0 ? simulation.totalWithdrawn / total : 0.0).toDouble();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เงินที่ใช้ไปแล้ว', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('ใช้ไปแล้ว ${formatThbCompact(simulation.totalWithdrawn)}'),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedPct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 8),
          Text('เหลือ ${formatThbCompact(simulation.remaining)}'),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.simulation});

  final WithdrawalSimulation simulation;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...simulation.timeline.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ปี ${e.age}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (e.event != null)
                      Text(e.event!, style: const TextStyle(color: AppColors.warning, fontSize: 12))
                    else ...[
                      Text('ถอน ${formatThbCompact(e.withdrawal)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('เหลือ ${formatThbCompact(e.balance)}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                    const Divider(color: AppColors.border, height: 12),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _WithdrawalModeCard extends StatelessWidget {
  const _WithdrawalModeCard({
    required this.settings,
    required this.simulation,
    required this.onModeChanged,
    required this.onRateChanged,
  });

  final WithdrawalSettings settings;
  final WithdrawalSimulation simulation;
  final ValueChanged<WithdrawalMode> onModeChanged;
  final ValueChanged<double> onRateChanged;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ปรับวิธีถอน', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...WithdrawalMode.values.map((mode) {
            return RadioListTile<WithdrawalMode>(
              value: mode,
              groupValue: settings.mode,
              onChanged: (v) {
                if (v != null) onModeChanged(v);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_modeLabel(mode), style: const TextStyle(fontSize: 14)),
            );
          }),
          if (settings.mode == WithdrawalMode.percentage) ...[
            Text('ถอน ${(settings.withdrawalRate * 100).toStringAsFixed(0)}% ทุกปี'),
            Slider(
              value: settings.withdrawalRate,
              min: 0.02,
              max: 0.08,
              divisions: 6,
              label: '${(settings.withdrawalRate * 100).toStringAsFixed(1)}%',
              onChanged: onRateChanged,
            ),
          ],
          if (settings.mode == WithdrawalMode.fixed)
            Text('ถอนคงที่ ${formatThbCompact(settings.monthlyWithdrawal)} ทุกเดือน',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (settings.mode == WithdrawalMode.profitOnly) ...[
            Text('กำไรปีนี้ ${formatThbCompact(simulation.annualProfitEstimate)}',
                style: const TextStyle(fontSize: 12)),
            Text('ถอนได้สูงสุด ~${formatThbCompact(simulation.annualProfitEstimate)} / ปี',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Text('เงินต้นไม่แตะ', style: TextStyle(color: AppColors.profit, fontSize: 12)),
          ],
          if (settings.mode == WithdrawalMode.dividendOnly)
            const Text('เหมาะกับ SCHD / JEPI / JEPQ',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  String _modeLabel(WithdrawalMode mode) => switch (mode) {
        WithdrawalMode.percentage => 'ถอน %',
        WithdrawalMode.fixed => 'ถอนคงที่',
        WithdrawalMode.profitOnly => 'ถอนเฉพาะกำไร',
        WithdrawalMode.dividendOnly => 'ถอนเฉพาะปันผล',
      };
}

class _MarketCrashCard extends StatelessWidget {
  const _MarketCrashCard({
    required this.enabled,
    required this.simulation,
    required this.onChanged,
  });

  final bool enabled;
  final WithdrawalSimulation simulation;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('ถ้าตลาดตก', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
          const Text('ตลาดลง 20%', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            enabled
                ? 'อยู่ถึง ${simulation.lastsUntilAge} ปี'
                : 'เปิดเพื่อจำลองวิกฤติ',
            style: TextStyle(
              color: simulation.safety == SafetyLevel.critical
                  ? AppColors.loss
                  : AppColors.profit,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.insight});

  final String insight;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(insight, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _RetireTodayButton extends StatelessWidget {
  const _RetireTodayButton({
    required this.simulation,
    required this.monthlyWithdrawal,
  });

  final WithdrawalSimulation simulation;
  final double monthlyWithdrawal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Text('🏖 หากคุณเกษียณวันนี้',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('ถอน ${formatThbCompact(monthlyWithdrawal)}/เดือน',
              style: const TextStyle(color: AppColors.textSecondary)),
          Text('เงินจะอยู่ถึงอายุ ${simulation.lastsUntilAge} ปี',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (simulation.successProbability).clamp(0, 1),
              minHeight: 10,
              backgroundColor: AppColors.border,
              color: AppColors.profit,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            simulation.safety == SafetyLevel.safe ? 'ปลอดภัย' : 'เสี่ยง',
            style: TextStyle(
              color: simulation.safety == SafetyLevel.safe
                  ? AppColors.profit
                  : AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text('★' * simulation.starRating + '☆' * (5 - simulation.starRating),
              style: const TextStyle(color: AppColors.warning, fontSize: 16)),
        ],
      ),
    );
  }
}

Widget _card({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    ),
  );
}
