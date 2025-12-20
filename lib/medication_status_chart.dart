import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MedicationStatusChart extends StatelessWidget {
  final int taken;
  final int skipped;

  const MedicationStatusChart({
    super.key,
    required this.taken,
    required this.skipped,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  return Text(value == 0 ? 'Taken' : 'Skipped');
                },
              ),
            ),
          ),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: taken.toDouble(),
                  color: Colors.green,
                )
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: skipped.toDouble(),
                  color: Colors.red,
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
