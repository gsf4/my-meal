import 'package:flutter/material.dart';
import 'package:my_meal/core/theme/app_theme.dart';

class MacroProgressCard extends StatelessWidget {
  final double currentProtein;
  final double goalProtein;
  final double currentCarbs;
  final double goalCarbs;
  final double currentFat;
  final double goalFat;

  const MacroProgressCard({
    super.key,
    required this.currentProtein,
    required this.goalProtein,
    required this.currentCarbs,
    required this.goalCarbs,
    required this.currentFat,
    required this.goalFat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Macronutrientes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildMacroRow(
              title: 'Proteínas',
              current: currentProtein,
              goal: goalProtein,
              color: AppTheme.proteinColor,
            ),
            const SizedBox(height: 14),
            _buildMacroRow(
              title: 'Carboidratos',
              current: currentCarbs,
              goal: goalCarbs,
              color: AppTheme.carbsColor,
            ),
            const SizedBox(height: 14),
            _buildMacroRow(
              title: 'Gorduras',
              current: currentFat,
              goal: goalFat,
              color: AppTheme.fatColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow({
    required String title,
    required double current,
    required double goal,
    required Color color,
  }) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              '${current.toStringAsFixed(1)}g / ${goal.toStringAsFixed(0)}g',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: current > goal ? AppTheme.dangerColor : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
