import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/portfolio_models.dart';
import '../../data/services/rebalance_calculator.dart';
import '../../data/services/storage_service.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class DcaScreen extends ConsumerStatefulWidget {
  const DcaScreen({super.key});

  @override
  ConsumerState<DcaScreen> createState() => _DcaScreenState();
}

class _DcaScreenState extends ConsumerState<DcaScreen> {
  late final StorageService _storage;
  late final TextEditingController _budgetController;
  late final Map<String, TextEditingController> _valueControllers;
  late final Map<String, double> _previousValues;
  late Map<String, double> _committedValues;
  String? _activeField;
  RebalancePlan? _plan;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider);
    final savedValues = _storage.getDcaAssetValues();
    _previousValues = Map<String, double>.from(
      _storage.getDcaAssetPreviousValues(),
    );
    _committedValues = {
      for (final asset in AppConstants.dcaCalculatorAssets)
        asset['symbol'] as String: savedValues[asset['symbol'] as String] ??
            (asset['defaultValue'] as num).toDouble(),
    };
    _budgetController = TextEditingController(
      text: _storage.monthlyBudget.toStringAsFixed(0),
    );
    _valueControllers = {
      for (final asset in AppConstants.dcaCalculatorAssets)
        asset['symbol'] as String: TextEditingController(
          text: _committedValues[asset['symbol'] as String]!
              .toStringAsFixed(2),
        ),
    };
    _recalculate();
  }

  double? _previousValueFor(String symbol, num defaultValue) {
    if (_previousValues.containsKey(symbol)) {
      return _previousValues[symbol];
    }
    return null;
  }

  @override
  void dispose() {
    _budgetController.dispose();
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    final budget = double.tryParse(_budgetController.text) ?? 10000;
    final inputs = AppConstants.dcaCalculatorAssets.map((asset) {
      final symbol = asset['symbol'] as String;
      final value = double.tryParse(_valueControllers[symbol]!.text) ?? 0;
      return RebalanceCalculatorInput(
        symbol: symbol,
        name: asset['name'] as String,
        targetPercent: (asset['target'] as num).toDouble(),
        currentValue: value,
      );
    }).toList();

    setState(() {
      _plan = RebalanceCalculator.calculate(
        assets: inputs,
        monthlyBudget: budget,
      );
    });
  }

  void _onBudgetChanged() {
    _recalculate();
    final budget = double.tryParse(_budgetController.text);
    if (budget != null) {
      _storage.setMonthlyBudget(budget);
    }
  }

  void _onAssetChanged(String symbol) {
    setState(() => _activeField = symbol);
    _recalculate();
  }

  void _onFieldTap(String fieldKey) {
    setState(() => _activeField = fieldKey);
  }

  Future<void> _commitNow() async {
    await _saveValues();
    ref.invalidate(portfolioSummaryProvider);
    ref.invalidate(retirementProjectionProvider);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _activeField = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกแล้ว')),
    );
  }

  Future<void> _saveValues() async {
    final budget = double.tryParse(_budgetController.text);
    if (budget != null) {
      await _storage.setMonthlyBudget(budget);
    }

    final values = <String, double>{
      for (final entry in _valueControllers.entries)
        entry.key: double.tryParse(entry.value.text) ?? 0,
    };

    if (!_sameValueMaps(_committedValues, values)) {
      final updatedPrevious = Map<String, double>.from(_previousValues);
      var previousChanged = false;

      for (final entry in values.entries) {
        final committed = _committedValues[entry.key];
        if (committed != null && (committed - entry.value).abs() > 0.009) {
          updatedPrevious[entry.key] = committed;
          previousChanged = true;
        }
      }

      if (previousChanged) {
        await _storage.saveDcaAssetPreviousValues(updatedPrevious);
        _previousValues
          ..clear()
          ..addAll(updatedPrevious);
      }

      await _storage.saveDcaAssetValues(values);
      _committedValues = Map<String, double>.from(values);

      if (mounted) {
        setState(() {});
      }
    }
  }

  bool _sameValueMaps(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || (entry.value - other).abs() > 0.009) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final retirement = ref.watch(retirementProjectionProvider);

    return AppScaffold(
      title: AppConstants.appName,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CompactBudgetBar(
              budgetController: _budgetController,
              plan: plan,
              onChanged: _onBudgetChanged,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const _DcaTableHeader(),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: AppConstants.dcaCalculatorAssets.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppColors.border,
                        ),
                        itemBuilder: (context, index) {
                          final asset = AppConstants.dcaCalculatorAssets[index];
                          final symbol = asset['symbol'] as String;
                          final row = plan?.rows.firstWhere(
                            (r) => r.symbol == symbol,
                          );
                          return _DcaTableRow(
                            name: asset['name'] as String,
                            targetPercent: (asset['target'] as num).toDouble(),
                            previousValue: _previousValueFor(
                              symbol,
                              asset['defaultValue'] as num,
                            ),
                            controller: _valueControllers[symbol]!,
                            row: row,
                            showSave: _activeField == symbol,
                            onChanged: () => _onAssetChanged(symbol),
                            onFieldTap: () => _onFieldTap(symbol),
                            onCommit: _commitNow,
                          );
                        },
                      ),
                    ),
                    if (plan != null) ...[
                      const Divider(height: 1, color: AppColors.border),
                      _DcaTotalFooter(totalBuy: plan.totalBuy),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _CompactRetirementGoal(
              retirement: retirement,
              currentAmount: plan?.totalPortfolio ?? retirement.currentAmount,
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveCheckButton extends StatelessWidget {
  const _SaveCheckButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'บันทึก',
      icon: const Icon(Icons.check_circle, color: AppColors.accent),
      iconSize: 22,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }
}

class _CompactBudgetBar extends StatelessWidget {
  const _CompactBudgetBar({
    required this.budgetController,
    required this.plan,
    required this.onChanged,
  });

  final TextEditingController budgetController;
  final RebalancePlan? plan;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'งบ/เดือน',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: budgetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    suffixText: '฿',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          if (plan != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InlineStat(
                    label: 'รวมพอร์ต',
                    value: formatThbCompact(plan!.totalPortfolio),
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                Expanded(
                  child: _InlineStat(
                    label: 'หลังลงทุน',
                    value: formatThbCompact(plan!.totalAfterInvest),
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                Expanded(
                  child: _InlineStat(
                    label: 'ซื้อเดือนหน้า',
                    value: formatThbCompact(plan!.totalBuy),
                    valueColor: AppColors.accent,
                    bold: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DcaTableHeader extends StatelessWidget {
  const _DcaTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'สินทรัพย์',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'ราคาก่อนหน้า',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'ราคาปัจจุบัน',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'สัดส่วน',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'ซื้อเดือนหน้า',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DcaTableRow extends StatelessWidget {
  const _DcaTableRow({
    required this.name,
    required this.targetPercent,
    required this.previousValue,
    required this.controller,
    required this.row,
    required this.showSave,
    required this.onChanged,
    required this.onFieldTap,
    required this.onCommit,
  });

  final String name;
  final double targetPercent;
  final double? previousValue;
  final TextEditingController controller;
  final RebalanceRow? row;
  final bool showSave;
  final VoidCallback onChanged;
  final VoidCallback onFieldTap;
  final Future<void> Function() onCommit;

  @override
  Widget build(BuildContext context) {
    final currentValue = double.tryParse(controller.text);
    final delta = (previousValue != null && currentValue != null)
        ? currentValue - previousValue!
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (row != null)
                      _ActionBadge(status: row!.status, compact: true)
                    else
                      const _ActionBadge(
                        status: RebalanceRowStatus.normal,
                        compact: true,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      'เป้า ${(targetPercent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  previousValue == null
                      ? '—'
                      : formatThbCompact(previousValue!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (delta != null && delta.abs() >= 0.01)
                  Text(
                    '${delta >= 0 ? '+' : ''}${formatThbCompact(delta)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      color: delta >= 0 ? AppColors.profit : AppColors.loss,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                suffixText: '฿',
                suffixStyle: TextStyle(fontSize: 9),
              ),
              onTap: onFieldTap,
              onChanged: (_) => onChanged(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row == null
                  ? '—'
                  : formatAllocationPercent(row!.currentPercent),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  row == null ? '—' : formatThbCompact(row!.buyAmount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                if (row != null)
                  Text(
                    '${row!.differencePercent >= 0 ? '+' : ''}${row!.differencePercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: row!.differencePercent.abs() <= 1
                          ? AppColors.textSecondary
                          : (row!.differencePercent > 0
                              ? AppColors.warning
                              : AppColors.accent),
                    ),
                  ),
              ],
            ),
          ),
          if (showSave) _SaveCheckButton(onPressed: () => onCommit()),
        ],
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({
    required this.status,
    this.compact = false,
  });

  final RebalanceRowStatus status;
  final bool compact;

  static String _label(RebalanceRowStatus status) => switch (status) {
        RebalanceRowStatus.under => 'ต้องซื้อ',
        RebalanceRowStatus.normal => 'เพิ่ม',
        RebalanceRowStatus.over => 'ไม่เพิ่ม',
      };

  static Color _color(RebalanceRowStatus status) => switch (status) {
        RebalanceRowStatus.under => AppColors.accent,
        RebalanceRowStatus.normal => AppColors.profit,
        RebalanceRowStatus.over => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    final label = _label(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DcaTotalFooter extends StatelessWidget {
  const _DcaTotalFooter({required this.totalBuy});

  final double totalBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'รวมซื้อเดือนหน้า',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            formatThb(totalBuy),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRetirementGoal extends StatelessWidget {
  const _CompactRetirementGoal({
    required this.retirement,
    required this.currentAmount,
  });

  final RetirementProjection retirement;
  final double currentAmount;

  @override
  Widget build(BuildContext context) {
    final yearsLeft = retirement.retirementAge - retirement.currentAge;
    final target = retirement.targetAmount;
    final progress = target > 0
        ? ((currentAmount / target) * 100).clamp(0.0, 100.0)
        : 0.0;
    final progressValue = (progress / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'เป้าหมายเกษียณ',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              Text(
                'ลงทุนอีก $yearsLeft ปี',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.accent,
                ),
              ),
              Text(
                '${(currentAmount / 1000000).toStringAsFixed(1)} / ${(target / 1000000).toStringAsFixed(0)} ล้านบาท',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                'ถึงเป้า ~ปี ${retirement.projectedYear}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
