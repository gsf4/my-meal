import 'package:flutter/material.dart';
import 'package:my_meal/core/theme/app_theme.dart';

class CalorieSummaryCard extends StatelessWidget {
  final double goal;
  final double consumed;

  const CalorieSummaryCard({
    super.key,
    required this.goal,
    required this.consumed,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = goal - consumed;
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final isExceeded = remaining < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: AppTheme.caloriesColor),
                const SizedBox(width: 8),
                const Text(
                  'Calorias Diárias',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  isExceeded ? 'Meta excedida' : 'Restante',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isExceeded ? AppTheme.dangerColor : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildColumn('Meta', goal.toStringAsFixed(0), Colors.grey.shade700),
                const Text('-', style: TextStyle(fontSize: 20, color: Colors.grey)),
                _buildColumn('Consumido', consumed.toStringAsFixed(0), AppTheme.primaryColor),
                const Text('=', style: TextStyle(fontSize: 20, color: Colors.grey)),
                _buildColumn(
                  'Restante',
                  remaining.abs().toStringAsFixed(0),
                  isExceeded ? AppTheme.dangerColor : AppTheme.caloriesColor,
                  isBold: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isExceeded ? AppTheme.dangerColor : AppTheme.caloriesColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
