import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/portfolio_profiles.dart';
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
  static const _keyUsdThbRate = 'usd_thb_rate';
  static const _keyDcaInputCurrency = 'dca_input_currency';
  static const _keyPortfolioVersion = 'portfolio_data_version';
  static const _keyActiveProfile = 'active_profile_id';

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

  Future<void> setMonthlyBudget(double value, {String? profileId}) =>
      _settings.put(_budgetKey(profileId), value);

  String get activeProfileId => _settings.get(
        _keyActiveProfile,
        defaultValue: PortfolioProfiles.retirementId,
      ) as String;

  Future<void> setActiveProfileId(String value) =>
      _settings.put(_keyActiveProfile, value);

  Map<String, double> getDcaAssetValues([String? profileId]) =>
      _readDcaValueMap(_dcaValuesKey(profileId));

  Map<String, double> getDcaAssetPreviousValues([String? profileId]) =>
      _readDcaValueMap(_dcaPreviousValuesKey(profileId));

  String _scopedKey(String base, String profileId) {
    if (profileId == PortfolioProfiles.retirementId) return base;
    return '${base}_$profileId';
  }

  String _budgetKey(String? profileId) =>
      _scopedKey(_keyMonthlyBudget, profileId ?? activeProfileId);

  String _dcaValuesKey(String? profileId) {
    final id = profileId ?? activeProfileId;
    if (id == PortfolioProfiles.retirementId) {
      final legacy = _readDcaValueMap(_keyDcaAssetValues);
      if (legacy.isNotEmpty) return _keyDcaAssetValues;
      return _scopedKey(_keyDcaAssetValues, id);
    }
    return _scopedKey(_keyDcaAssetValues, id);
  }

  String _dcaPreviousValuesKey(String? profileId) {
    final id = profileId ?? activeProfileId;
    if (id == PortfolioProfiles.retirementId) {
      final legacy = _readDcaValueMap(_keyDcaAssetPreviousValues);
      if (legacy.isNotEmpty) return _keyDcaAssetPreviousValues;
      return _scopedKey(_keyDcaAssetPreviousValues, id);
    }
    return _scopedKey(_keyDcaAssetPreviousValues, id);
  }

  double get monthlyBudget => getMonthlyBudget();

  double getMonthlyBudget([String? profileId]) {
    final id = profileId ?? activeProfileId;
    final scoped = (_settings.get(_budgetKey(id)) as num?)?.toDouble();
    if (scoped != null) return scoped;
    if (id == PortfolioProfiles.retirementId) {
      return (_settings.get(_keyMonthlyBudget) as num?)?.toDouble() ??
          PortfolioProfiles.byId(id).defaultMonthlyBudget;
    }
    return PortfolioProfiles.byId(id).defaultMonthlyBudget;
  }

  Future<void> saveDcaAssetValues(
    Map<String, double> values, {
    String? profileId,
  }) async {
    await _settings.put(_dcaValuesKey(profileId), jsonEncode(values));
    await _settings.flush();
  }

  Future<void> saveDcaAssetPreviousValues(
    Map<String, double> values, {
    String? profileId,
  }) async {
    await _settings.put(_dcaPreviousValuesKey(profileId), jsonEncode(values));
    await _settings.flush();
  }

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

  bool get darkMode => _settings.get(_keyDarkMode, defaultValue: true) as bool;
  Future<void> setDarkMode(bool value) => _settings.put(_keyDarkMode, value);

  /// บาทต่อ 1 ดอลลาร์ (เช่น 33.28)
  double get usdThbRate =>
      (_settings.get(_keyUsdThbRate) as num?)?.toDouble() ??
      AppConstants.usdThbRate;

  Future<void> setUsdThbRate(double value) =>
      _settings.put(_keyUsdThbRate, value);

  /// สกุลเงินช่องกรอก DCA: `THB` หรือ `USD`
  String get dcaInputCurrency {
    final value = _settings.get(_keyDcaInputCurrency, defaultValue: 'THB') as String;
    return value == 'USD' ? 'USD' : 'THB';
  }

  Future<void> setDcaInputCurrency(String value) =>
      _settings.put(_keyDcaInputCurrency, value == 'USD' ? 'USD' : 'THB');

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
