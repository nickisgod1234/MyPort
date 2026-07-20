import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _ageController;
  late final TextEditingController _retirementController;
  late final TextEditingController _targetController;
  late final TextEditingController _usdThbRateController;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _apiKeyController = TextEditingController(text: storage.apiKey ?? '');
    _ageController =
        TextEditingController(text: storage.currentAge.toString());
    _retirementController =
        TextEditingController(text: storage.retirementAge.toString());
    _targetController = TextEditingController(
      text: storage.targetAmount.toStringAsFixed(0),
    );
    _usdThbRateController = TextEditingController(
      text: storage.usdThbRate.toStringAsFixed(2),
    );
    _darkMode = storage.darkMode;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _ageController.dispose();
    _retirementController.dispose();
    _targetController.dispose();
    _usdThbRateController.dispose();
    super.dispose();
  }

  ({int currentAge, int retirementAge, double targetAmount, double usdThbRate})?
  _validatedSettings() {
    final currentAge = int.tryParse(_ageController.text.trim());
    if (currentAge == null || currentAge < 1 || currentAge > 100) {
      _showValidationError('กรอกอายุปัจจุบันเป็นตัวเลข 1-100');
      return null;
    }

    final retirementAge = int.tryParse(_retirementController.text.trim());
    if (retirementAge == null || retirementAge < 1 || retirementAge > 120) {
      _showValidationError('กรอกอายุเกษียณเป็นตัวเลข 1-120');
      return null;
    }
    if (retirementAge <= currentAge) {
      _showValidationError('อายุเกษียณต้องมากกว่าอายุปัจจุบัน');
      return null;
    }

    final targetAmount = double.tryParse(_targetController.text.trim());
    if (targetAmount == null || targetAmount <= 0) {
      _showValidationError('เงินเป้าหมายต้องมากกว่า 0');
      return null;
    }

    final usdThbRate = double.tryParse(_usdThbRateController.text.trim());
    if (usdThbRate == null || usdThbRate <= 0) {
      _showValidationError('เรท USD/THB ต้องมากกว่า 0');
      return null;
    }

    return (
      currentAge: currentAge,
      retirementAge: retirementAge,
      targetAmount: targetAmount,
      usdThbRate: usdThbRate,
    );
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _save() async {
    final validated = _validatedSettings();
    if (validated == null) return;

    final storage = ref.read(storageServiceProvider);
    await storage.setApiKey(_apiKeyController.text.trim());
    await storage.setCurrentAge(validated.currentAge);
    await storage.setRetirementAge(validated.retirementAge);
    await storage.setTargetAmount(validated.targetAmount);
    await storage.setUsdThbRate(validated.usdThbRate);
    ref.read(usdThbRateProvider.notifier).state = validated.usdThbRate;
    await storage.setDarkMode(_darkMode);

    _ageController.text = validated.currentAge.toString();
    _retirementController.text = validated.retirementAge.toString();
    _targetController.text = validated.targetAmount.toStringAsFixed(0);
    _usdThbRateController.text = validated.usdThbRate.toStringAsFixed(2);

    ref.read(fmpApiServiceProvider).updateApiKey(_apiKeyController.text.trim());
    ref.invalidate(portfolioSummaryProvider);
    ref.invalidate(marketQuotesProvider);
    ref.invalidate(watchlistQuotesProvider);
    ref.invalidate(portfolioNewsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกการตั้งค่าแล้ว')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      trialPageName: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'API'),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'Financial Modeling Prep API Key',
              hintText: 'ใส่ API Key จาก fmp.com',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          const Text(
            'ใช้ API เดียวสำหรับหุ้น, ETF และคริปโต',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'อัตราแลกเปลี่ยน'),
          TextField(
            controller: _usdThbRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'บาท ต่อ 1 ดอลลาร์',
              hintText: 'เช่น 33.28',
              suffixText: '฿ / \$',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ใส่เรทที่ใช้ตอนกรอกมูลค่า เช่น 1 USD = 32.50 บาท — แก้ได้บนหน้า DCA ด้วย',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'เป้าหมายเกษียณ'),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'อายุปัจจุบัน'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _retirementController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'อายุเกษียณ'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'เงินเป้าหมาย',
              suffixText: formatThb(0).replaceAll('0', '').trim(),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'ธีม'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text(
                'TradingView style — สีดำพรีเมียม',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: _darkMode,
              thumbColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected) ? AppColors.accent : null,
              ),
              onChanged: (v) => setState(() => _darkMode = v),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('บันทึก'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              AppConstants.appName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
