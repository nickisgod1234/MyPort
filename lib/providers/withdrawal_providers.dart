import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/real_withdrawal_models.dart';
import '../data/models/withdrawal_models.dart';
import '../data/services/real_withdrawal_service.dart';
import '../data/services/withdrawal_simulator.dart';
import 'app_providers.dart';

class WithdrawalSettings {
  const WithdrawalSettings({
    required this.monthlyWithdrawal,
    required this.mode,
    required this.annualReturn,
    required this.inflation,
    required this.withdrawalRate,
    required this.simulateMarketCrash,
    required this.lifeExpectancyAge,
    required this.initialized,
    required this.simulationExpanded,
  });

  final double monthlyWithdrawal;
  final WithdrawalMode mode;
  final double annualReturn;
  final double inflation;
  final double withdrawalRate;
  final bool simulateMarketCrash;
  final int lifeExpectancyAge;
  final bool initialized;
  final bool simulationExpanded;

  WithdrawalSettings copyWith({
    double? monthlyWithdrawal,
    WithdrawalMode? mode,
    double? annualReturn,
    double? inflation,
    double? withdrawalRate,
    bool? simulateMarketCrash,
    int? lifeExpectancyAge,
    bool? initialized,
    bool? simulationExpanded,
  }) {
    return WithdrawalSettings(
      monthlyWithdrawal: monthlyWithdrawal ?? this.monthlyWithdrawal,
      mode: mode ?? this.mode,
      annualReturn: annualReturn ?? this.annualReturn,
      inflation: inflation ?? this.inflation,
      withdrawalRate: withdrawalRate ?? this.withdrawalRate,
      simulateMarketCrash: simulateMarketCrash ?? this.simulateMarketCrash,
      lifeExpectancyAge: lifeExpectancyAge ?? this.lifeExpectancyAge,
      initialized: initialized ?? this.initialized,
      simulationExpanded: simulationExpanded ?? this.simulationExpanded,
    );
  }
}

class WithdrawalSettingsNotifier extends StateNotifier<WithdrawalSettings> {
  WithdrawalSettingsNotifier()
      : super(
          const WithdrawalSettings(
            monthlyWithdrawal: 46850,
            mode: WithdrawalMode.percentage,
            annualReturn: 0.07,
            inflation: 0.03,
            withdrawalRate: 0.04,
            simulateMarketCrash: false,
            lifeExpectancyAge: 96,
            initialized: false,
            simulationExpanded: false,
          ),
        );

  void setMonthlyWithdrawal(
    double value, {
    double? portfolio,
    RealWithdrawalSnapshot? real,
  }) {
    var monthly = value;
    if (portfolio != null && portfolio > 0) {
      final (min, max) = WithdrawalSimulator.modeSliderRange(
        portfolio,
        state.mode,
        annualReturn: state.annualReturn,
        real: real,
      );
      monthly = value.clamp(min, max).toDouble();
    }
    state = state.copyWith(
      monthlyWithdrawal: monthly,
      withdrawalRate: portfolio != null && portfolio > 0
          ? (monthly * 12 / portfolio).clamp(0.01, 0.15)
          : state.withdrawalRate,
      initialized: true,
    );
  }

  void setWithdrawalRate(double rate, {double? portfolio}) {
    state = state.copyWith(
      withdrawalRate: rate,
      monthlyWithdrawal: portfolio != null && portfolio > 0
          ? (portfolio * rate) / 12
          : state.monthlyWithdrawal,
      initialized: true,
    );
  }

  void setMode(
    WithdrawalMode mode, {
    double? portfolio,
    RealWithdrawalSnapshot? real,
  }) {
    if (portfolio != null && portfolio > 0) {
      final monthly = WithdrawalSimulator.modeDefaultMonthly(
        portfolio,
        mode,
        annualReturn: state.annualReturn,
        real: real,
      );
      final (min, max) = WithdrawalSimulator.modeSliderRange(
        portfolio,
        mode,
        annualReturn: state.annualReturn,
        real: real,
      );
      final clampedMonthly = monthly.clamp(min, max).toDouble();
      state = state.copyWith(
        mode: mode,
        monthlyWithdrawal: clampedMonthly,
        withdrawalRate: (clampedMonthly * 12 / portfolio).clamp(0.01, 0.15),
        initialized: true,
      );
      return;
    }
    state = state.copyWith(mode: mode);
  }

  void setSimulateMarketCrash(bool value) {
    state = state.copyWith(simulateMarketCrash: value);
  }

  void setSimulationExpanded(bool value) {
    state = state.copyWith(simulationExpanded: value);
  }
}

final withdrawalSettingsProvider =
    StateNotifierProvider<WithdrawalSettingsNotifier, WithdrawalSettings>(
  (ref) => WithdrawalSettingsNotifier(),
);

final realWithdrawalSnapshotProvider = Provider<RealWithdrawalSnapshot?>((ref) {
  final summaryAsync = ref.watch(portfolioSummaryProvider);
  final storage = ref.watch(storageServiceProvider);

  return summaryAsync.when(
    data: (s) => RealWithdrawalService.fromSummary(
      s,
      previousValues: storage.getDcaAssetPreviousValues(),
    ),
    loading: () => null,
    error: (_, __) => null,
  );
});

final withdrawalSimulationProvider = Provider<WithdrawalSimulation?>((ref) {
  final summary = ref.watch(portfolioSummaryProvider);
  final settings = ref.watch(withdrawalSettingsProvider);
  final storage = ref.watch(storageServiceProvider);

  return summary.when(
    data: (s) {
      final real = RealWithdrawalService.fromSummary(
        s,
        previousValues: storage.getDcaAssetPreviousValues(),
      );
      final portfolio = s.totalValueThb;
      final monthlyWithdrawal = settings.initialized
          ? settings.monthlyWithdrawal
          : WithdrawalSimulator.modeDefaultMonthly(
              portfolio,
              settings.mode,
              real: real,
            );
      final cashReserve = math.max(
        monthlyWithdrawal * 26,
        portfolio * 0.08,
      );
      final effectiveWithdrawalRate = portfolio > 0
          ? (monthlyWithdrawal * 12 / portfolio).clamp(0.01, 0.15)
          : settings.withdrawalRate;

      final plan = WithdrawalPlan(
        portfolio: portfolio,
        principal: s.totalInvestedThb,
        currentAge: storage.retirementAge,
        lifeExpectancyAge: settings.lifeExpectancyAge,
        monthlyWithdrawal: monthlyWithdrawal,
        annualReturn: settings.annualReturn,
        inflation: settings.inflation,
        cashReserve: cashReserve,
        mode: settings.mode,
        withdrawalRate: settings.mode == WithdrawalMode.percentage
            ? effectiveWithdrawalRate
            : settings.withdrawalRate,
        simulateMarketCrash: settings.simulateMarketCrash,
        realDividendAnnual: real.annualDividendEstimate,
      );

      return WithdrawalSimulator.simulate(plan);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
