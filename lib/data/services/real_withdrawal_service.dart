import 'dart:math' as math;

import '../models/portfolio_models.dart';
import '../models/real_withdrawal_models.dart';
import '../models/withdrawal_models.dart';

class RealWithdrawalService {
  /// ประมาณ dividend yield ต่อปีของแต่ละสินทรัพย์ (จากมูลค่าปัจจุบัน)
  static const _dividendYieldBySymbol = <String, double>{
    'VT': 0.015,
    'VTI': 0.013,
    'KKP_NDQ': 0.0,
    'SMH': 0.008,
    'SCHG': 0.0,
    'SCHD': 0.035,
    'TLSEMICON': 0.0,
    'MTS_GOLD': 0.0,
    'RKLB': 0.0,
    'BTCUSD': 0.0,
  };

  static RealWithdrawalSnapshot fromSummary(
    PortfolioSummary summary, {
    Map<String, double> previousValues = const {},
  }) {
    final assets = <RealAssetProfit>[];
    var annualDividend = 0.0;

    for (final hv in summary.holdings) {
      final symbol = hv.holding.symbol;
      final yield = _dividendYieldBySymbol[symbol] ?? 0.0;
      final dividend = hv.marketValueThb * yield;
      annualDividend += dividend;

      assets.add(
        RealAssetProfit(
          targetAllocation: previousValues[symbol] ?? 0.0,
          symbol: symbol,
          name: hv.holding.name,
          valueThb: hv.marketValueThb,
          costThb: hv.holding.investedThb,
          profitThb: hv.profitThb,
          estimatedAnnualDividendThb: dividend,
        ),
      );
    }

    final portfolio = summary.totalValueThb;
    final principal = summary.totalInvestedThb;
    final profit = summary.totalProfitThb;
    final profitForWithdrawal = profit > 0 ? profit : 0.0;
    final recommendedMonthly4Pct = portfolio > 0 ? (portfolio * 0.04) / 12 : 0.0;

    return RealWithdrawalSnapshot(
      portfolioValue: portfolio,
      principal: principal,
      profit: profit,
      returnPercent: summary.totalReturnPercent,
      annualDividendEstimate: annualDividend,
      profitOnlyMaxMonthly: profitForWithdrawal / 12,
      dividendOnlyMaxMonthly: annualDividend / 12,
      recommendedMonthly4Pct: recommendedMonthly4Pct,
      assets: assets,
      trackedAssetCount: previousValues.length,
    );
  }

  static double annualWithdrawalRatePercent(
    RealWithdrawalSnapshot real,
    double monthlyWithdrawal,
  ) {
    if (real.portfolioValue <= 0) return 0;
    return (monthlyWithdrawal * 12 / real.portfolioValue) * 100;
  }

  static List<WithdrawalAllocationLine> splitByDcaTarget(
    RealWithdrawalSnapshot real,
    double monthlyTotal,
  ) {
    return real.assets
        .where((asset) => asset.targetAllocation > 0)
        .map(
          (asset) => WithdrawalAllocationLine(
            name: asset.name,
            targetPercent: asset.targetAllocation,
            monthlyAmount: monthlyTotal * asset.targetAllocation,
            currentValueThb: asset.valueThb,
          ),
        )
        .toList()
      ..sort((a, b) => b.monthlyAmount.compareTo(a.monthlyAmount));
  }

  static double effectiveMonthly(
    RealWithdrawalSnapshot real,
    WithdrawalMode mode,
    double targetMonthly,
  ) {
    return switch (mode) {
      WithdrawalMode.percentage || WithdrawalMode.fixed => targetMonthly,
      WithdrawalMode.profitOnly =>
        math.min(targetMonthly, real.profitOnlyMaxMonthly),
      WithdrawalMode.dividendOnly =>
        math.min(targetMonthly, real.dividendOnlyMaxMonthly),
    };
  }
}
