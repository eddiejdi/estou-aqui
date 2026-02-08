import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Widget de medidor visual para estimativa de público
class CrowdGauge extends StatelessWidget {
  final int confirmedCheckins;
  final int estimatedAttendees;

  const CrowdGauge({
    super.key,
    required this.confirmedCheckins,
    required this.estimatedAttendees,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.05),
            AppTheme.secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text(
            'Estimativa de Público',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Número principal
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCount(estimatedAttendees),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  ' pessoas',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barra de progresso visual
          _buildProgressIndicator(),
          const SizedBox(height: 16),

          // Detalhes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem(
                icon: Icons.check_circle,
                label: 'Confirmados',
                value: confirmedCheckins.toString(),
                color: AppTheme.secondaryColor,
              ),
              _statItem(
                icon: Icons.trending_up,
                label: 'Estimativa',
                value: _formatCount(estimatedAttendees),
                color: AppTheme.primaryColor,
              ),
              _statItem(
                icon: Icons.speed,
                label: 'Multiplicador',
                value: confirmedCheckins > 0
                    ? '${(estimatedAttendees / confirmedCheckins).toStringAsFixed(1)}x'
                    : '-',
                color: AppTheme.accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    // Densidade visual baseada no número de participantes
    Color barColor;
    String densityLabel;

    if (estimatedAttendees > 10000) {
      barColor = AppTheme.densityVeryHigh;
      densityLabel = 'Muito Alta';
    } else if (estimatedAttendees > 1000) {
      barColor = AppTheme.densityHigh;
      densityLabel = 'Alta';
    } else if (estimatedAttendees > 100) {
      barColor = AppTheme.densityMedium;
      densityLabel = 'Moderada';
    } else {
      barColor = AppTheme.densityLow;
      densityLabel = 'Baixa';
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _normalizedValue(),
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: barColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                densityLabel,
                style: TextStyle(
                  color: barColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _normalizedValue() {
    if (estimatedAttendees <= 0) return 0;
    // Escala logarítmica para melhor visualização
    final log = _log10(estimatedAttendees.toDouble());
    return (log / 6).clamp(0.0, 1.0); // max ~1M
  }

  double _log10(double x) {
    if (x <= 0) return 0;
    return _ln(x) / _ln(10);
  }

  double _ln(double x) {
    // Approximation usando Newton's method não necessária — Dart tem import:math
    // Simplificação inline:
    if (x <= 0) return 0;
    double result = 0;
    while (x > 2.71828) {
      x /= 2.71828;
      result += 1;
    }
    return result + (x - 1) - (x - 1) * (x - 1) / 2;
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
