import 'package:flutter_test/flutter_test.dart';
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
          targetAllocation: 0.4182,
        ),
        RealAssetProfit(
          symbol: 'KKP_NDQ',
          name: 'KKP',
          valueThb: 2455,
          costThb: 2000,
          profitThb: 455,
          estimatedAnnualDividendThb: 0,
          targetAllocation: 0.2455,
        ),
      ],
    );

    final lines = RealWithdrawalService.splitByDcaTarget(real, 1000);

    expect(lines.length, 2);
    expect(lines.first.name, 'VT');
    expect(lines.first.monthlyAmount, closeTo(418.2, 0.1));
    expect(
      lines.fold<double>(0, (sum, line) => sum + line.monthlyAmount),
      closeTo(663.7, 1),
    );
  });
}
