import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/withdrawal_models.dart';
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
  });

  final double monthlyWithdrawal;
  final WithdrawalMode mode;
  final double annualReturn;
  final double inflation;
  final double withdrawalRate;
  final bool simulateMarketCrash;
  final int lifeExpectancyAge;
  final bool initialized;

  WithdrawalSettings copyWith({
    double? monthlyWithdrawal,
    WithdrawalMode? mode,
    double? annualReturn,
    double? inflation,
    double? withdrawalRate,
    bool? simulateMarketCrash,
    int? lifeExpectancyAge,
    bool? initialized,
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
          ),
        );

  void setMonthlyWithdrawal(double value) {
    state = state.copyWith(monthlyWithdrawal: value, initialized: true);
  }

  void setMode(WithdrawalMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setSimulateMarketCrash(bool value) {
    state = state.copyWith(simulateMarketCrash: value);
  }

  void setWithdrawalRate(double rate) {
    state = state.copyWith(withdrawalRate: rate);
  }
}

final withdrawalSettingsProvider =
    StateNotifierProvider<WithdrawalSettingsNotifier, WithdrawalSettings>(
  (ref) => WithdrawalSettingsNotifier(),
);

final withdrawalSimulationProvider = Provider<WithdrawalSimulation?>((ref) {
  final summary = ref.watch(portfolioSummaryProvider);
  final settings = ref.watch(withdrawalSettingsProvider);
  final storage = ref.watch(storageServiceProvider);

  return summary.when(
    data: (s) {
      final portfolio = s.totalValueThb;
      final monthlyWithdrawal = settings.initialized
          ? settings.monthlyWithdrawal
          : WithdrawalSimulator.recommendedMonthly(portfolio);
      final cashReserve = math.max(
        monthlyWithdrawal * 26,
        portfolio * 0.08,
      );

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
        withdrawalRate: settings.withdrawalRate,
        simulateMarketCrash: settings.simulateMarketCrash,
      );

      return WithdrawalSimulator.simulate(plan);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
