import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

class PortfolioChart extends StatelessWidget {
  const PortfolioChart({
    super.key,
    required this.data,
    this.height = 200,
  });

  final List<double> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('ไม่มีข้อมูลกราฟ')),
      );
    }

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    final isUp = data.last >= data.first;
    final lineColor = isUp ? AppColors.profit : AppColors.loss;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated,
              getTooltipItems: (spots) => spots.map((spot) {
                return LineTooltipItem(
                  '\$${spot.y.toStringAsFixed(0)}',
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withValues(alpha: 0.25),
                    lineColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartPeriodSelector extends StatelessWidget {
  const ChartPeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ChartPeriod selected;
  final ValueChanged<ChartPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      ChartPeriod.oneDay: '1 วัน',
      ChartPeriod.oneMonth: '1 เดือน',
      ChartPeriod.sixMonths: '6 เดือน',
      ChartPeriod.oneYear: '1 ปี',
      ChartPeriod.all: 'ทั้งหมด',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ChartPeriod.values.map((period) {
          final isSelected = period == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[period]!),
              selected: isSelected,
              onSelected: (_) => onChanged(period),
              selectedColor: AppColors.accent.withValues(alpha: 0.2),
              backgroundColor: AppColors.surfaceElevated,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.accent : AppColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
