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
        'name': 'VT',
        'target': 0.30,
        'defaultValue': 3000.0,
      },
      {
        'symbol': 'KKP_NDQ',
        'name': 'KKP NDQ100-UH-E',
        'target': 0.30,
        'defaultValue': 3000.0,
      },
      {
        'symbol': 'SMH',
        'name': 'SMH',
        'target': 0.20,
        'defaultValue': 2000.0,
      },
      {
        'symbol': 'MTS_GOLD',
        'name': 'Gold',
        'target': 0.10,
        'defaultValue': 1000.0,
      },
      {
        'symbol': 'BTCUSD',
        'name': 'BTC',
        'target': 0.05,
        'defaultValue': 500.0,
      },
      {
        'symbol': 'RKLB',
        'name': 'RKLB',
        'target': 0.05,
        'defaultValue': 500.0,
      },
    ],
  );

  /// พอร์ตแฟน — growth 80% + ปันผล 10% + ทอง 10%
  static const partner = PortfolioProfile(
    id: partnerId,
    name: 'แฟน',
    emoji: '💕',
    defaultMonthlyBudget: 5000,
    assets: [
      {
        'symbol': 'VT',
        'name': 'VT',
        'target': 0.30,
        'defaultValue': 0.0,
      },
      {
        'symbol': 'SCHG',
        'name': 'SCHG',
        'target': 0.50,
        'defaultValue': 0.0,
      },
      {
        'symbol': 'SCHD',
        'name': 'SCHD',
        'target': 0.10,
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
