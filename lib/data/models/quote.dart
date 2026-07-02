enum QuoteSource { fmp, yahoo, mock }

class Quote {
  const Quote({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changesPercentage,
    this.name,
    this.isLive = false,
    this.source = QuoteSource.mock,
  });

  final String symbol;
  final double price;
  final double change;
  final double changesPercentage;
  final String? name;
  final bool isLive;
  final QuoteSource source;

  factory Quote.fromJson(Map<String, dynamic> json) {
    final changePct = (json['changePercentage'] as num?)?.toDouble() ??
        (json['changesPercentage'] as num?)?.toDouble() ??
        0.0;

    return Quote(
      symbol: json['symbol'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      changesPercentage: changePct,
      name: json['name'] as String?,
      isLive: true,
      source: QuoteSource.fmp,
    );
  }
}
