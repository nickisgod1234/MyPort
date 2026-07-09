class AppConstants {
  static const appName = 'ลงทุนครอบครัว';
  static const portfolioName = 'เกษียณสำราญ';
  static const fmpBaseUrl = 'https://financialmodelingprep.com/stable';
  static const usdThbRate = 33.28;
  static const portfolioDataVersion = 2;

  static const defaultTargetAmount = 7000000.0;
  static const defaultCurrentAge = 36;
  static const defaultRetirementAge = 61;
  static const defaultMonthlyBudget = 10000.0;

  /// สินทรัพย์สำหรับหน้าคำนวณ DCA (ตาม spreadsheet)
  static const dcaCalculatorAssets = <Map<String, dynamic>>[
    {
      'symbol': 'VT',
      'name': 'Vanguard Total World Stock ETF (VT)',
      'target': 4500 / 11000,
      'defaultValue': 4500.0,
    },
    {
      'symbol': 'KKP_NDQ',
      'name': 'KKP NDQ100-UH-E',
      'target': 2500 / 11000,
      'defaultValue': 2500.0,
    },
    {
      'symbol': 'SMH',
      'name': 'VanEck Semiconductor ETF (SMH)',
      'target': 1500 / 11000,
      'defaultValue': 1500.0,
    },
    {
      'symbol': 'MTS_GOLD',
      'name': 'Gold',
      'target': 1000 / 11000,
      'defaultValue': 1000.0,
    },
    {
      'symbol': 'BTCUSD',
      'name': 'Bitcoin',
      'target': 1000 / 11000,
      'defaultValue': 1000.0,
    },
    {
      'symbol': 'RKLB',
      'name': 'Rocket Lab',
      'target': 500 / 11000,
      'defaultValue': 500.0,
    },
  ];

  static const marketWatchSymbols = ['VT', 'SMH', 'RKLB', 'GCUSD'];
  static const watchlistSymbols = ['AAPL', 'NVDA', 'AMZN', 'V', 'SPY'];

  static const targetAllocations = <String, double>{
    'VT': 4500 / 11000,
    'KKP_NDQ': 2500 / 11000,
    'SMH': 1500 / 11000,
    'MTS_GOLD': 1000 / 11000,
    'BTCUSD': 1000 / 11000,
    'RKLB': 500 / 11000,
  };

  static const assetDisplayNames = <String, String>{
    'VT': 'VT',
    'KKP_NDQ': 'KKP NDQ100-UH-E',
    'SMH': 'SMH',
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
    'KKP_NDQ': 0xFF1E3A8A,
    'SMH': 0xFF6B21A8,
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
          'targetAllocation': 4500 / 11000,
          'isThaiFund': false,
        },
        {
          'symbol': 'KKP_NDQ',
          'displayName': 'KKP NDQ100-UH-E',
          'shares': 250.0,
          'averageCost': 10.0,
          'targetAllocation': 2500 / 11000,
          'isThaiFund': true,
          'fixedValueThb': 2500.0,
          'fixedCostThb': 2500.0,
        },
        {
          'symbol': 'SMH',
          'displayName': 'SMH',
          'fmpSymbol': 'SMH',
          'shares': 0.5,
          'averageCost': 300.0,
          'targetAllocation': 1500 / 11000,
          'isThaiFund': false,
        },
        {
          'symbol': 'MTS_GOLD',
          'displayName': 'MTS-GOLD',
          'shares': 1.0,
          'averageCost': 1000.0,
          'targetAllocation': 1000 / 11000,
          'isThaiFund': true,
          'fixedValueThb': 1000.0,
          'fixedCostThb': 1000.0,
        },
        {
          'symbol': 'BTCUSD',
          'displayName': 'Bitcoin',
          'fmpSymbol': 'BTCUSD',
          'shares': 0.01,
          'averageCost': 100000.0,
          'targetAllocation': 1000 / 11000,
          'isThaiFund': false,
        },
        {
          'symbol': 'RKLB',
          'displayName': 'RKLB',
          'fmpSymbol': 'RKLB',
          'shares': 0.5378,
          'averageCost': 27.92,
          'targetAllocation': 500 / 11000,
          'isThaiFund': false,
        },
      ];
}
