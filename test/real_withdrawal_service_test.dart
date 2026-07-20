import 'package:flutter_test/flutter_test.dart';
import 'package:port_invest/data/models/portfolio_models.dart';
import 'package:port_invest/data/models/real_withdrawal_models.dart';
import 'package:port_invest/data/services/real_withdrawal_service.dart';

void main() {
  test('splitByDcaTarget allocates monthly withdrawal by DCA targets', () {
    const real = RealWithdrawalSnapshot(
      portfolioValue: 10000,
      principal: 8000,
      profit: 2000,
      returnPercent: 25,
      annualDividendEstimate: 0,
      profitOnlyMaxMonthly: 2000 / 12,
      dividendOnlyMaxMonthly: 0,
      recommendedMonthly4Pct: 10000 * 0.04 / 12,
      trackedAssetCount: 1,
      assets: [
        RealAssetProfit(
          symbol: 'VT',
          name: 'VT',
          valueThb: 4182,
          costThb: 3000,
          profitThb: 1182,
          estimatedAnnualDividendThb: 0,
          targetAllocation: 0.60,
        ),
        RealAssetProfit(
          symbol: 'KKP_NDQ',
          name: 'KKP',
          valueThb: 2455,
          costThb: 2000,
          profitThb: 455,
          estimatedAnnualDividendThb: 0,
          targetAllocation: 0.40,
        ),
      ],
    );

    final lines = RealWithdrawalService.splitByDcaTarget(real, 1000);

    expect(lines.length, 2);
    expect(lines.first.name, 'VT');
    expect(lines.first.monthlyAmount, closeTo(600, 0.1));
    expect(
      lines.fold<double>(0, (sum, line) => sum + line.monthlyAmount),
      closeTo(1000, 0.1),
    );
  });

  test('fromSummary keeps target allocation from holdings', () {
    final summary = PortfolioSummary(
      totalValueThb: 10000,
      totalInvestedThb: 8000,
      totalProfitThb: 2000,
      totalReturnPercent: 25,
      holdings: const [
        HoldingValue(
          holding: Holding(
            symbol: 'VOO',
            displayName: 'VOO',
            shares: 1,
            averageCost: 5000,
            targetAllocation: 0.35,
            isThaiFund: false,
          ),
          currentPrice: 6000,
          marketValueThb: 6000,
          marketValueUsd: null,
          profitThb: 1000,
          returnPercent: 20,
          allocation: 0.60,
          isLive: false,
        ),
        HoldingValue(
          holding: Holding(
            symbol: 'SCHD',
            displayName: 'SCHD',
            shares: 1,
            averageCost: 3000,
            targetAllocation: 0.10,
            isThaiFund: false,
          ),
          currentPrice: 4000,
          marketValueThb: 4000,
          marketValueUsd: null,
          profitThb: 1000,
          returnPercent: 33.33,
          allocation: 0.40,
          isLive: false,
        ),
      ],
    );

    final real = RealWithdrawalService.fromSummary(
      summary,
      costBasisValues: const {'VOO': 5000, 'SCHD': 3000},
    );

    expect(real.assets[0].targetAllocation, closeTo(0.35, 0.0001));
    expect(real.assets[1].targetAllocation, closeTo(0.10, 0.0001));
    expect(real.trackedAssetCount, 2);
  });
}
