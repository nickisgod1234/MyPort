import 'dart:math' as math;

import '../models/withdrawal_models.dart';

class WithdrawalSimulator {
  static const _dividendYield = 0.04;
  static const _growthAssets = {'VT', 'MSFT', 'BTCUSD', 'RKLB', 'KKP_NDQ', 'TLSEMICON'};

  static double recommendedMonthly(double portfolio, {double rate = 0.04}) {
    return (portfolio * rate) / 12;
  }

  static WithdrawalSimulation simulate(WithdrawalPlan plan) {
    final recommended = recommendedMonthly(plan.portfolio);
    final withdrawalRatePercent = plan.portfolio > 0
        ? (plan.monthlyWithdrawal * 12 / plan.portfolio) * 100.0
        : 0.0;

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

      final annualWithdrawal = _annualWithdrawal(plan, balance, year);
      final actualWithdrawal = math.min(annualWithdrawal, balance);
      balance -= actualWithdrawal;
      cumulativeWithdrawn += actualWithdrawal;

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
    final successProbability = _successProbability(
      lastsUntilAge: lastsUntilAge,
      targetAge: plan.lifeExpectancyAge,
      withdrawalRatePercent: withdrawalRatePercent,
    );
    final safety = _safetyLevel(lastsUntilAge, plan.lifeExpectancyAge);
    final starRating = _starRating(successProbability);
    final profit = math.max(0, plan.portfolio - plan.principal).toDouble();
    final sources = _withdrawalSources(plan.monthlyWithdrawal);
    final cashReserveMonths = plan.monthlyWithdrawal > 0
        ? (plan.cashReserve / plan.monthlyWithdrawal).toDouble()
        : 0.0;
    final annualProfitEstimate = plan.portfolio * plan.annualReturn;

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
      totalWithdrawn: cumulativeWithdrawn,
      remaining: math.max(0, plan.portfolio - cumulativeWithdrawn).toDouble(),
      sources: sources,
      cashReserveMonths: cashReserveMonths,
      aiInsight: _aiInsight(plan, safety, lastsUntilAge),
      annualProfitEstimate: annualProfitEstimate,
    );
  }

  static double _annualWithdrawal(WithdrawalPlan plan, double balance, int year) {
    final inflatedMonthly =
        plan.monthlyWithdrawal * math.pow(1 + plan.inflation, year).toDouble();

    switch (plan.mode) {
      case WithdrawalMode.percentage:
        return balance * plan.withdrawalRate;
      case WithdrawalMode.fixed:
        return inflatedMonthly * 12;
      case WithdrawalMode.profitOnly:
        final profit = balance * plan.annualReturn;
        return math.min(inflatedMonthly * 12, profit).toDouble();
      case WithdrawalMode.dividendOnly:
        return math.min(balance * _dividendYield, inflatedMonthly * 12).toDouble();
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
