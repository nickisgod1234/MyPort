import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../models/portfolio_models.dart';
import '../models/quote.dart';
import 'fmp_api_service.dart';
import 'storage_service.dart';

class PortfolioService {
  PortfolioService(this._fmp, this._storage);

  final FmpApiService _fmp;
  final StorageService _storage;

  Future<PortfolioSummary> getSummary() async {
    return _buildSummaryFromDca();
  }

  PortfolioSummary _buildSummaryFromDca() {
    final savedValues = _storage.getDcaAssetValues();
    final previousValues = _storage.getDcaAssetPreviousValues();

    final holdings = <HoldingValue>[];
    var totalValueThb = 0.0;
    var totalInvestedThb = 0.0;

    for (final asset in AppConstants.dcaCalculatorAssets) {
      final symbol = asset['symbol'] as String;
      final name = asset['name'] as String;
      final defaultValue = (asset['defaultValue'] as num).toDouble();
      final target = (asset['target'] as num).toDouble();

      final valueThb = savedValues[symbol] ?? defaultValue;
      final previous = previousValues[symbol];
      // ไม่มีค่า 'ก่อนหน้า' = ถือว่าทุนเท่ามูลค่าปัจจุบัน (กำไร 0)
      final costThb = previous ?? valueThb;
      final profitThb = valueThb - costThb;
      final returnPct = costThb > 0 ? (profitThb / costThb) * 100 : 0.0;

      totalValueThb += valueThb;
      totalInvestedThb += costThb;

      holdings.add(
        HoldingValue(
          holding: Holding(
            symbol: symbol,
            displayName: name,
            shares: 1,
            averageCost: costThb,
            targetAllocation: target,
            isThaiFund: true,
            fixedValueThb: valueThb,
            fixedCostThb: costThb,
          ),
          currentPrice: valueThb,
          marketValueThb: valueThb,
          marketValueUsd: null,
          profitThb: profitThb,
          returnPercent: returnPct,
          allocation: 0,
          isLive: false,
        ),
      );
    }

    for (var i = 0; i < holdings.length; i++) {
      final hv = holdings[i];
      holdings[i] = HoldingValue(
        holding: hv.holding,
        currentPrice: hv.currentPrice,
        marketValueThb: hv.marketValueThb,
        marketValueUsd: hv.marketValueUsd,
        profitThb: hv.profitThb,
        returnPercent: hv.returnPercent,
        allocation:
            totalValueThb > 0 ? hv.marketValueThb / totalValueThb : 0,
        isLive: hv.isLive,
      );
    }

    final totalProfitThb = totalValueThb - totalInvestedThb;
    final totalReturn = totalInvestedThb > 0
        ? (totalProfitThb / totalInvestedThb) * 100
        : 0.0;

    return PortfolioSummary(
      totalValueThb: totalValueThb,
      totalInvestedThb: totalInvestedThb,
      totalProfitThb: totalProfitThb,
      totalReturnPercent: totalReturn,
      holdings: holdings,
    );
  }

  List<DcaAllocation> calculateDca(double monthlyBudget) {
    return AppConstants.targetAllocations.entries.map((e) {
      return DcaAllocation(
        symbol: e.key,
        displayName: AppConstants.assetDisplayNames[e.key] ?? e.key,
        amount: monthlyBudget * e.value,
        isRecommended: true,
      );
    }).toList();
  }

  Future<PortfolioAnalysis> analyzePortfolio() async {
    final summary = await getSummary();
    final suggestions = <RebalanceSuggestion>[];

    for (final hv in summary.holdings) {
      final target = hv.holding.targetAllocation;
      final actual = hv.allocation;
      final diff = actual - target;
      final displayName = AppConstants.assetDisplayNames[hv.holding.symbol] ??
          hv.holding.name;

      if (diff > 0.05) {
        suggestions.add(
          RebalanceSuggestion(
            symbol: hv.holding.symbol,
            displayName: displayName,
            status: RebalanceStatus.over,
            message: 'สูงเกินเป้า',
          ),
        );
      } else if (diff < -0.03) {
        final amount = (target - actual) * summary.totalValueThb;
        suggestions.add(
          RebalanceSuggestion(
            symbol: hv.holding.symbol,
            displayName: displayName,
            status: RebalanceStatus.under,
            message: 'ต่ำกว่าเป้า — เพิ่มอีก',
            suggestedAmount: amount > 0 ? amount : 900,
          ),
        );
      } else {
        suggestions.add(
          RebalanceSuggestion(
            symbol: hv.holding.symbol,
            displayName: displayName,
            status: RebalanceStatus.ok,
            message: 'อยู่ในเป้าหมาย',
          ),
        );
      }
    }

    var score = 100;
    for (final s in suggestions) {
      if (s.status == RebalanceStatus.over) score -= 2;
      if (s.status == RebalanceStatus.under) score -= 1;
    }

    return PortfolioAnalysis(
      score: score.clamp(70, 100),
      suggestions: suggestions,
      sharpe: 1.42,
      beta: 0.89,
      maxDrawdown: -12.4,
      volatility: 14.2,
    );
  }

  RetirementProjection getRetirementProjection(double currentAmountThb) {
    final currentAge = _storage.currentAge;
    final retirementAge = _storage.retirementAge;
    final target = _storage.targetAmount;
    final progress = target > 0 ? (currentAmountThb / target).clamp(0.0, 1.0) : 0.0;

    final yearsToRetirement = retirementAge - currentAge;
    final monthlyReturn = 0.007;
    final monthlyContribution = _storage.monthlyBudget;
    var projected = currentAmountThb;
    var months = 0;
    final maxMonths = yearsToRetirement * 12 + 120;

    while (projected < target && months < maxMonths) {
      projected = projected * (1 + monthlyReturn) + monthlyContribution;
      months++;
    }

    final projectedYear = DateTime.now().year + (months / 12).ceil();

    return RetirementProjection(
      currentAge: currentAge,
      retirementAge: retirementAge,
      targetAmount: target,
      projectedYear: projectedYear,
      progressPercent: progress * 100,
      currentAmount: currentAmountThb,
    );
  }

  List<double> generateChartData(int points, double baseValue) {
    final random = Random(42);
    final data = <double>[];
    var value = baseValue * 0.82;
    for (var i = 0; i < points; i++) {
      value *= 1 + (random.nextDouble() - 0.42) * 0.025;
      data.add(value);
    }
    data[points - 1] = baseValue;
    return data;
  }

  Future<List<Quote>> getMarketQuotes() =>
      _fmp.fetchQuotes(AppConstants.marketWatchSymbols);

  Future<List<Quote>> getWatchlistQuotes() =>
      _fmp.fetchQuotes(AppConstants.watchlistSymbols);

  Future<List<NewsItem>> getPortfolioNews() async {
    final symbols = AppConstants.dcaCalculatorAssets
        .map((a) => a['symbol'] as String)
        .where((s) => !const {'KKP_NDQ', 'MTS_GOLD'}.contains(s))
        .map((s) => switch (s) {
              'BTCUSD' => 'BTCUSD',
              _ => s,
            })
        .toList();
    return _fmp.fetchNews(symbols);
  }

  Future<List<Map<String, dynamic>>> getHistorical(String symbol, int days) {
    return _fmp.fetchHistorical(symbol, days: days);
  }
}
