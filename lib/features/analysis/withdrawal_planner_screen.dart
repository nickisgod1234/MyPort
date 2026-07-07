import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/withdrawal_models.dart';
import '../../data/models/real_withdrawal_models.dart';
import '../../data/services/real_withdrawal_service.dart';
import '../../data/services/withdrawal_simulator.dart';
import '../../providers/app_providers.dart';
import '../../providers/withdrawal_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class WithdrawalPlannerScreen extends ConsumerWidget {
  const WithdrawalPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final simulation = ref.watch(withdrawalSimulationProvider);
    final real = ref.watch(realWithdrawalSnapshotProvider);
    final settings = ref.watch(withdrawalSettingsProvider);
    final storage = ref.watch(storageServiceProvider);
    final monthlyWithdrawal = settings.initialized
        ? settings.monthlyWithdrawal
        : (real != null
            ? WithdrawalSimulator.modeDefaultMonthly(
                real.portfolioValue,
                settings.mode,
                real: real,
              )
            : simulation?.recommendedMonthly ?? settings.monthlyWithdrawal);
    final realMonthly = real != null
        ? RealWithdrawalService.effectiveMonthly(
            real,
            settings.mode,
            monthlyWithdrawal,
          )
        : monthlyWithdrawal;
    final simMonthly = simulation != null
        ? simulation.projectedFirstYearWithdrawal / 12
        : realMonthly;

    return AppScaffold(
      title: 'แผนเกษียณ',
      trialPageName: 'เกษียณ',
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (summary) {
          if (simulation == null || real == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HeroCard(real: real, age: storage.retirementAge),
              const SizedBox(height: 12),
              _RealPortfolioCard(real: real),
              const SizedBox(height: 12),
              _MonthlyWithdrawalCard(
                settings: settings,
                real: real,
                portfolio: summary.totalValueThb,
                monthlyWithdrawal: monthlyWithdrawal,
                effectiveMonthly: realMonthly,
                onChanged: (v) => ref
                    .read(withdrawalSettingsProvider.notifier)
                    .setMonthlyWithdrawal(
                      v,
                      portfolio: summary.totalValueThb,
                      real: real,
                    ),
                onModeChanged: (m) => ref
                    .read(withdrawalSettingsProvider.notifier)
                    .setMode(
                      m,
                      portfolio: summary.totalValueThb,
                      real: real,
                    ),
              ),
              const SizedBox(height: 12),
              _RealWithdrawalTodayCard(
                settings: settings,
                real: real,
                targetMonthly: monthlyWithdrawal,
                effectiveMonthly: realMonthly,
              ),
              if (settings.mode == WithdrawalMode.percentage ||
                  settings.mode == WithdrawalMode.fixed) ...[
                const SizedBox(height: 12),
                _DcaWithdrawalSplitCard(
                  real: real,
                  monthlyTotal: realMonthly,
                ),
              ],
              const SizedBox(height: 12),
              _SimulationSection(
                expanded: settings.simulationExpanded,
                onExpansionChanged: (v) => ref
                    .read(withdrawalSettingsProvider.notifier)
                    .setSimulationExpanded(v),
                simulation: simulation,
                settings: settings,
                effectiveMonthly: simMonthly,
                monthlyWithdrawal: monthlyWithdrawal,
                enabledCrash: settings.simulateMarketCrash,
                onCrashChanged: (v) => ref
                    .read(withdrawalSettingsProvider.notifier)
                    .setSimulateMarketCrash(v),
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
    required this.real,
    required this.age,
  });

  final RealWithdrawalSnapshot real;
  final int age;

  @override
  Widget build(BuildContext context) {
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
          const Text('🏖️ แผนเกษียณ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'ข้อมูลจากพอร์ต DCA จริง',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _heroRow('พอร์ตรวม', formatThbCompact(real.portfolioValue)),
          _heroRow('ทุนจริง', formatThbCompact(real.principal)),
          _heroRow('กำไรสะสม', formatThbCompact(real.profit)),
          _heroRow('ผลตอบแทน', '${real.returnPercent.toStringAsFixed(1)}%'),
          _heroRow('อายุเป้าเกษียณ', '$age ปี'),
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

class _RealPortfolioCard extends StatelessWidget {
  const _RealPortfolioCard({required this.real});

  final RealWithdrawalSnapshot real;

  @override
  Widget build(BuildContext context) {
    final withDelta = real.assets.where((a) => a.profitThb.abs() >= 0.01).toList()
      ..sort((a, b) => b.profitThb.compareTo(a.profitThb));

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('พอร์ตจริงรายสินทรัพย์', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'มูลค่าและกำไรจากหน้า DCA',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          if (!real.hasProfit) ...[
            const SizedBox(height: 10),
            Text(
              real.hasCostBasis
                  ? 'กำไรรวม ${formatThbCompact(real.profit)} — ยังไม่มีกำไรถอนได้'
                  : 'ยังไม่มีข้อมูลทุน (คอลัมน์ก่อนหน้าใน DCA) — กำไรจะขึ้นหลังบันทึกมูลค่าใหม่ที่สูงกว่าเดิม',
              style: const TextStyle(fontSize: 12, color: AppColors.warning, height: 1.4),
            ),
          ],
          if (withDelta.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...withDelta.take(5).map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(a.name, style: const TextStyle(fontSize: 13))),
                      Text(
                        formatThbCompact(a.valueThb),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${a.profitThb >= 0 ? '+' : ''}${formatThbCompact(a.profitThb)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: a.profitThb >= 0 ? AppColors.profit : AppColors.loss,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (real.annualDividendEstimate > 0) ...[
            const Divider(color: AppColors.border, height: 16),
            _infoRow(
              'ปันผลประมาณ/ปี',
              formatThbCompact(real.annualDividendEstimate),
            ),
          ],
        ],
      ),
    );
  }
}

class _RealWithdrawalTodayCard extends StatelessWidget {
  const _RealWithdrawalTodayCard({
    required this.settings,
    required this.real,
    required this.targetMonthly,
    required this.effectiveMonthly,
  });

  final WithdrawalSettings settings;
  final RealWithdrawalSnapshot real;
  final double targetMonthly;
  final double effectiveMonthly;

  @override
  Widget build(BuildContext context) {
    final capped = targetMonthly > effectiveMonthly + 500;
    final noProfit = settings.mode == WithdrawalMode.profitOnly && !real.hasProfit;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('วันนี้ถอนได้ (จริง)', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.profit.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _withdrawalModeLabel(settings.mode),
                  style: const TextStyle(fontSize: 11, color: AppColors.profit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (noProfit) ...[
            const Text(
              'ยังถอนไม่ได้',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              real.hasCostBasis
                  ? 'กำไรสะสม ${formatThbCompact(real.profit)} — มูลค่ายังไม่เกินทุนที่บันทึกไว้'
                  : 'ยังไม่มีข้อมูลทุน — ระบบยังไม่รู้ว่าลงทุนไปเท่าไร',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'วิธีให้มีตัวเลข:\n'
              '1. ไปหน้า DCA บันทึกมูลค่าปัจจุบัน\n'
              '2. เมื่อพอร์ตโต ให้แก้มูลค่าให้สูงขึ้นแล้วกด ✓ บันทึก\n'
              '3. ค่าเดิมจะกลายเป็น "ทุน" ส่วนต่างคือกำไร',
              style: TextStyle(fontSize: 11, color: AppColors.warning, height: 1.45),
            ),
          ] else ...[
            Text(
              formatThbCompact(effectiveMonthly),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.profit),
            ),
            const Text('/ เดือน (รวมทั้งพอร์ต)', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (settings.mode == WithdrawalMode.percentage ||
                settings.mode == WithdrawalMode.fixed)
              Text(
                '≈ ${RealWithdrawalService.annualWithdrawalRatePercent(real, effectiveMonthly).toStringAsFixed(1)}% ของพอร์ต/ปี · แบ่งถอนตามเป้า DCA ในการ์ดถัดไป',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
              ),
            if (settings.mode == WithdrawalMode.profitOnly)
              Text(
                'จากกำไรสะสม ${formatThbCompact(real.profit)} (สูงสุด ${formatThbCompact(real.profitOnlyMaxMonthly)}/เดือน)',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            if (settings.mode == WithdrawalMode.dividendOnly)
              Text(
                'จากปันผลประมาณ ${formatThbCompact(real.annualDividendEstimate)}/ปี',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            if (capped)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'เป้า ${formatThbCompact(targetMonthly)} สูงกว่าที่ถอนได้จริง — ถูกจำกัดตามโหมด',
                  style: const TextStyle(fontSize: 11, color: AppColors.warning),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'ทุนจริงไม่ถูกแตะ หากถอนไม่เกินกำไรสะสม',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _DcaWithdrawalSplitCard extends StatelessWidget {
  const _DcaWithdrawalSplitCard({
    required this.real,
    required this.monthlyTotal,
  });

  final RealWithdrawalSnapshot real;
  final double monthlyTotal;

  @override
  Widget build(BuildContext context) {
    final lines = RealWithdrawalService.splitByDcaTarget(real, monthlyTotal);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('แบ่งถอนตามเป้า DCA', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'รวม ${formatThbCompact(monthlyTotal)}/เดือน แบ่งตามสัดส่วนเป้าในหน้า DCA',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${(line.targetPercent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(line.name, style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    formatThbCompact(line.monthlyAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
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

class _SimulationSection extends StatelessWidget {
  const _SimulationSection({
    required this.expanded,
    required this.onExpansionChanged,
    required this.simulation,
    required this.settings,
    required this.effectiveMonthly,
    required this.monthlyWithdrawal,
    required this.enabledCrash,
    required this.onCrashChanged,
  });

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final WithdrawalSimulation simulation;
  final WithdrawalSettings settings;
  final double effectiveMonthly;
  final double monthlyWithdrawal;
  final bool enabledCrash;
  final ValueChanged<bool> onCrashChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: const Text('จำลองอนาคตหลังเกษียณ', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text(
            'สมมติผลตอบแทน 7%/ปี — ไม่ใช่ข้อมูลจริง',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _OutcomeCard(
                    settings: settings,
                    simulation: simulation,
                    effectiveMonthly: effectiveMonthly,
                  ),
                  const SizedBox(height: 12),
                  _SourceCard(simulation: simulation, monthly: monthlyWithdrawal),
                  const SizedBox(height: 12),
                  _CashReserveCard(
                    cashReserve: simulation.cashReserveMonths * monthlyWithdrawal,
                    months: simulation.cashReserveMonths,
                  ),
                  const SizedBox(height: 12),
                  _PortfolioChartCard(simulation: simulation),
                  const SizedBox(height: 12),
                  _UsedRemainingCard(simulation: simulation),
                  const SizedBox(height: 12),
                  _TimelineCard(simulation: simulation),
                  const SizedBox(height: 12),
                  _MarketCrashCard(
                    enabled: enabledCrash,
                    simulation: simulation,
                    onChanged: onCrashChanged,
                  ),
                  if (simulation.aiInsight != null) ...[
                    const SizedBox(height: 12),
                    _AiInsightCard(insight: simulation.aiInsight!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyWithdrawalCard extends StatelessWidget {
  const _MonthlyWithdrawalCard({
    required this.settings,
    required this.real,
    required this.portfolio,
    required this.monthlyWithdrawal,
    required this.effectiveMonthly,
    required this.onChanged,
    required this.onModeChanged,
  });

  final WithdrawalSettings settings;
  final RealWithdrawalSnapshot real;
  final double portfolio;
  final double monthlyWithdrawal;
  final double effectiveMonthly;
  final ValueChanged<double> onChanged;
  final ValueChanged<WithdrawalMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final (sliderMin, sliderMax) = WithdrawalSimulator.modeSliderRange(
      portfolio,
      settings.mode,
      annualReturn: settings.annualReturn,
      real: real,
    );
    final sliderValue = monthlyWithdrawal.clamp(sliderMin, sliderMax);
    final sliderSpan = sliderMax - sliderMin;
    final sliderDivisions =
        sliderSpan > 0 ? math.min(12, math.max(1, sliderSpan ~/ 1000)) : null;
    final modeSuggested = WithdrawalSimulator.modeDefaultMonthly(
      portfolio,
      settings.mode,
      annualReturn: settings.annualReturn,
      real: real,
    );
    final targetAnnual = sliderValue * 12;
    final targetRatePercent =
        portfolio > 0 ? (targetAnnual / portfolio) * 100 : 0.0;
    final cappedByMode = monthlyWithdrawal > effectiveMonthly + 500;
    final noProfit =
        settings.mode == WithdrawalMode.profitOnly && !real.hasProfit;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เดือนนี้ถอนเท่าไรดี', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'เลื่อนแถบเพื่อตั้งเป้าว่าอยากถอนกี่บาทต่อเดือน',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<WithdrawalMode>(
            value: settings.mode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'วิธีถอน',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            items: WithdrawalMode.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(_withdrawalModeLabel(mode)),
                  ),
                )
                .toList(),
            onChanged: (mode) {
              if (mode != null) onModeChanged(mode);
            },
          ),
          if (_modeHint(settings.mode, real) != null) ...[
            const SizedBox(height: 8),
            Text(
              _modeHint(settings.mode, real)!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          if (noProfit) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
              ),
              child: const Text(
                'โหมดถอนเฉพาะกำไรต้องมีกำไรสะสมจาก DCA ก่อน\n'
                'บันทึกมูลค่าในหน้า DCA แล้วอัปเดตเมื่อพอร์ตโต — ส่วนต่างจะกลายเป็นกำไร',
                style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.45),
              ),
            ),
          ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เป้าถอนที่ตั้ง',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatThbCompact(sliderValue)} / เดือน',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '≈ ${formatThbCompact(targetAnnual)} / ปี · ${targetRatePercent.toStringAsFixed(1)}% ของพอร์ต',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (cappedByMode) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ถอนได้จริง ${formatThbCompact(effectiveMonthly)}/เดือน (โหมดนี้จำกัดไม่ให้เกิน)',
                    style: const TextStyle(fontSize: 11, color: AppColors.warning),
                  ),
                ] else if ((sliderValue - effectiveMonthly).abs() < 1) ...[
                  const SizedBox(height: 6),
                  Text(
                    'เท่ากับยอดถอนได้จริง — ดูรายละเอียดในการ์ดด้านล่าง',
                    style: TextStyle(fontSize: 11, color: AppColors.profit.withValues(alpha: 0.9)),
                  ),
                ],
              ],
            ),
          ),
          if (!noProfit) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: sliderSpan > 0 ? () => onChanged(modeSuggested) : null,
              child: Text('ใช้ค่าแนะนำ ${formatThbCompact(modeSuggested)}'),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ถอนน้อย', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('ถอนมาก', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          Slider(
            value: sliderValue,
            min: sliderMin,
            max: sliderMax,
            divisions: sliderDivisions,
            label: formatThbCompact(sliderValue),
            onChanged: sliderSpan > 0 ? onChanged : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatThbCompact(sliderMin),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              Text(
                formatThbCompact(sliderMax),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'เลื่อนซ้าย = ถอนน้อยลง · เลื่อนขวา = ถอนมากขึ้น\nผลระยะยาวดูใน “จำลองอนาคตหลังเกษียณ” ด้านล่าง',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
          ),
          ],
          ],
        ],
      ),
    );
  }
}

String _withdrawalModeLabel(WithdrawalMode mode) => switch (mode) {
      WithdrawalMode.percentage => 'ถอนรวม % · แบ่งตาม DCA',
      WithdrawalMode.fixed => 'ถอนคงที่ · แบ่งตาม DCA',
      WithdrawalMode.profitOnly => 'ถอนเฉพาะกำไร',
      WithdrawalMode.dividendOnly => 'ถอนเฉพาะปันผล',
    };

String? _modeHint(WithdrawalMode mode, RealWithdrawalSnapshot real) => switch (mode) {
      WithdrawalMode.percentage =>
        'ตั้งยอดรวม/เดือน → คิดเป็น % ของพอร์ต → แบ่งถอนแต่ละตัวตามเป้า DCA',
      WithdrawalMode.fixed =>
        'ยอดคงที่/เดือน แบ่งถอนตามเป้า % ในหน้า DCA',
      WithdrawalMode.profitOnly =>
        'กำไรสะสมจริง ${formatThbCompact(real.profit)} — ไม่แตะทุน ${formatThbCompact(real.principal)}',
      WithdrawalMode.dividendOnly =>
        'ปันผลประมาณ ${formatThbCompact(real.annualDividendEstimate)}/ปี จากมูลค่าพอร์ตจริง',
    };

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.settings,
    required this.simulation,
    required this.effectiveMonthly,
  });

  final WithdrawalSettings settings;
  final WithdrawalSimulation simulation;
  final double effectiveMonthly;

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
          Row(
            children: [
              const Expanded(
                child: Text('ถ้าถอนแบบนี้', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _withdrawalModeLabel(settings.mode),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('ถอนจริง/เดือน', style: TextStyle(color: color.withValues(alpha: 0.9))),
          Text(
            formatThbCompact(effectiveMonthly),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 8),
          _infoRow('เงินจะอยู่ถึง', 'อายุ ${simulation.lastsUntilAge} ปี'),
          _infoRow('โอกาสสำเร็จ', '${(simulation.successProbability * 100).toStringAsFixed(0)}%'),
          _infoRow('% ถอน/ปี', '${simulation.withdrawalRatePercent.toStringAsFixed(1)}%'),
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
    final firstYear = simulation.projectedFirstYearWithdrawal;
    final usedPct = total > 0 ? (firstYear / total).clamp(0.0, 1.0) : 0.0;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('การถอน (จำลอง)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'ยังไม่มีประวัติถอนจริง — ตัวเลขด้านล่างคาดการณ์ปีแรก',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text('ปีแรกจะถอน ~${formatThbCompact(firstYear)}'),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedPct,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 8),
          Text('พอร์ตปัจจุบัน ${formatThbCompact(simulation.remaining)}'),
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
          const Text('แผนอนาคต (จำลอง)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'เริ่มอายุ ${simulation.simulationStartAge} — ไม่ใช่ประวัติย้อนหลัง',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          ...simulation.timeline.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('อายุ ${e.age} ปี', style: const TextStyle(fontWeight: FontWeight.w600)),
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
