import 'dart:math' as math;

import '../models/real_withdrawal_models.dart';
import '../models/withdrawal_models.dart';

class WithdrawalSimulator {
  static const _dividendYield = 0.04;
  static const _growthAssets = {
    'VT',
    'SMH',
    'SCHG',
    'BTCUSD',
    'RKLB',
    'KKP_NDQ',
  };

  static double recommendedMonthly(double portfolio, {double rate = 0.04}) {
    return (portfolio * rate) / 12;
  }

  static double modeDefaultMonthly(
    double portfolio,
    WithdrawalMode mode, {
    double annualReturn = 0.07,
    RealWithdrawalSnapshot? real,
  }) {
    if (real != null) {
      return switch (mode) {
        WithdrawalMode.percentage || WithdrawalMode.fixed =>
          real.recommendedMonthly4Pct,
        WithdrawalMode.profitOnly => real.profitOnlyMaxMonthly,
        WithdrawalMode.dividendOnly => real.dividendOnlyMaxMonthly,
      };
    }

    return switch (mode) {
      WithdrawalMode.percentage || WithdrawalMode.fixed =>
        recommendedMonthly(portfolio),
      WithdrawalMode.profitOnly => (portfolio * annualReturn) / 12,
      WithdrawalMode.dividendOnly => (portfolio * _dividendYield) / 12,
    };
  }

  static (double min, double max) modeSliderRange(
    double portfolio,
    WithdrawalMode mode, {
    double annualReturn = 0.07,
    RealWithdrawalSnapshot? real,
  }) {
    if (portfolio <= 0) return (1000, 5000);

    if (real != null) {
      final range = switch (mode) {
        WithdrawalMode.percentage || WithdrawalMode.fixed => (
            math.max(1000, real.recommendedMonthly4Pct * 0.4),
            math.max(20000, real.recommendedMonthly4Pct * 2.5),
          ),
        WithdrawalMode.profitOnly => real.profitOnlyMaxMonthly > 0
            ? (
                real.profitOnlyMaxMonthly * 0.3,
                real.profitOnlyMaxMonthly,
              )
            : (0.0, 0.0),
        WithdrawalMode.dividendOnly => (
            real.dividendOnlyMaxMonthly * 0.3,
            math.max(1000, math.max(real.dividendOnlyMaxMonthly, 1000)),
          ),
      };
      return _normalizeSliderRange(range.$1.toDouble(), range.$2.toDouble());
    }

    final range = switch (mode) {
      WithdrawalMode.percentage || WithdrawalMode.fixed => (
          math.max(1000, recommendedMonthly(portfolio) * 0.4),
          math.max(20000, recommendedMonthly(portfolio) * 2.5),
        ),
      WithdrawalMode.profitOnly => () {
        final maxMonthly = (portfolio * annualReturn) / 12;
        return (maxMonthly * 0.3, maxMonthly);
      }(),
      WithdrawalMode.dividendOnly => () {
        final maxMonthly = (portfolio * _dividendYield) / 12;
        return (maxMonthly * 0.3, maxMonthly);
      }(),
    };

    return _normalizeSliderRange(range.$1.toDouble(), range.$2.toDouble());
  }

  static (double min, double max) _normalizeSliderRange(double min, double max) {
    if (max <= 0) return (0, 1000);
    if (min >= max) return (max * 0.5, max);
    return (min, max);
  }

  static WithdrawalSimulation simulate(WithdrawalPlan plan) {
    final recommended = recommendedMonthly(plan.portfolio);

    var balance = plan.portfolio;
    var age = plan.currentAge;
    var cumulativeWithdrawn = 0.0;
    final timeline = <WithdrawalTimelineEntry>[];
    final chartPoints = <WithdrawalChartPoint>[
      WithdrawalChartPoint(
        age: age,
        portfolio: balance,
        cumulativeWithdrawal: 0,
      ),
    ];

    var depletedAge = plan.lifeExpectancyAge + 5;
    final maxAge = plan.lifeExpectancyAge + 10;
    double? projectedFirstYearWithdrawal;
    var principalRemaining = plan.principal;

    for (var year = 0; age <= maxAge && balance > 0; year++) {
      if (plan.simulateMarketCrash && age == plan.currentAge + 3) {
        balance *= 0.72;
        timeline.add(
          WithdrawalTimelineEntry(
            age: age,
            withdrawal: 0,
            balance: balance,
            event: 'วิกฤติ -28%',
          ),
        );
      } else if (plan.simulateMarketCrash && age == plan.currentAge + 4) {
        timeline.add(
          WithdrawalTimelineEntry(
            age: age,
            withdrawal: 0,
            balance: balance,
            event: 'ใช้เงินสด ไม่ขายหุ้น',
          ),
        );
      }

      balance *= (1 + plan.annualReturn);

      final annualWithdrawal = plan.mode == WithdrawalMode.profitOnly
          ? _profitOnlyWithdrawal(plan, balance, principalRemaining, year)
          : _annualWithdrawal(plan, balance, year);
      final actualWithdrawal = math.min(annualWithdrawal, balance);
      balance -= actualWithdrawal;
      cumulativeWithdrawn += actualWithdrawal;
      projectedFirstYearWithdrawal ??= actualWithdrawal;

      String? event;
      if (plan.simulateMarketCrash && age == plan.currentAge + 5) {
        event = 'ตลาดฟื้น';
      }

      timeline.add(
        WithdrawalTimelineEntry(
          age: age,
          withdrawal: actualWithdrawal,
          balance: balance,
          event: event,
        ),
      );

      chartPoints.add(
        WithdrawalChartPoint(
          age: age + 1,
          portfolio: balance.clamp(0, double.infinity),
          cumulativeWithdrawal: cumulativeWithdrawn,
        ),
      );

      if (balance <= 0) {
        depletedAge = age;
        break;
      }

      age++;
    }

    if (balance > 0) {
      depletedAge = age;
    }

    final lastsUntilAge = depletedAge;
    final profit = math.max(0, plan.portfolio - plan.principal).toDouble();
    final sources = _withdrawalSources(plan.monthlyWithdrawal);
    final cashReserveMonths = plan.monthlyWithdrawal > 0
        ? (plan.cashReserve / plan.monthlyWithdrawal).toDouble()
        : 0.0;
    final annualProfitEstimate = plan.portfolio * plan.annualReturn;
    final withdrawalRatePercent = plan.portfolio > 0
        ? ((projectedFirstYearWithdrawal ?? 0) / plan.portfolio) * 100.0
        : 0.0;
    final successProbability = _successProbability(
      lastsUntilAge: lastsUntilAge,
      targetAge: plan.lifeExpectancyAge,
      withdrawalRatePercent: withdrawalRatePercent,
    );
    final safety = _safetyLevel(lastsUntilAge, plan.lifeExpectancyAge);
    final starRating = _starRating(successProbability);

    return WithdrawalSimulation(
      lastsUntilAge: lastsUntilAge,
      successProbability: successProbability,
      safety: safety,
      starRating: starRating,
      recommendedMonthly: recommended,
      withdrawalRatePercent: withdrawalRatePercent,
      timeline: timeline.take(8).toList(),
      chartPoints: chartPoints,
      principal: plan.principal,
      profit: profit,
      totalWithdrawn: 0,
      remaining: plan.portfolio,
      projectedFirstYearWithdrawal: projectedFirstYearWithdrawal ?? 0,
      simulationStartAge: plan.currentAge,
      sources: sources,
      cashReserveMonths: cashReserveMonths,
      aiInsight: _aiInsight(plan, safety, lastsUntilAge),
      annualProfitEstimate: annualProfitEstimate,
    );
  }

  static double _profitOnlyWithdrawal(
    WithdrawalPlan plan,
    double balance,
    double principalRemaining,
    int year,
  ) {
    final inflatedMonthly =
        plan.monthlyWithdrawal * math.pow(1 + plan.inflation, year).toDouble();
    final gainAvailable = math.max(0, balance - principalRemaining);
    return math.min(inflatedMonthly * 12, gainAvailable).toDouble();
  }

  static double _annualWithdrawal(WithdrawalPlan plan, double balance, int year) {
    final inflatedMonthly =
        plan.monthlyWithdrawal * math.pow(1 + plan.inflation, year).toDouble();
    final dividendYield = plan.realDividendAnnual > 0 && plan.portfolio > 0
        ? plan.realDividendAnnual / plan.portfolio
        : _dividendYield;

    switch (plan.mode) {
      case WithdrawalMode.percentage:
        return balance * plan.withdrawalRate;
      case WithdrawalMode.fixed:
        return inflatedMonthly * 12;
      case WithdrawalMode.profitOnly:
        return inflatedMonthly * 12;
      case WithdrawalMode.dividendOnly:
        return math.min(balance * dividendYield, inflatedMonthly * 12).toDouble();
    }
  }

  static double _successProbability({
    required int lastsUntilAge,
    required int targetAge,
    required double withdrawalRatePercent,
  }) {
    if (lastsUntilAge >= targetAge + 1) {
      return math.min(0.98, 0.88 + (targetAge - 90) * 0.01 + (4.5 - withdrawalRatePercent) * 0.02);
    }

    final yearsShort = targetAge - lastsUntilAge;
    final ratePenalty = math.max(0, withdrawalRatePercent - 4) * 0.04;
    return math.max(0.15, 0.85 - yearsShort * 0.08 - ratePenalty);
  }

  static SafetyLevel _safetyLevel(int lastsUntilAge, int targetAge) {
    if (lastsUntilAge >= targetAge) return SafetyLevel.safe;
    if (lastsUntilAge >= targetAge - 8) return SafetyLevel.warning;
    return SafetyLevel.critical;
  }

  static int _starRating(double probability) {
    if (probability >= 0.95) return 5;
    if (probability >= 0.85) return 4;
    if (probability >= 0.70) return 3;
    if (probability >= 0.50) return 2;
    return 1;
  }

  static List<WithdrawalSourceRecommendation> _withdrawalSources(
    double monthlyWithdrawal,
  ) {
    final gold = monthlyWithdrawal * 0.17;
    final income = monthlyWithdrawal * 0.32;
    final cash = monthlyWithdrawal - gold - income;

    return [
      const WithdrawalSourceRecommendation(
        name: 'VT',
        amount: 0,
        recommended: false,
      ),
      const WithdrawalSourceRecommendation(
        name: 'Microsoft',
        amount: 0,
        recommended: false,
      ),
      const WithdrawalSourceRecommendation(
        name: 'Bitcoin',
        amount: 0,
        recommended: false,
      ),
      WithdrawalSourceRecommendation(
        name: 'Gold',
        amount: gold,
        recommended: true,
      ),
      WithdrawalSourceRecommendation(
        name: 'SCHD',
        amount: income,
        recommended: true,
      ),
      WithdrawalSourceRecommendation(
        name: 'เงินสด',
        amount: cash,
        recommended: true,
      ),
    ];
  }

  static String? _aiInsight(
    WithdrawalPlan plan,
    SafetyLevel safety,
    int lastsUntilAge,
  ) {
    if (plan.simulateMarketCrash) {
      if (safety == SafetyLevel.critical) {
        return 'ตลาดลง 25% — แนะนำลดการถอน 10% เป็นเวลา 2 ปี เพื่อเพิ่มโอกาสอยู่ถึง ${plan.lifeExpectancyAge + 1} ปี';
      }
      return 'ตลาดลง 20% — ลดการถอนชั่วคราว 10% เป็นเวลา 2 ปี จะช่วยให้เงินอยู่ถึงอายุ ${plan.lifeExpectancyAge} ปี';
    }

    if (safety == SafetyLevel.warning) {
      return 'อัตราการถอนสูงกว่าแผน — ลองลดลง 10% หรือถอนเฉพาะกำไรเพื่อยืดอายุพอร์ต';
    }

    if (lastsUntilAge >= plan.lifeExpectancyAge) {
      return 'แผนถอนเงินปัจจุบันปลอดภัย — เงินน่าจะอยู่ได้ถึงอายุ $lastsUntilAge ปี';
    }

    return null;
  }

  static bool isGrowthAsset(String symbol) => _growthAssets.contains(symbol);
}
