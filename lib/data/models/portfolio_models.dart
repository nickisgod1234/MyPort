import '../../core/constants/app_constants.dart';

class Holding {
  const Holding({
    required this.symbol,
    required this.shares,
    required this.averageCost,
    required this.targetAllocation,
    this.displayName,
    this.fmpSymbol,
    this.isThaiFund = false,
    this.fixedValueThb,
    this.fixedCostThb,
  });

  final String symbol;
  final String? displayName;
  final String? fmpSymbol;
  final double shares;
  final double averageCost;
  final double targetAllocation;
  final bool isThaiFund;
  final double? fixedValueThb;
  final double? fixedCostThb;

  String get name => displayName ?? symbol;

  String? get quoteSymbol => isThaiFund ? null : (fmpSymbol ?? symbol);

  double get investedUsd => isThaiFund ? 0 : shares * averageCost;

  double get investedThb {
    if (isThaiFund) {
      return fixedCostThb ?? shares * averageCost;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        if (displayName != null) 'displayName': displayName,
        if (fmpSymbol != null) 'fmpSymbol': fmpSymbol,
        'shares': shares,
        'averageCost': averageCost,
        'targetAllocation': targetAllocation,
        'isThaiFund': isThaiFund,
        if (fixedValueThb != null) 'fixedValueThb': fixedValueThb,
        if (fixedCostThb != null) 'fixedCostThb': fixedCostThb,
      };

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      symbol: json['symbol'] as String,
      displayName: json['displayName'] as String?,
      fmpSymbol: json['fmpSymbol'] as String?,
      shares: (json['shares'] as num).toDouble(),
      averageCost: (json['averageCost'] as num).toDouble(),
      targetAllocation: (json['targetAllocation'] as num).toDouble(),
      isThaiFund: json['isThaiFund'] as bool? ?? false,
      fixedValueThb: (json['fixedValueThb'] as num?)?.toDouble(),
      fixedCostThb: (json['fixedCostThb'] as num?)?.toDouble(),
    );
  }
}

class PortfolioSummary {
  const PortfolioSummary({
    required this.totalValueThb,
    required this.totalInvestedThb,
    required this.totalProfitThb,
    required this.totalReturnPercent,
    required this.holdings,
  });

  final double totalValueThb;
  final double totalInvestedThb;
  final double totalProfitThb;
  final double totalReturnPercent;
  final List<HoldingValue> holdings;

  double get totalValueUsd => totalValueThb / AppConstants.usdThbRate;
}

class HoldingValue {
  const HoldingValue({
    required this.holding,
    required this.currentPrice,
    required this.marketValueThb,
    required this.marketValueUsd,
    required this.profitThb,
    required this.returnPercent,
    required this.allocation,
    this.isLive = false,
  });

  final Holding holding;
  final double currentPrice;
  final double marketValueThb;
  final double? marketValueUsd;
  final double profitThb;
  final double returnPercent;
  final double allocation;
  final bool isLive;
}

class RebalanceSuggestion {
  const RebalanceSuggestion({
    required this.symbol,
    required this.displayName,
    required this.status,
    required this.message,
    this.suggestedAmount,
  });

  final String symbol;
  final String displayName;
  final RebalanceStatus status;
  final String message;
  final double? suggestedAmount;
}

enum RebalanceStatus { over, under, ok, skip }

class DcaAllocation {
  const DcaAllocation({
    required this.symbol,
    required this.displayName,
    required this.amount,
    required this.isRecommended,
  });

  final String symbol;
  final String displayName;
  final double amount;
  final bool isRecommended;
}

class RetirementProjection {
  const RetirementProjection({
    required this.currentAge,
    required this.retirementAge,
    required this.targetAmount,
    required this.projectedYear,
    required this.progressPercent,
    required this.currentAmount,
  });

  final int currentAge;
  final int retirementAge;
  final double targetAmount;
  final int projectedYear;
  final double progressPercent;
  final double currentAmount;
}

class PortfolioAnalysis {
  const PortfolioAnalysis({
    required this.score,
    required this.suggestions,
    required this.sharpe,
    required this.beta,
    required this.maxDrawdown,
    required this.volatility,
  });

  final int score;
  final List<RebalanceSuggestion> suggestions;
  final double sharpe;
  final double beta;
  final double maxDrawdown;
  final double volatility;
}

class NewsItem {
  const NewsItem({
    required this.title,
    required this.symbol,
    required this.publishedDate,
    required this.site,
    this.url,
  });

  final String title;
  final String symbol;
  final String publishedDate;
  final String site;
  final String? url;
}
