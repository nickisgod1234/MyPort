import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/portfolio_profiles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/portfolio_models.dart';
import '../../data/services/rebalance_calculator.dart';
import '../../data/services/storage_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/portfolio_profile_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class DcaScreen extends ConsumerStatefulWidget {
  const DcaScreen({super.key});

  @override
  ConsumerState<DcaScreen> createState() => _DcaScreenState();
}

class _DcaScreenState extends ConsumerState<DcaScreen> {
  late final StorageService _storage;
  late final TextEditingController _budgetController;
  late final TextEditingController _rateController;
  late final Map<String, TextEditingController> _valueControllers;
  late final Map<String, double> _previousValues;
  late Map<String, double> _committedValues;
  late String _profileId;
  String? _activeField;
  RebalancePlan? _plan;
  bool _inputInUsd = false;

  List<Map<String, dynamic>> get _assets =>
      PortfolioProfiles.byId(_profileId).assets;

  double get _rate {
    final parsed = double.tryParse(_rateController.text);
    if (parsed != null && parsed > 0) return parsed;
    final stored = ref.read(usdThbRateProvider);
    return stored > 0 ? stored : AppConstants.usdThbRate;
  }

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider);
    _inputInUsd = ref.read(dcaInputCurrencyProvider) == 'USD';
    _budgetController = TextEditingController();
    _rateController = TextEditingController(
      text: ref.read(usdThbRateProvider).toStringAsFixed(2),
    );
    _valueControllers = {};
    _previousValues = {};
    _committedValues = {};
    _bootstrapProfile(ref.read(activeProfileIdProvider));
  }

  void _bootstrapProfile(String profileId) {
    _profileId = profileId;
    final profile = PortfolioProfiles.byId(profileId);
    final savedValues = _storage.getDcaAssetValues(profileId);
    _previousValues
      ..clear()
      ..addAll(_storage.getDcaAssetPreviousValues(profileId));
    _committedValues = {
      for (final asset in profile.assets)
        asset['symbol'] as String: savedValues[asset['symbol'] as String] ??
            (asset['defaultValue'] as num).toDouble(),
    };
    _budgetController.text =
        _storage.getMonthlyBudget(profileId).toStringAsFixed(0);
    for (final controller in _valueControllers.values) {
      controller.dispose();
    }
    _valueControllers
      ..clear()
      ..addEntries(
        profile.assets.map(
          (asset) {
            final symbol = asset['symbol'] as String;
            final thb = _committedValues[symbol]!;
            final display = displayAmountFromThb(
              thb,
              inUsd: _inputInUsd,
              rate: _rate,
            );
            return MapEntry(
              symbol,
              TextEditingController(text: display.toStringAsFixed(2)),
            );
          },
        ),
      );
    _recalculate();
  }

  double _thbFromController(String symbol) {
    final display = double.tryParse(_valueControllers[symbol]!.text) ?? 0;
    return thbFromDisplayAmount(display, inUsd: _inputInUsd, rate: _rate);
  }

  Future<void> _setInputCurrency(bool inUsd) async {
    if (_inputInUsd == inUsd) return;

    // Convert currently typed values to THB first, then re-display.
    final thbBySymbol = <String, double>{
      for (final symbol in _valueControllers.keys) symbol: _thbFromController(symbol),
    };

    setState(() => _inputInUsd = inUsd);
    await _storage.setDcaInputCurrency(inUsd ? 'USD' : 'THB');
    ref.read(dcaInputCurrencyProvider.notifier).state = inUsd ? 'USD' : 'THB';

    for (final entry in thbBySymbol.entries) {
      final controller = _valueControllers[entry.key];
      if (controller == null) continue;
      final display = displayAmountFromThb(
        entry.value,
        inUsd: _inputInUsd,
        rate: _rate,
      );
      controller.text = display.toStringAsFixed(2);
    }
    _recalculate();
  }

  Future<void> _onRateChanged(String raw) async {
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      _recalculate();
      return;
    }
    ref.read(usdThbRateProvider.notifier).state = parsed;
    await _storage.setUsdThbRate(parsed);

    // Keep typed amounts as the same currency numbers; recalc THB internal uses new rate.
    // If input is USD, changing rate changes THB equivalent — expected.
    _recalculate();
  }

  Future<void> _switchProfile(String profileId) async {
    if (profileId == _profileId) return;
    await _saveValues();
    _bootstrapProfile(profileId);
    await ref.read(activeProfileIdProvider.notifier).setProfile(profileId);
    ref.invalidate(portfolioSummaryProvider);
    ref.invalidate(retirementProjectionProvider);
    if (mounted) {
      setState(() => _activeField = null);
    }
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
    _rateController.dispose();
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _recalculate() {
    final budget = double.tryParse(_budgetController.text) ?? 10000;
    final inputs = _assets.map((asset) {
      final symbol = asset['symbol'] as String;
      return RebalanceCalculatorInput(
        symbol: symbol,
        name: AppConstants.assetDisplayNames[symbol] ??
            asset['name'] as String,
        targetPercent: (asset['target'] as num).toDouble(),
        currentValue: _thbFromController(symbol),
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
      _storage.setMonthlyBudget(budget, profileId: _profileId);
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
      await _storage.setMonthlyBudget(budget, profileId: _profileId);
    }

    final values = <String, double>{
      for (final symbol in _valueControllers.keys) symbol: _thbFromController(symbol),
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
        await _storage.saveDcaAssetPreviousValues(
          updatedPrevious,
          profileId: _profileId,
        );
        _previousValues
          ..clear()
          ..addAll(updatedPrevious);
      }

      await _storage.saveDcaAssetValues(values, profileId: _profileId);
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

  Future<void> _clearAssetValues() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เคลียร์มูลค่า'),
        content: const Text(
          'รีเซ็ตมูลค่าปัจจุบันและก่อนหน้าเป็น 0\n'
          'สัดส่วนเป้าหมายและงบ/เดือนจะไม่เปลี่ยน',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('เคลียร์'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    for (final controller in _valueControllers.values) {
      controller.text = '0.00';
    }

    final zeros = <String, double>{
      for (final symbol in _valueControllers.keys) symbol: 0.0,
    };

    _previousValues.clear();
    _committedValues = Map<String, double>.from(zeros);
    await _storage.saveDcaAssetValues(zeros, profileId: _profileId);
    await _storage.saveDcaAssetPreviousValues({}, profileId: _profileId);

    ref.invalidate(portfolioSummaryProvider);
    ref.invalidate(retirementProjectionProvider);
    _recalculate();
    setState(() => _activeField = null);

    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เคลียร์มูลค่าเป็น 0 แล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final retirement = ref.watch(retirementProjectionProvider);
    final activeProfile = PortfolioProfiles.byId(_profileId);
    final usdThbRate = ref.watch(usdThbRateProvider);

    return AppScaffold(
      title: AppConstants.appName,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileSwitcher(
              selectedId: _profileId,
              onSelected: _switchProfile,
            ),
            if (_profileId == PortfolioProfiles.partnerId)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  '${activeProfile.emoji} Growth 85% · ปันผล 5% · ทอง 10%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            _CompactBudgetBar(
              budgetController: _budgetController,
              rateController: _rateController,
              plan: plan,
              usdThbRate: usdThbRate,
              inputInUsd: _inputInUsd,
              onChanged: _onBudgetChanged,
              onClear: _clearAssetValues,
              onRateChanged: _onRateChanged,
              onCurrencyChanged: _setInputCurrency,
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
                    _DcaTableHeader(inputInUsd: _inputInUsd),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _assets.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppColors.border,
                        ),
                        itemBuilder: (context, index) {
                          final asset = _assets[index];
                          final symbol = asset['symbol'] as String;
                          final row = plan?.rows.firstWhere(
                            (r) => r.symbol == symbol,
                          );
                          return _DcaTableRow(
                            name: AppConstants.assetDisplayNames[symbol] ??
                                asset['name'] as String,
                            targetPercent: (asset['target'] as num).toDouble(),
                            previousValue: _previousValueFor(
                              symbol,
                              asset['defaultValue'] as num,
                            ),
                            controller: _valueControllers[symbol]!,
                            row: row,
                            usdThbRate: usdThbRate,
                            inputInUsd: _inputInUsd,
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
                      _DcaTotalFooter(
                        totalBuy: plan.totalBuy,
                        usdThbRate: usdThbRate,
                      ),
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

class _ProfileSwitcher extends StatelessWidget {
  const _ProfileSwitcher({
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final profile in PortfolioProfiles.all)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: profile.id == PortfolioProfiles.retirementId ? 4 : 0,
                left: profile.id == PortfolioProfiles.partnerId ? 4 : 0,
              ),
              child: Material(
                color: selectedId == profile.id
                    ? AppColors.accent.withValues(alpha: 0.18)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onSelected(profile.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedId == profile.id
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${profile.emoji} ${profile.name}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: selectedId == profile.id
                            ? AppColors.accent
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactBudgetBar extends StatelessWidget {
  const _CompactBudgetBar({
    required this.budgetController,
    required this.rateController,
    required this.plan,
    required this.usdThbRate,
    required this.inputInUsd,
    required this.onChanged,
    required this.onClear,
    required this.onRateChanged,
    required this.onCurrencyChanged,
  });

  final TextEditingController budgetController;
  final TextEditingController rateController;
  final RebalancePlan? plan;
  final double usdThbRate;
  final bool inputInUsd;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onRateChanged;
  final ValueChanged<bool> onCurrencyChanged;

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
              const SizedBox(width: 4),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('เคลียร์', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'เรท',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    suffixText: '฿/\$',
                    suffixStyle: TextStyle(fontSize: 10),
                  ),
                  onChanged: onRateChanged,
                ),
              ),
              const Spacer(),
              _CurrencyToggle(
                inputInUsd: inputInUsd,
                onChanged: onCurrencyChanged,
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
                    subtitle: formatUsdFromThb(
                      plan!.totalPortfolio,
                      usdThbRate,
                    ),
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(
                  child: _InlineStat(
                    label: 'หลังลงทุน',
                    value: formatThbCompact(plan!.totalAfterInvest),
                    subtitle: formatUsdFromThb(
                      plan!.totalAfterInvest,
                      usdThbRate,
                    ),
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(
                  child: _InlineStat(
                    label: 'ซื้อเดือนหน้า',
                    value: formatThbCompact(plan!.totalBuy),
                    subtitle: formatUsdFromThb(plan!.totalBuy, usdThbRate),
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

class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle({
    required this.inputInUsd,
    required this.onChanged,
  });

  final bool inputInUsd;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CurrencyChip(
            label: '฿',
            selected: !inputInUsd,
            onTap: () => onChanged(false),
          ),
          _CurrencyChip(
            label: '\$',
            selected: inputInUsd,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final String? subtitle;
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
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _DcaTableHeader extends StatelessWidget {
  const _DcaTableHeader({required this.inputInUsd});

  final bool inputInUsd;

  @override
  Widget build(BuildContext context) {
    final unit = inputInUsd ? '\$' : '฿';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          const Expanded(
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
              'ก่อน ($unit)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'ปัจจุบัน ($unit)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(
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
          const Expanded(
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
    required this.usdThbRate,
    required this.inputInUsd,
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
  final double usdThbRate;
  final bool inputInUsd;
  final bool showSave;
  final VoidCallback onChanged;
  final VoidCallback onFieldTap;
  final Future<void> Function() onCommit;

  @override
  Widget build(BuildContext context) {
    final displayValue = double.tryParse(controller.text);
    final currentThb = displayValue == null
        ? null
        : thbFromDisplayAmount(
            displayValue,
            inUsd: inputInUsd,
            rate: usdThbRate,
          );
    final previousDisplay = previousValue == null
        ? null
        : displayAmountFromThb(
            previousValue!,
            inUsd: inputInUsd,
            rate: usdThbRate,
          );
    final delta = (previousValue != null && currentThb != null)
        ? currentThb - previousValue!
        : null;
    final deltaDisplay = delta == null
        ? null
        : displayAmountFromThb(delta, inUsd: inputInUsd, rate: usdThbRate);

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
                  previousDisplay == null
                      ? '—'
                      : previousDisplay.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (previousValue != null)
                  Text(
                    inputInUsd
                        ? formatThbCompact(previousValue!)
                        : formatUsdFromThb(previousValue!, usdThbRate),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (deltaDisplay != null && deltaDisplay.abs() >= 0.01)
                  Text(
                    '${deltaDisplay >= 0 ? '+' : ''}${deltaDisplay.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      color: deltaDisplay >= 0
                          ? AppColors.profit
                          : AppColors.loss,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                TextField(
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
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    suffixText: inputInUsd ? '\$' : '฿',
                    suffixStyle: const TextStyle(fontSize: 9),
                  ),
                  onTap: onFieldTap,
                  onChanged: (_) => onChanged(),
                ),
                if (currentThb != null && currentThb > 0)
                  Text(
                    inputInUsd
                        ? formatThbCompact(currentThb)
                        : formatUsdFromThb(currentThb, usdThbRate),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
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
                  row == null
                      ? '—'
                      : (inputInUsd
                          ? thbToUsd(row!.buyAmount, usdThbRate)
                              .toStringAsFixed(2)
                          : formatThbCompact(row!.buyAmount)),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                if (row != null) ...[
                  Text(
                    inputInUsd
                        ? formatThbCompact(row!.buyAmount)
                        : formatUsdFromThb(row!.buyAmount, usdThbRate),
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textSecondary,
                    ),
                  ),
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
  const _DcaTotalFooter({
    required this.totalBuy,
    required this.usdThbRate,
  });

  final double totalBuy;
  final double usdThbRate;

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatThb(totalBuy),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              Text(
                formatUsdFromThb(totalBuy, usdThbRate),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
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
