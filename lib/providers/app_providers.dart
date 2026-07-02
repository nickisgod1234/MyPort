import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/portfolio_models.dart';
import '../data/models/quote.dart';
import '../data/services/fmp_api_service.dart';
import '../data/services/portfolio_service.dart';
import '../data/services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden');
});

final fmpApiServiceProvider = Provider<FmpApiService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return FmpApiService(apiKey: storage.apiKey);
});

final portfolioServiceProvider = Provider<PortfolioService>((ref) {
  return PortfolioService(
    ref.watch(fmpApiServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

final portfolioSummaryProvider = FutureProvider<PortfolioSummary>((ref) async {
  return ref.watch(portfolioServiceProvider).getSummary();
});

final marketQuotesProvider = FutureProvider<List<Quote>>((ref) async {
  return ref.watch(portfolioServiceProvider).getMarketQuotes();
});

final watchlistQuotesProvider = FutureProvider<List<Quote>>((ref) async {
  return ref.watch(portfolioServiceProvider).getWatchlistQuotes();
});

final portfolioNewsProvider = FutureProvider<List<NewsItem>>((ref) async {
  return ref.watch(portfolioServiceProvider).getPortfolioNews();
});

final portfolioAnalysisProvider = FutureProvider<PortfolioAnalysis>((ref) async {
  return ref.watch(portfolioServiceProvider).analyzePortfolio();
});

final monthlyBudgetProvider = StateProvider<double>((ref) {
  return ref.watch(storageServiceProvider).monthlyBudget;
});

final chartPeriodProvider = StateProvider<ChartPeriod>((ref) => ChartPeriod.oneMonth);

enum ChartPeriod { oneDay, oneMonth, sixMonths, oneYear, all }

int chartDaysForPeriod(ChartPeriod period) {
  switch (period) {
    case ChartPeriod.oneDay:
      return 1;
    case ChartPeriod.oneMonth:
      return 30;
    case ChartPeriod.sixMonths:
      return 180;
    case ChartPeriod.oneYear:
      return 365;
    case ChartPeriod.all:
      return 730;
  }
}

final retirementProjectionProvider = Provider<RetirementProjection>((ref) {
  final summary = ref.watch(portfolioSummaryProvider);
  return summary.when(
    data: (s) => ref.watch(portfolioServiceProvider).getRetirementProjection(s.totalValueThb),
    loading: () => RetirementProjection(
      currentAge: ref.watch(storageServiceProvider).currentAge,
      retirementAge: ref.watch(storageServiceProvider).retirementAge,
      targetAmount: ref.watch(storageServiceProvider).targetAmount,
      projectedYear: 2050,
      progressPercent: 0,
      currentAmount: 0,
    ),
    error: (_, __) => RetirementProjection(
      currentAge: ref.watch(storageServiceProvider).currentAge,
      retirementAge: ref.watch(storageServiceProvider).retirementAge,
      targetAmount: ref.watch(storageServiceProvider).targetAmount,
      projectedYear: 2050,
      progressPercent: 0,
      currentAmount: 0,
    ),
  );
});

final assetHistoricalProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, symbol) async {
  final period = ref.watch(chartPeriodProvider);
  final days = chartDaysForPeriod(period);
  return ref.watch(portfolioServiceProvider).getHistorical(symbol, days);
});
