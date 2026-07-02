import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/rebalance_calculator.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class DcaScreen extends ConsumerStatefulWidget {
  const DcaScreen({super.key});

  @override
  ConsumerState<DcaScreen> createState() => _DcaScreenState();
}

class _DcaScreenState extends ConsumerState<DcaScreen> {
  late final TextEditingController _budgetController;
  late final Map<String, TextEditingController> _valueControllers;
  RebalancePlan? _plan;

  @override
  void initState() {
    super.initState();
    final budget = ref.read(storageServiceProvider).monthlyBudget;
    _budgetController = TextEditingController(
      text: budget.toStringAsFixed(0),
    );
    _valueControllers = {
      for (final asset in AppConstants.dcaCalculatorAssets)
        asset['symbol'] as String: TextEditingController(
          text: (asset['defaultValue'] as num).toStringAsFixed(2),
        ),
    };
    _recalculate();
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

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    return AppScaffold(
      title: AppConstants.appName,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'งบต่อเดือน (บาท)',
              suffixText: '฿',
            ),
            onChanged: (_) => _recalculate(),
          ),
          if (plan != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryChip(
                    label: 'รวมพอร์ต',
                    value: formatThbCompact(plan.totalPortfolio),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryChip(
                    label: 'หลังลงทุนเดือนหน้า',
                    value: formatThbCompact(plan.totalAfterInvest),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader(title: 'มูลค่าปัจจุบัน (บาท)'),
          ...AppConstants.dcaCalculatorAssets.map((asset) {
            final symbol = asset['symbol'] as String;
            final name = asset['name'] as String;
            final target = (asset['target'] as num).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AssetValueField(
                name: name,
                targetPercent: target,
                controller: _valueControllers[symbol]!,
                onChanged: _recalculate,
              ),
            );
          }),
          const SizedBox(height: 8),
          if (plan != null) ...[
            const SectionHeader(title: 'เดือนหน้าควรซื้อ'),
            ...plan.rows.map((row) => _ResultCard(row: row)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'รวมที่ต้องลงเดือนหน้า',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    formatThb(plan.totalBuy),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetValueField extends StatelessWidget {
  const _AssetValueField({
    required this.name,
    required this.targetPercent,
    required this.controller,
    required this.onChanged,
  });

  final String name;
  final double targetPercent;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'เป้า ${(targetPercent * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixText: '฿',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.row});

  final RebalanceRow row;

  @override
  Widget build(BuildContext context) {
    final status = row.status;
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case RebalanceRowStatus.normal:
        statusColor = AppColors.profit;
        statusIcon = Icons.check_circle;
        statusLabel = 'ปกติ';
      case RebalanceRowStatus.under:
        statusColor = AppColors.accent;
        statusIcon = Icons.add_circle_outline;
        statusLabel = 'ต่ำกว่าเป้า';
      case RebalanceRowStatus.over:
        statusColor = AppColors.warning;
        statusIcon = Icons.pause_circle_outline;
        statusLabel = 'สูงเกินเป้า';
    }

    final diffSign = row.differencePercent >= 0 ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                label: 'สัดส่วน',
                value: formatAllocationPercent(row.currentPercent),
              ),
              _Metric(
                label: 'ส่วนต่าง',
                value: '$diffSign${row.differencePercent.toStringAsFixed(2)}%',
                valueColor: row.differencePercent.abs() <= 1
                    ? AppColors.textSecondary
                    : (row.differencePercent > 0
                        ? AppColors.warning
                        : AppColors.accent),
              ),
              _Metric(
                label: 'ซื้อเดือนหน้า',
                value: formatThbCompact(row.buyAmount),
                valueColor: AppColors.accent,
                bold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
