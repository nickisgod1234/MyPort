import 'package:flutter_test/flutter_test.dart';
import 'package:port_invest/data/services/rebalance_calculator.dart';

void main() {
  test('uses fixed DCA when allocation drift is within 5%', () {
    const inputs = [
      RebalanceCalculatorInput(
        symbol: 'VT',
        name: 'VT',
        targetPercent: 0.5,
        currentValue: 4800,
      ),
      RebalanceCalculatorInput(
        symbol: 'KKP',
        name: 'KKP',
        targetPercent: 0.5,
        currentValue: 5200,
      ),
    ];

    final plan = RebalanceCalculator.calculate(
      assets: inputs,
      monthlyBudget: 10000,
    );

    expect(plan.rows[0].differencePercent, closeTo(-2, 0.1));
    expect(plan.rows[0].buyAmount, closeTo(5000, 0.01));
    expect(plan.rows[1].buyAmount, closeTo(5000, 0.01));
    expect(plan.totalBuy, closeTo(10000, 0.01));
  });

  test('rebalances only assets outside 5% drift', () {
    const inputs = [
      RebalanceCalculatorInput(
        symbol: 'VT',
        name: 'VT',
        targetPercent: 0.4,
        currentValue: 4200,
      ),
      RebalanceCalculatorInput(
        symbol: 'KKP',
        name: 'KKP',
        targetPercent: 0.3,
        currentValue: 2000,
      ),
      RebalanceCalculatorInput(
        symbol: 'SMH',
        name: 'SMH',
        targetPercent: 0.3,
        currentValue: 3800,
      ),
    ];

    final plan = RebalanceCalculator.calculate(
      assets: inputs,
      monthlyBudget: 10000,
    );

    expect(plan.rows[0].differencePercent.abs(), lessThanOrEqualTo(5));
    expect(plan.rows[0].buyAmount, closeTo(4000, 0.01));
    expect(plan.rows[1].differencePercent.abs(), greaterThan(5));
    expect(plan.rows[2].differencePercent.abs(), greaterThan(5));
    expect(plan.totalBuy, closeTo(10000, 0.01));
  });
}
