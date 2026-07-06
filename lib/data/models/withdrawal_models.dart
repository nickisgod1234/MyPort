enum WithdrawalMode {
  percentage,
  fixed,
  profitOnly,
  dividendOnly,
}

enum SafetyLevel {
  safe,
  warning,
  critical,
}

class WithdrawalPlan {
  const WithdrawalPlan({
    required this.portfolio,
    required this.principal,
    required this.currentAge,
    required this.lifeExpectancyAge,
    required this.monthlyWithdrawal,
    required this.annualReturn,
    required this.inflation,
    required this.cashReserve,
    required this.mode,
    this.withdrawalRate = 0.04,
    this.simulateMarketCrash = false,
  });

  final double portfolio;
  final double principal;
  final int currentAge;
  final int lifeExpectancyAge;
  final double monthlyWithdrawal;
  final double annualReturn;
  final double inflation;
  final double cashReserve;
  final WithdrawalMode mode;
  final double withdrawalRate;
  final bool simulateMarketCrash;
}

class WithdrawalSourceRecommendation {
  const WithdrawalSourceRecommendation({
    required this.name,
    required this.amount,
    required this.recommended,
  });

  final String name;
  final double amount;
  final bool recommended;
}

class WithdrawalTimelineEntry {
  const WithdrawalTimelineEntry({
    required this.age,
    required this.withdrawal,
    required this.balance,
    this.event,
  });

  final int age;
  final double withdrawal;
  final double balance;
  final String? event;
}

class WithdrawalChartPoint {
  const WithdrawalChartPoint({
    required this.age,
    required this.portfolio,
    required this.cumulativeWithdrawal,
  });

  final int age;
  final double portfolio;
  final double cumulativeWithdrawal;
}

class WithdrawalSimulation {
  const WithdrawalSimulation({
    required this.lastsUntilAge,
    required this.successProbability,
    required this.safety,
    required this.starRating,
    required this.recommendedMonthly,
    required this.withdrawalRatePercent,
    required this.timeline,
    required this.chartPoints,
    required this.principal,
    required this.profit,
    required this.totalWithdrawn,
    required this.remaining,
    required this.sources,
    required this.cashReserveMonths,
    required this.aiInsight,
    required this.annualProfitEstimate,
  });

  final int lastsUntilAge;
  final double successProbability;
  final SafetyLevel safety;
  final int starRating;
  final double recommendedMonthly;
  final double withdrawalRatePercent;
  final List<WithdrawalTimelineEntry> timeline;
  final List<WithdrawalChartPoint> chartPoints;
  final double principal;
  final double profit;
  final double totalWithdrawn;
  final double remaining;
  final List<WithdrawalSourceRecommendation> sources;
  final double cashReserveMonths;
  final String? aiInsight;
  final double annualProfitEstimate;
}
