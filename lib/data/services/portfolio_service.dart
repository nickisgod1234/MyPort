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

  static const _rate = AppConstants.usdThbRate;

  Future<PortfolioSummary> getSummary() async {
    final holdings = _storage.getHoldings();
    final fmpSymbols = holdings
        .map((h) => h.quoteSymbol)
        .whereType<String>()
        .toSet()
        .toList();
    final quotes = await _fmp.fetchQuotes(fmpSymbols);
    final quoteMap = {for (final q in quotes) q.symbol: q};

    final values = <HoldingValue>[];
    var totalValueThb = 0.0;
    var totalInvestedThb = 0.0;

    for (final holding in holdings) {
      final hv = _valueForHolding(holding, quoteMap);
      totalValueThb += hv.marketValueThb;
      totalInvestedThb += _investedThb(holding, hv);
      values.add(hv);
    }

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      values[i] = HoldingValue(
        holding: v.holding,
        currentPrice: v.currentPrice,
        marketValueThb: v.marketValueThb,
        marketValueUsd: v.marketValueUsd,
        profitThb: v.profitThb,
        returnPercent: v.returnPercent,
        allocation: totalValueThb > 0 ? v.marketValueThb / totalValueThb : 0,
        isLive: v.isLive,
      );
    }

    final totalProfitThb = totalValueThb - totalInvestedThb;
    final totalReturn =
        totalInvestedThb > 0 ? (totalProfitThb / totalInvestedThb) * 100 : 0.0;

    return PortfolioSummary(
      totalValueThb: totalValueThb,
      totalInvestedThb: totalInvestedThb,
      totalProfitThb: totalProfitThb,
      totalReturnPercent: totalReturn,
      holdings: values,
    );
  }

  HoldingValue _valueForHolding(
    Holding holding,
    Map<String, Quote> quoteMap,
  ) {
    if (holding.isThaiFund) {
      final valueThb = holding.fixedValueThb ?? holding.shares * holding.averageCost;
      final costThb = holding.fixedCostThb ?? holding.shares * holding.averageCost;
      final profit = valueThb - costThb;
      final returnPct = costThb > 0 ? (profit / costThb) * 100 : 0.0;
      return HoldingValue(
        holding: holding,
        currentPrice: holding.averageCost,
        marketValueThb: valueThb,
        marketValueUsd: null,
        profitThb: profit,
        returnPercent: returnPct,
        allocation: 0,
        isLive: false,
      );
    }

    final fmpSym = holding.quoteSymbol!;
    final quote = quoteMap[fmpSym];
    final price = quote?.price ?? holding.averageCost;
    final valueUsd = holding.shares * price;
    final valueThb = valueUsd * _rate;
    final costUsd = holding.investedUsd;
    final costThb = costUsd * _rate;
    final profitThb = valueThb - costThb;
    final returnPct = costUsd > 0 ? ((valueUsd - costUsd) / costUsd) * 100 : 0.0;

    return HoldingValue(
      holding: holding,
      currentPrice: price,
      marketValueThb: valueThb,
      marketValueUsd: valueUsd,
      profitThb: profitThb,
      returnPercent: returnPct,
      allocation: 0,
      isLive: quote?.isLive ?? false,
    );
  }

  double _investedThb(Holding holding, HoldingValue hv) {
    if (holding.isThaiFund) {
      return holding.fixedCostThb ?? holding.shares * holding.averageCost;
    }
    return holding.investedUsd * _rate;
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
    final holdings = _storage.getHoldings();
    final symbols = holdings
        .map((h) => h.quoteSymbol)
        .whereType<String>()
        .toList();
    return _fmp.fetchNews(symbols);
  }

  Future<List<Map<String, dynamic>>> getHistorical(String symbol, int days) {
    final holding = _storage.getHoldings().where((h) => h.symbol == symbol).firstOrNull;
    final fmpSym = holding?.quoteSymbol ?? symbol;
    return _fmp.fetchHistorical(fmpSym, days: days);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
