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
    _darkMode = storage.darkMode;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _ageController.dispose();
    _retirementController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setApiKey(_apiKeyController.text.trim());
    await storage.setCurrentAge(int.tryParse(_ageController.text) ?? 36);
    await storage.setRetirementAge(
      int.tryParse(_retirementController.text) ?? 60,
    );
    await storage.setTargetAmount(
      double.tryParse(_targetController.text) ??
          AppConstants.defaultTargetAmount,
    );
    await storage.setDarkMode(_darkMode);

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
              activeThumbColor: AppColors.accent,
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
