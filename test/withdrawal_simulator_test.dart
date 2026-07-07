import 'package:flutter_test/flutter_test.dart';
import 'package:port_invest/data/models/withdrawal_models.dart';
import 'package:port_invest/data/services/withdrawal_simulator.dart';

WithdrawalPlan _plan({
  required double portfolio,
  required double monthlyWithdrawal,
  double withdrawalRate = 0.04,
  WithdrawalMode mode = WithdrawalMode.percentage,
}) {
  return WithdrawalPlan(
    portfolio: portfolio,
    principal: portfolio * 0.7,
    currentAge: 61,
    lifeExpectancyAge: 96,
    monthlyWithdrawal: monthlyWithdrawal,
    annualReturn: 0.07,
    inflation: 0.03,
    cashReserve: monthlyWithdrawal * 26,
    mode: mode,
    withdrawalRate: withdrawalRate,
  );
}

void main() {
  test('percentage mode scales simulation with effective withdrawal rate', () {
    const portfolio = 14000000.0;
    final lowRate = (25000 * 12 / portfolio);
    final highRate = (80000 * 12 / portfolio);

    final conservative = WithdrawalSimulator.simulate(
      _plan(
        portfolio: portfolio,
        monthlyWithdrawal: 25000,
        withdrawalRate: lowRate,
      ),
    );
    final aggressive = WithdrawalSimulator.simulate(
      _plan(
        portfolio: portfolio,
        monthlyWithdrawal: 80000,
        withdrawalRate: highRate,
      ),
    );

    expect(
      conservative.projectedFirstYearWithdrawal,
      lessThan(aggressive.projectedFirstYearWithdrawal),
    );
    expect(
      conservative.withdrawalRatePercent,
      lessThan(aggressive.withdrawalRatePercent),
    );
    expect(
      conservative.successProbability,
      greaterThanOrEqualTo(aggressive.successProbability),
    );
  });

  test('fixed mode follows monthly withdrawal amount', () {
    const portfolio = 14000000.0;

    final low = WithdrawalSimulator.simulate(
      _plan(
        portfolio: portfolio,
        monthlyWithdrawal: 25000,
        mode: WithdrawalMode.fixed,
      ),
    );
    final high = WithdrawalSimulator.simulate(
      _plan(
        portfolio: portfolio,
        monthlyWithdrawal: 80000,
        mode: WithdrawalMode.fixed,
      ),
    );

    expect(low.lastsUntilAge, greaterThan(high.lastsUntilAge));
  });

  test('withdrawal modes produce different first-year amounts', () {
    const portfolio = 10000000.0;
    final percentage = WithdrawalSimulator.simulate(
      _plan(
        portfolio: portfolio,
        monthlyWithdrawal: WithdrawalSimulator.modeDefaultMonthly(
          portfolio,
          WithdrawalMode.percentage,
        ),
        withdrawalRate: 0.04,
        mode: WithdrawalMode.percentage,
      ),
    );
    final profitOnly = WithdrawalSimulator.simulate(
      _plan(
        portfolio: portfolio,
        monthlyWithdrawal: WithdrawalSimulator.modeDefaultMonthly(
          portfolio,
          WithdrawalMode.profitOnly,
        ),
        mode: WithdrawalMode.profitOnly,
      ),
    );
    final dividendOnly = WithdrawalSimulator.simulate(
      _plan(
        portfolio: portfolio,
        monthlyWithdrawal: WithdrawalSimulator.modeDefaultMonthly(
          portfolio,
          WithdrawalMode.dividendOnly,
        ),
        mode: WithdrawalMode.dividendOnly,
      ),
    );

    expect(
      profitOnly.projectedFirstYearWithdrawal,
      greaterThan(dividendOnly.projectedFirstYearWithdrawal),
    );
    expect(
      percentage.projectedFirstYearWithdrawal,
      greaterThan(dividendOnly.projectedFirstYearWithdrawal),
    );
  });

  test('dividend slider range keeps min below max for small portfolios', () {
    const portfolio = 800000.0;
    final (min, max) = WithdrawalSimulator.modeSliderRange(
      portfolio,
      WithdrawalMode.dividendOnly,
    );

    expect(min, lessThan(max));
    expect(max, closeTo(portfolio * 0.04 / 12, 1));
  });
}
