import 'package:equatable/equatable.dart';

class CrowdEstimate extends Equatable {
  final String id;
  final String eventId;
  final String method;
  final int estimatedCount;
  final double? confidence;
  final double? areaSquareMeters;
  final double? densityPerSqMeter;
  final int? activeCheckins;
  final double adjustmentFactor;
  final DateTime createdAt;

  const CrowdEstimate({
    required this.id,
    required this.eventId,
    required this.method,
    required this.estimatedCount,
    this.confidence,
    this.areaSquareMeters,
    this.densityPerSqMeter,
    this.activeCheckins,
    this.adjustmentFactor = 1.0,
    required this.createdAt,
  });

  factory CrowdEstimate.fromJson(Map<String, dynamic> json) {
    return CrowdEstimate(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      method: json['method'] as String,
      estimatedCount: json['estimatedCount'] as int,
      confidence: (json['confidence'] as num?)?.toDouble(),
      areaSquareMeters: (json['areaSquareMeters'] as num?)?.toDouble(),
      densityPerSqMeter: (json['densityPerSqMeter'] as num?)?.toDouble(),
      activeCheckins: json['activeCheckins'] as int?,
      adjustmentFactor: (json['adjustmentFactor'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Nível de confiança como texto
  String get confidenceLabel {
    if (confidence == null) return 'Desconhecida';
    if (confidence! >= 0.7) return 'Alta';
    if (confidence! >= 0.4) return 'Média';
    return 'Baixa';
  }

  /// Formata o número estimado de forma legível
  String get formattedCount {
    if (estimatedCount >= 1000000) {
      return '${(estimatedCount / 1000000).toStringAsFixed(1)}M';
    }
    if (estimatedCount >= 1000) {
      return '${(estimatedCount / 1000).toStringAsFixed(1)}K';
    }
    return estimatedCount.toString();
  }

  @override
  List<Object?> get props => [id, eventId, estimatedCount, method];
}
