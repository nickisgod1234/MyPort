import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

final _currencyUsd = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _currencyThb = NumberFormat('#,##0.00', 'en_US');
final _percent = NumberFormat('#0.00');
final _compact = NumberFormat.compact();

String formatUsd(double value) => _currencyUsd.format(value);

String formatThb(double value) => '${_currencyThb.format(value)} บาท';

String formatThbCompact(double value) =>
    '${_currencyThb.format(value)}';

String formatUsdApprox(double value) => '≈ ${formatUsd(value)}';

double thbToUsd(double thb, double usdThbRate) {
  if (usdThbRate <= 0) return 0;
  return thb / usdThbRate;
}

double usdToThb(double usd, double usdThbRate) {
  if (usdThbRate <= 0) return 0;
  return usd * usdThbRate;
}

String formatUsdFromThb(double thb, double usdThbRate) =>
    formatUsdApprox(thbToUsd(thb, usdThbRate));

String formatThbFromUsd(double usd, double usdThbRate) =>
    '≈ ${formatThbCompact(usdToThb(usd, usdThbRate))}';

/// แปลงค่าที่แสดงในช่องกรอก ↔ บาท (เก็บภายในเป็น THB เสมอ)
double displayAmountFromThb(double thb, {required bool inUsd, required double rate}) =>
    inUsd ? thbToUsd(thb, rate) : thb;

double thbFromDisplayAmount(double display, {required bool inUsd, required double rate}) =>
    inUsd ? usdToThb(display, rate) : display;

String formatPercent(double value, {bool showSign = true}) {
  final sign = showSign && value > 0 ? '+' : '';
  return '$sign${_percent.format(value)}%';
}

String formatCompact(double value) => _compact.format(value);

String formatMillionsThb(double value) {
  final millions = value / 1000000;
  return '${millions.toStringAsFixed(1)} / ${(AppConstants.defaultTargetAmount / 1000000).toStringAsFixed(0)} ล้านบาท';
}

String formatExchangeRate([double? usdThbRate]) =>
    '1 USD = ${(usdThbRate ?? AppConstants.usdThbRate).toStringAsFixed(2)} ฿';

String formatProfitThb(double profit) {
  final sign = profit >= 0 ? '+' : '';
  return '$sign${_currencyThb.format(profit)} บาท';
}

String formatAllocationPercent(double allocation) =>
    '${(allocation * 100).toStringAsFixed(2)}%';
