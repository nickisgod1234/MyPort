import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/portfolio_models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class DcaScreen extends ConsumerStatefulWidget {
  const DcaScreen({super.key});

  @override
  ConsumerState<DcaScreen> createState() => _DcaScreenState();
}

class _DcaScreenState extends ConsumerState<DcaScreen> {
  late final TextEditingController _budgetController;
  List<DcaAllocation>? _allocations;
  PortfolioAnalysis? _analysis;

  @override
  void initState() {
    super.initState();
    final budget = ref.read(storageServiceProvider).monthlyBudget;
    _budgetController = TextEditingController(
      text: budget.toStringAsFixed(0),
    );
    _calculateDca();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  void _calculateDca() {
    final budget = double.tryParse(_budgetController.text) ?? 10000;
    setState(() {
      _allocations = ref.read(portfolioServiceProvider).calculateDca(budget);
    });
  }

  Future<void> _analyzePortfolio() async {
    final analysis =
        await ref.read(portfolioServiceProvider).analyzePortfolio();
    setState(() => _analysis = analysis);
  }

  @override
  Widget build(BuildContext context) {
    final allocations = _allocations ?? [];

    return AppScaffold(
      title: 'DCA',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'DCA Calculator'),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'งบเดือนนี้ (บาท)',
              suffixText: '฿',
            ),
            onChanged: (_) => _calculateDca(),
          ),
          const SizedBox(height: 20),
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
                const Text(
                  'ระบบแนะนำ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ...allocations.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.displayName,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        Text(
                          formatThb(a.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (a.isRecommended) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.profit,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Rebalance'),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _analyzePortfolio,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Analyze Portfolio'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_analysis != null) ...[
            const SizedBox(height: 20),
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
                  Row(
                    children: [
                      const Text(
                        'คะแนน',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_analysis!.score}/100',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.profit,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._analysis!.suggestions.map(_buildSuggestion),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSuggestion(RebalanceSuggestion s) {
    Color statusColor;
    IconData icon;
    switch (s.status) {
      case RebalanceStatus.over:
        statusColor = AppColors.warning;
        icon = Icons.trending_up;
      case RebalanceStatus.skip:
        statusColor = AppColors.loss;
        icon = Icons.block;
      case RebalanceStatus.under:
        statusColor = AppColors.profit;
        icon = Icons.add_circle_outline;
      case RebalanceStatus.ok:
        statusColor = AppColors.textSecondary;
        icon = Icons.check;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  s.message,
                  style: TextStyle(color: statusColor, fontSize: 13),
                ),
                if (s.suggestedAmount != null)
                  Text(
                    'เพิ่มอีก ${s.suggestedAmount!.toStringAsFixed(0)} บาท',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
