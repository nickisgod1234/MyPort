import 'package:dio/dio.dart';

import '../models/quote.dart';

/// Fallback สำหรับ symbol ที่ FMP Free tier ไม่รองรับ (เช่น RKLB, VT)
class YahooFinanceService {
  YahooFinanceService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (compatible; MyWealthApp/1.0)',
  };

  Future<Quote?> fetchQuote(String symbol) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol',
        queryParameters: const {'interval': '1d', 'range': '1d'},
        options: Options(
          headers: _headers,
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
        ),
      );

      final result = response.data?['chart']?['result'];
      if (result is! List || result.isEmpty) return null;

      final meta = result.first['meta'];
      if (meta is! Map) return null;

      final map = Map<String, dynamic>.from(meta);
      final price = (map['regularMarketPrice'] as num?)?.toDouble();
      if (price == null || price <= 0) return null;

      final previous = (map['chartPreviousClose'] as num?)?.toDouble() ??
          (map['previousClose'] as num?)?.toDouble();
      final change = previous != null ? price - previous : 0.0;
      final changePct =
          previous != null && previous > 0 ? (change / previous) * 100 : 0.0;

      return Quote(
        symbol: symbol,
        price: price,
        change: change,
        changesPercentage: changePct,
        name: map['longName'] as String? ?? map['shortName'] as String?,
        isLive: true,
        source: QuoteSource.yahoo,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchHistorical(
    String symbol, {
    int days = 30,
  }) async {
    try {
      final range = _rangeForDays(days);
      final response = await _dio.get<Map<String, dynamic>>(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol',
        queryParameters: {'interval': '1d', 'range': range},
        options: Options(
          headers: _headers,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final result = response.data?['chart']?['result'];
      if (result is! List || result.isEmpty) return [];

      final first = result.first as Map<String, dynamic>;
      final timestamps = first['timestamp'] as List<dynamic>?;
      final quotes = first['indicators']?['quote'] as List<dynamic>?;
      if (timestamps == null || quotes == null || quotes.isEmpty) return [];

      final closes = (quotes.first as Map)['close'] as List<dynamic>?;
      if (closes == null) return [];

      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < timestamps.length; i++) {
        final close = closes[i];
        if (close == null) continue;
        final ts = timestamps[i] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
        rows.add({
          'date': date.toIso8601String().split('T').first,
          'close': (close as num).toDouble(),
        });
      }

      if (rows.length > days) {
        return rows.sublist(rows.length - days);
      }
      return rows;
    } catch (_) {
      return [];
    }
  }

  String _rangeForDays(int days) {
    if (days <= 5) return '5d';
    if (days <= 30) return '1mo';
    if (days <= 180) return '6mo';
    if (days <= 365) return '1y';
    return '5y';
  }
}
