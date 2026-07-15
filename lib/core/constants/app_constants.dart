import 'portfolio_profiles.dart';

class AppConstants {
  static const appName = 'ลงทุนครอบครัว';
  static const portfolioName = 'เกษียณสำราญ';
  static const fmpBaseUrl = 'https://financialmodelingprep.com/stable';
  static const usdThbRate = 33.28;
  static const portfolioDataVersion = 3;

  static const defaultTargetAmount = 7000000.0;
  static const defaultCurrentAge = 36;
  static const defaultRetirementAge = 61;
  static const defaultMonthlyBudget = 10000.0;

  /// พอร์ตหลัก (เกษียณสำราญ) — ใช้กับ holdings เดิม
  static List<Map<String, dynamic>> get dcaCalculatorAssets =>
      PortfolioProfiles.retirement.assets;

  static const marketWatchSymbols = [
    'VT',
    'VTI',
    'SMH',
    'RKLB',
    'GCUSD',
    'SCHG',
    'SCHD',
  ];
  static const watchlistSymbols = ['AAPL', 'NVDA', 'AMZN', 'V', 'SPY'];

  static const targetAllocations = <String, double>{
    'VT': 0.30,
    'KKP_NDQ': 0.30,
    'SMH': 0.20,
    'MTS_GOLD': 0.10,
    'BTCUSD': 0.05,
    'RKLB': 0.05,
  };

  static const assetDisplayNames = <String, String>{
    'VT': 'VT',
    'VTI': 'VTI',
    'KKP_NDQ': 'KKP NDQ100-UH-E',
    'SMH': 'SMH',
    'SCHG': 'SCHG',
    'SCHD': 'SCHD',
    'TLSEMICON': 'TLSEMICON-UH',
    'MTS_GOLD': 'Gold',
    'RKLB': 'RKLB',
    'BTCUSD': 'Bitcoin',
    'AAPL': 'Apple',
    'NVDA': 'Nvidia',
    'AMZN': 'Amazon',
    'V': 'Visa',
    'SPY': 'SPY',
    'GCUSD': 'Gold',
  };

  static const assetColors = <String, int>{
    'VT': 0xFF8B2332,
    'VTI': 0xFFC2410C,
    'KKP_NDQ': 0xFF1E3A8A,
    'SMH': 0xFF6B21A8,
    'SCHG': 0xFF0D9488,
    'SCHD': 0xFF2563EB,
    'TLSEMICON': 0xFF9333EA,
    'MTS_GOLD': 0xFFD4AF37,
    'RKLB': 0xFFE91E63,
    'BTCUSD': 0xFFFF9800,
    'AAPL': 0xFFA2AAAD,
    'NVDA': 0xFF76B900,
    'AMZN': 0xFFFF9900,
    'V': 0xFF1A1F71,
    'SPY': 0xFF2962FF,
    'GCUSD': 0xFFFFB300,
  };

  /// Default holdings — พอร์ต "เกษียณสำราญ" จากข้อมูลจริง
  static List<Map<String, dynamic>> get defaultHoldingsJson => [
        {
          'symbol': 'VT',
          'displayName': 'VT',
          'fmpSymbol': 'VT',
          'shares': 1.0504,
          'averageCost': 128.78,
          'targetAllocation': 0.30,
          'isThaiFund': false,
        },
        {
          'symbol': 'KKP_NDQ',
          'displayName': 'KKP NDQ100-UH-E',
          'shares': 230.0,
          'averageCost': 10.0,
          'targetAllocation': 0.30,
          'isThaiFund': true,
          'fixedValueThb': 2300.0,
          'fixedCostThb': 2300.0,
        },
        {
          'symbol': 'SMH',
          'displayName': 'SMH',
          'fmpSymbol': 'SMH',
          'shares': 0.5,
          'averageCost': 300.0,
          'targetAllocation': 0.20,
          'isThaiFund': false,
        },
        {
          'symbol': 'MTS_GOLD',
          'displayName': 'MTS-GOLD',
          'shares': 1.0,
          'averageCost': 900.0,
          'targetAllocation': 0.10,
          'isThaiFund': true,
          'fixedValueThb': 900.0,
          'fixedCostThb': 900.0,
        },
        {
          'symbol': 'BTCUSD',
          'displayName': 'Bitcoin',
          'fmpSymbol': 'BTCUSD',
          'shares': 0.01,
          'averageCost': 100000.0,
          'targetAllocation': 0.05,
          'isThaiFund': false,
        },
        {
          'symbol': 'RKLB',
          'displayName': 'RKLB',
          'fmpSymbol': 'RKLB',
          'shares': 0.5378,
          'averageCost': 27.92,
          'targetAllocation': 0.05,
          'isThaiFund': false,
        },
      ];
}
