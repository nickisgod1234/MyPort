class RealAssetProfit {
  const RealAssetProfit({
    required this.symbol,
    required this.name,
    required this.valueThb,
    required this.costThb,
    required this.profitThb,
    required this.estimatedAnnualDividendThb,
    required this.targetAllocation,
  });

  final String symbol;
  final String name;
  final double valueThb;
  final double costThb;
  final double profitThb;
  final double estimatedAnnualDividendThb;
  final double targetAllocation;
}

class WithdrawalAllocationLine {
  const WithdrawalAllocationLine({
    required this.name,
    required this.targetPercent,
    required this.monthlyAmount,
    required this.currentValueThb,
  });

  final String name;
  final double targetPercent;
  final double monthlyAmount;
  final double currentValueThb;
}

class RealWithdrawalSnapshot {
  const RealWithdrawalSnapshot({
    required this.portfolioValue,
    required this.principal,
    required this.profit,
    required this.returnPercent,
    required this.annualDividendEstimate,
    required this.profitOnlyMaxMonthly,
    required this.dividendOnlyMaxMonthly,
    required this.recommendedMonthly4Pct,
    required this.assets,
    required this.trackedAssetCount,
  });

  final double portfolioValue;
  final double principal;
  final double profit;
  final double returnPercent;
  final double annualDividendEstimate;
  final double profitOnlyMaxMonthly;
  final double dividendOnlyMaxMonthly;
  final double recommendedMonthly4Pct;
  final List<RealAssetProfit> assets;
  final int trackedAssetCount;

  bool get hasProfit => profit > 0;

  bool get hasCostBasis => trackedAssetCount > 0;

  double get profitRatio =>
      portfolioValue > 0 ? (profit / portfolioValue).clamp(0.0, 1.0) : 0.0;

  double get dividendYieldRatio => portfolioValue > 0
      ? (annualDividendEstimate / portfolioValue).clamp(0.0, 1.0)
      : 0.0;
}
