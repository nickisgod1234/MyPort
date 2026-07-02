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
      'name': 'VT',
      'target': 0.45,
      'defaultValue': 4521.28,
    },
    {
      'symbol': 'KKP_NDQ',
      'name': 'KKP NDQ100-UH-E',
      'target': 0.25,
      'defaultValue': 2500.0,
    },
    {
      'symbol': 'TLSEMICON',
      'name': 'TLSEMICON-UH',
      'target': 0.10,
      'defaultValue': 1000.0,
    },
    {
      'symbol': 'MTS_GOLD',
      'name': 'MTS Gold',
      'target': 0.10,
      'defaultValue': 990.9,
    },
    {
      'symbol': 'MSFT',
      'name': 'Microsoft',
      'target': 0.05,
      'defaultValue': 500.0,
    },
    {
      'symbol': 'BTCUSD',
      'name': 'Bitcoin',
      'target': 0.03,
      'defaultValue': 300.0,
    },
    {
      'symbol': 'RKLB',
      'name': 'Rocket Lab',
      'target': 0.02,
      'defaultValue': 200.0,
    },
  ];

  static const marketWatchSymbols = ['VT', 'RKLB', 'MSFT', 'GCUSD'];
  static const watchlistSymbols = ['AAPL', 'NVDA', 'AMZN', 'V', 'SPY'];

  static const targetAllocations = <String, double>{
    'VT': 0.4491,
    'KKP_NDQ': 0.2499,
    'MTS_GOLD': 0.1008,
    'TLSEMICON': 0.10,
    'RKLB': 0.0509,
    'MSFT': 0.0493,
  };

  static const assetDisplayNames = <String, String>{
    'VT': 'VT',
    'KKP_NDQ': 'KKP NDQ100-UH-E',
    'MTS_GOLD': 'MTS-GOLD',
    'TLSEMICON': 'TLSEMICON-UH',
    'RKLB': 'RKLB',
    'MSFT': 'MSFT',
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
    'MTS_GOLD': 0xFFD4AF37,
    'TLSEMICON': 0xFF6B21A8,
    'RKLB': 0xFFE91E63,
    'MSFT': 0xFF00A4EF,
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
          'targetAllocation': 0.4491,
          'isThaiFund': false,
        },
        {
          'symbol': 'KKP_NDQ',
          'displayName': 'KKP NDQ100-UH-E',
          'shares': 250.0,
          'averageCost': 10.0,
          'targetAllocation': 0.2499,
          'isThaiFund': true,
          'fixedValueThb': 2500.0,
          'fixedCostThb': 2500.0,
        },
        {
          'symbol': 'MTS_GOLD',
          'displayName': 'MTS-GOLD',
          'shares': 1.0,
          'averageCost': 994.2,
          'targetAllocation': 0.1008,
          'isThaiFund': true,
          'fixedValueThb': 1008.72,
          'fixedCostThb': 994.2,
        },
        {
          'symbol': 'TLSEMICON',
          'displayName': 'TLSEMICON-UH',
          'shares': 100.0,
          'averageCost': 10.0,
          'targetAllocation': 0.10,
          'isThaiFund': true,
          'fixedValueThb': 1000.0,
          'fixedCostThb': 1000.0,
        },
        {
          'symbol': 'RKLB',
          'displayName': 'RKLB',
          'fmpSymbol': 'RKLB',
          'shares': 0.5378,
          'averageCost': 27.92,
          'targetAllocation': 0.0509,
          'isThaiFund': false,
        },
        {
          'symbol': 'MSFT',
          'displayName': 'MSFT',
          'fmpSymbol': 'MSFT',
          'shares': 0.0391,
          'averageCost': 384.5,
          'targetAllocation': 0.0493,
          'isThaiFund': false,
        },
      ];
}
