class PortfolioProfile {
  const PortfolioProfile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.assets,
    this.defaultMonthlyBudget = 10000,
  });

  final String id;
  final String name;
  final String emoji;
  final List<Map<String, dynamic>> assets;
  final double defaultMonthlyBudget;

  double get targetSum =>
      assets.fold(0.0, (sum, asset) => sum + (asset['target'] as num).toDouble());
}

class PortfolioProfiles {
  static const retirementId = 'retirement';
  static const partnerId = 'partner';

  static const retirement = PortfolioProfile(
    id: retirementId,
    name: 'เกษียณสำราญ',
    emoji: '🏖',
    defaultMonthlyBudget: 10000,
    assets: [
      {
        'symbol': 'VT',
        'name': 'Vanguard Total World Stock ETF (VT)',
        'target': 3600 / 10000,
        'defaultValue': 3600.0,
      },
      {
        'symbol': 'KKP_NDQ',
        'name': 'KKP NDQ100-UH-E',
        'target': 2300 / 10000,
        'defaultValue': 2300.0,
      },
      {
        'symbol': 'SMH',
        'name': 'VanEck Semiconductor ETF (SMH)',
        'target': 1800 / 10000,
        'defaultValue': 1800.0,
      },
      {
        'symbol': 'MTS_GOLD',
        'name': 'Gold',
        'target': 900 / 10000,
        'defaultValue': 900.0,
      },
      {
        'symbol': 'BTCUSD',
        'name': 'Bitcoin',
        'target': 900 / 10000,
        'defaultValue': 900.0,
      },
      {
        'symbol': 'RKLB',
        'name': 'Rocket Lab',
        'target': 500 / 10000,
        'defaultValue': 500.0,
      },
    ],
  );

  /// พอร์ตแฟน — growth US 75% + ปันผล 15% + ทอง 10%
  static const partner = PortfolioProfile(
    id: partnerId,
    name: 'แฟน',
    emoji: '💕',
    defaultMonthlyBudget: 5000,
    assets: [
      {
        'symbol': 'VT',
        'name': 'Vanguard Total World (VT)',
        'target': 0.30,
        'defaultValue': 0.0,
      },
      {
        'symbol': 'SCHG',
        'name': 'Schwab US Large-Cap Growth (SCHG)',
        'target': 0.45,
        'defaultValue': 0.0,
      },
      {
        'symbol': 'SCHD',
        'name': 'Schwab US Dividend Equity (SCHD)',
        'target': 0.15,
        'defaultValue': 0.0,
      },
      {
        'symbol': 'MTS_GOLD',
        'name': 'Gold',
        'target': 0.10,
        'defaultValue': 0.0,
      },
    ],
  );

  static const all = [retirement, partner];

  static PortfolioProfile byId(String id) => switch (id) {
        partnerId => partner,
        _ => retirement,
      };
}
