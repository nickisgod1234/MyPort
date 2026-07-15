import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../models/portfolio_models.dart';
import '../models/quote.dart';
import 'yahoo_finance_service.dart';

class FmpApiService {
  FmpApiService({
    Dio? dio,
    String? apiKey,
    YahooFinanceService? yahoo,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                validateStatus: (status) => status != null && status < 500,
              ),
            ),
        _apiKey = apiKey,
        _yahoo = yahoo ?? YahooFinanceService();

  final Dio _dio;
  final YahooFinanceService _yahoo;
  String? _apiKey;

  void updateApiKey(String? apiKey) => _apiKey = apiKey;

  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  Future<List<Quote>> fetchQuotes(List<String> symbols) async {
    return Future.wait(symbols.map(_fetchSingleQuote));
  }

  Future<Quote> _fetchSingleQuote(String symbol) async {
    if (hasApiKey) {
      final fmp = await _tryFmpQuote(symbol);
      if (fmp != null) return fmp;
    }

    final yahoo = await _yahoo.fetchQuote(symbol);
    if (yahoo != null) return yahoo;

    return _mockQuote(symbol);
  }

  Future<Quote?> _tryFmpQuote(String symbol) async {
    try {
      final response = await _dio.get<dynamic>(
        '${AppConstants.fmpBaseUrl}/quote',
        queryParameters: {
          'symbol': symbol,
          'apikey': _apiKey,
        },
      );

      if (response.statusCode == 402 || response.statusCode == 403) {
        return null;
      }

      final data = response.data;
      if (data is! List || data.isEmpty) return null;

      final first = data.first;
      if (first is! Map) return null;

      return Quote.fromJson(Map<String, dynamic>.from(first));
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchHistorical(
    String symbol, {
    int days = 30,
  }) async {
    if (hasApiKey) {
      final fmp = await _tryFmpHistorical(symbol, days);
      if (fmp.isNotEmpty) return fmp;
    }

    final yahoo = await _yahoo.fetchHistorical(symbol, days: days);
    if (yahoo.isNotEmpty) return yahoo;

    return _mockHistorical(symbol, days);
  }

  Future<List<Map<String, dynamic>>> _tryFmpHistorical(
    String symbol,
    int days,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        '${AppConstants.fmpBaseUrl}/historical-price-eod/full',
        queryParameters: {
          'symbol': symbol,
          'apikey': _apiKey,
        },
      );

      if (response.statusCode == 402 || response.statusCode == 403) {
        return [];
      }

      final data = response.data;
      if (data is! List || data.isEmpty) return [];

      final sliced = data.take(days).toList().reversed.toList();
      return sliced.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<NewsItem>> fetchNews(List<String> symbols) async {
    if (!hasApiKey) {
      return _mockNews(symbols);
    }

    final results = <NewsItem>[];
    for (final symbol in symbols.take(3)) {
      try {
        final response = await _dio.get<dynamic>(
          '${AppConstants.fmpBaseUrl}/news/stock',
          queryParameters: {
            'symbols': symbol,
            'limit': 3,
            'apikey': _apiKey,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 8),
          ),
        );

        final data = response.data;
        if (data is! List) {
          results.addAll(_mockNews([symbol]));
          continue;
        }

        for (final item in data) {
          final map = Map<String, dynamic>.from(item as Map);
          results.add(
            NewsItem(
              title: map['title'] as String? ?? '',
              symbol: map['symbol'] as String? ?? symbol,
              publishedDate:
                  (map['publishedDate'] ?? map['date']) as String? ?? '',
              site: map['site'] as String? ?? map['publisher'] as String? ?? '',
              url: map['url'] as String?,
            ),
          );
        }
      } catch (_) {
        results.addAll(_mockNews([symbol]));
      }
    }
    return results;
  }

  Quote _mockQuote(String symbol) {
    const mockPrices = {
      'VT': 128.52,
      'VTI': 295.0,
      'SMH': 285.0,
      'SCHG': 26.5,
      'SCHD': 27.8,
      'RKLB': 28.45,
      'MSFT': 378.73,
      'GCUSD': 4044.9,
      'AAPL': 291.11,
      'NVDA': 135.80,
      'AMZN': 218.90,
      'V': 342.15,
      'SPY': 743.62,
    };
    const mockChanges = {
      'VT': -0.10,
      'VTI': 0.25,
      'SMH': 0.85,
      'SCHG': 0.42,
      'SCHD': 0.18,
      'RKLB': 1.98,
      'MSFT': -1.31,
      'GCUSD': 0.16,
      'AAPL': 0.60,
      'NVDA': 1.12,
      'AMZN': 0.68,
      'V': 0.15,
      'SPY': -0.42,
    };

    final price = mockPrices[symbol] ?? 100.0;
    final changePct = mockChanges[symbol] ?? 0.0;
    return Quote(
      symbol: symbol,
      price: price,
      change: price * changePct / 100,
      changesPercentage: changePct,
      name: AppConstants.assetDisplayNames[symbol],
      isLive: false,
      source: QuoteSource.mock,
    );
  }

  List<Map<String, dynamic>> _mockHistorical(String symbol, int days) {
    const basePrices = {
      'VT': 128.52,
      'VTI': 295.0,
      'SMH': 285.0,
      'SCHG': 26.5,
      'SCHD': 27.8,
      'RKLB': 28.45,
      'MSFT': 378.73,
      'GCUSD': 4044.9,
      'AAPL': 291.11,
      'SPY': 743.62,
    };
    final base = basePrices[symbol] ?? 100.0;
    final now = DateTime.now();
    return List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - i - 1));
      final noise = (i % 7 - 3) * 0.008;
      final trend = i * 0.002;
      return {
        'date': date.toIso8601String().split('T').first,
        'close': base * (1 + trend + noise),
      };
    });
  }

  List<NewsItem> _mockNews(List<String> symbols) {
    const headlines = {
      'MSFT': [
        'Microsoft Cloud revenue beats expectations',
        'Azure AI growth accelerates in Q4',
      ],
      'RKLB': [
        'Rocket Lab wins new launch contract',
      ],
      'VT': [
        'Global ETF flows remain strong amid volatility',
      ],
      'AAPL': [
        'Apple services revenue reaches new high',
      ],
    };

    return symbols.expand((symbol) {
      final titles = headlines[symbol] ?? ['Market update for $symbol'];
      return titles.map(
        (title) => NewsItem(
          title: title,
          symbol: symbol,
          publishedDate: DateTime.now().toIso8601String(),
          site: 'Financial News',
        ),
      );
    }).toList();
  }
}
