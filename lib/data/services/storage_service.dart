import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/portfolio_models.dart';

class StorageService {
  static const _settingsBox = 'settings';
  static const _holdingsBox = 'holdings';

  static const _keyApiKey = 'fmp_api_key';
  static const _keyCurrentAge = 'current_age';
  static const _keyRetirementAge = 'retirement_age';
  static const _keyTargetAmount = 'target_amount';
  static const _keyMonthlyBudget = 'monthly_budget';
  static const _keyDcaAssetValues = 'dca_asset_values';
  static const _keyDcaAssetPreviousValues = 'dca_asset_previous_values';
  static const _keyDarkMode = 'dark_mode';
  static const _keyPortfolioVersion = 'portfolio_data_version';

  late Box<dynamic> _settings;
  late Box<dynamic> _holdings;

  Future<void> init() async {
    await Hive.initFlutter();
    _settings = await Hive.openBox(_settingsBox);
    _holdings = await Hive.openBox(_holdingsBox);

    final version =
        _settings.get(_keyPortfolioVersion, defaultValue: 0) as int;
    if (_holdings.isEmpty || version < AppConstants.portfolioDataVersion) {
      await _seedDefaultHoldings();
      await _settings.put(
        _keyPortfolioVersion,
        AppConstants.portfolioDataVersion,
      );
    }
  }

  Future<void> _seedDefaultHoldings() async {
    final defaults = AppConstants.defaultHoldingsJson
        .map((e) => Holding.fromJson(e))
        .toList();
    await saveHoldings(defaults);
  }

  String? get apiKey => _settings.get(_keyApiKey) as String?;
  Future<void> setApiKey(String value) => _settings.put(_keyApiKey, value);

  int get currentAge =>
      _settings.get(_keyCurrentAge, defaultValue: AppConstants.defaultCurrentAge) as int;
  Future<void> setCurrentAge(int value) => _settings.put(_keyCurrentAge, value);

  int get retirementAge =>
      _settings.get(_keyRetirementAge, defaultValue: AppConstants.defaultRetirementAge) as int;
  Future<void> setRetirementAge(int value) => _settings.put(_keyRetirementAge, value);

  double get targetAmount =>
      (_settings.get(_keyTargetAmount) as num?)?.toDouble() ??
      AppConstants.defaultTargetAmount;
  Future<void> setTargetAmount(double value) => _settings.put(_keyTargetAmount, value);

  double get monthlyBudget =>
      (_settings.get(_keyMonthlyBudget) as num?)?.toDouble() ??
      AppConstants.defaultMonthlyBudget;
  Future<void> setMonthlyBudget(double value) => _settings.put(_keyMonthlyBudget, value);

  Map<String, double> getDcaAssetValues() => _readDcaValueMap(_keyDcaAssetValues);

  Map<String, double> getDcaAssetPreviousValues() =>
      _readDcaValueMap(_keyDcaAssetPreviousValues);

  Map<String, double> _readDcaValueMap(String key) {
    final raw = _settings.get(key);
    if (raw == null) return {};

    if (raw is String) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return decoded.map(
          (k, value) => MapEntry(k, (value as num).toDouble()),
        );
      } catch (_) {
        return {};
      }
    }

    if (raw is Map) {
      return Map<String, double>.fromEntries(
        raw.entries.map(
          (entry) => MapEntry(
            entry.key.toString(),
            (entry.value as num).toDouble(),
          ),
        ),
      );
    }

    return {};
  }

  Future<void> saveDcaAssetValues(Map<String, double> values) async {
    await _settings.put(_keyDcaAssetValues, jsonEncode(values));
    await _settings.flush();
  }

  Future<void> saveDcaAssetPreviousValues(Map<String, double> values) async {
    await _settings.put(_keyDcaAssetPreviousValues, jsonEncode(values));
    await _settings.flush();
  }

  bool get darkMode => _settings.get(_keyDarkMode, defaultValue: true) as bool;
  Future<void> setDarkMode(bool value) => _settings.put(_keyDarkMode, value);

  List<Holding> getHoldings() {
    final raw = _holdings.get('list') as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((e) => Holding.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveHoldings(List<Holding> holdings) async {
    await _holdings.put('list', holdings.map((h) => h.toJson()).toList());
  }
}
