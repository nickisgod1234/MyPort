class RebalanceRow {
  const RebalanceRow({
    required this.symbol,
    required this.name,
    required this.targetPercent,
    required this.currentValue,
    required this.currentPercent,
    required this.differencePercent,
    required this.buyAmount,
    required this.status,
  });

  final String symbol;
  final String name;
  final double targetPercent;
  final double currentValue;
  final double currentPercent;
  /// สัดส่วนปัจจุบัน − เป้าหมาย (หน่วย % เช่น 0.5 = 0.5%)
  final double differencePercent;
  final double buyAmount;
  final RebalanceRowStatus status;
}

enum RebalanceRowStatus { normal, under, over }

class RebalancePlan {
  const RebalancePlan({
    required this.rows,
    required this.totalPortfolio,
    required this.monthlyBudget,
    required this.totalAfterInvest,
    required this.totalBuy,
  });

  final List<RebalanceRow> rows;
  final double totalPortfolio;
  final double monthlyBudget;
  final double totalAfterInvest;
  final double totalBuy;
}

class RebalanceCalculatorInput {
  const RebalanceCalculatorInput({
    required this.symbol,
    required this.name,
    required this.targetPercent,
    required this.currentValue,
  });

  final String symbol;
  final String name;
  final double targetPercent;
  final double currentValue;
}

class RebalanceCalculator {
  static const tolerancePercent = 1.0;

  static RebalancePlan calculate({
    required List<RebalanceCalculatorInput> assets,
    required double monthlyBudget,
  }) {
    final total =
        assets.fold(0.0, (sum, asset) => sum + asset.currentValue);
    final newTotal = total + monthlyBudget;

    final rawBuys = <double>[];
    final rows = <RebalanceRow>[];

    for (final asset in assets) {
      final currentPct = total > 0 ? (asset.currentValue / total) * 100 : 0;
      final targetPct = asset.targetPercent * 100;
      final diff = currentPct - targetPct;

      final idealBuy =
          (newTotal * asset.targetPercent - asset.currentValue).clamp(0.0, double.infinity);
      rawBuys.add(idealBuy);

      rows.add(
        RebalanceRow(
          symbol: asset.symbol,
          name: asset.name,
          targetPercent: asset.targetPercent,
          currentValue: asset.currentValue,
          currentPercent: currentPct / 100,
          differencePercent: diff,
          buyAmount: 0,
          status: _status(diff, idealBuy),
        ),
      );
    }

  final sumIdeal = rawBuys.fold(0.0, (a, b) => a + b);
    final buyAmounts = <double>[];

    if (sumIdeal > 0) {
      for (final ideal in rawBuys) {
        buyAmounts.add(monthlyBudget * (ideal / sumIdeal));
      }
    } else {
      for (final asset in assets) {
        buyAmounts.add(monthlyBudget * asset.targetPercent);
      }
    }

    final adjustedRows = <RebalanceRow>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      adjustedRows.add(
        RebalanceRow(
          symbol: row.symbol,
          name: row.name,
          targetPercent: row.targetPercent,
          currentValue: row.currentValue,
          currentPercent: row.currentPercent,
          differencePercent: row.differencePercent,
          buyAmount: buyAmounts[i],
          status: row.status,
        ),
      );
    }

    final totalBuy = buyAmounts.fold(0.0, (a, b) => a + b);

    return RebalancePlan(
      rows: adjustedRows,
      totalPortfolio: total,
      monthlyBudget: monthlyBudget,
      totalAfterInvest: newTotal,
      totalBuy: totalBuy,
    );
  }

  static RebalanceRowStatus _status(double diffPercent, double idealBuy) {
    if (idealBuy <= 0 && diffPercent > tolerancePercent) {
      return RebalanceRowStatus.over;
    }
    if (diffPercent.abs() <= tolerancePercent) {
      return RebalanceRowStatus.normal;
    }
    return RebalanceRowStatus.under;
  }
}
