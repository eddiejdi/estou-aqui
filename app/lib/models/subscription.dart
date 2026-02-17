import 'package:equatable/equatable.dart';

/// Tipos de plano disponíveis
enum SubscriptionPlan {
  free,
  basic,
  professional,
  enterprise;

  String get label {
    switch (this) {
      case SubscriptionPlan.free:
        return 'Gratuito';
      case SubscriptionPlan.basic:
        return 'Básico';
      case SubscriptionPlan.professional:
        return 'Profissional';
      case SubscriptionPlan.enterprise:
        return 'Enterprise';
    }
  }

  String get price {
    switch (this) {
      case SubscriptionPlan.free:
        return 'R\$ 0';
      case SubscriptionPlan.basic:
        return 'R\$ 9,90/mês';
      case SubscriptionPlan.professional:
        return 'R\$ 29,90/mês';
      case SubscriptionPlan.enterprise:
        return 'R\$ 99,90/mês';
    }
  }

  String get description {
    switch (this) {
      case SubscriptionPlan.free:
        return 'Até 3 eventos, com anúncios';
      case SubscriptionPlan.basic:
        return 'Até 10 eventos, sem anúncios';
      case SubscriptionPlan.professional:
        return 'Eventos ilimitados, análise avançada';
      case SubscriptionPlan.enterprise:
        return 'Tudo + API, white-label, suporte';
    }
  }

  List<String> get features {
    switch (this) {
      case SubscriptionPlan.free:
        return [
          'Criar até 3 eventos/mês',
          'Check-in/checkout',
          'Chat em tempo real',
          'Mapa de eventos',
        ];
      case SubscriptionPlan.basic:
        return [
          'Tudo do Gratuito',
          'Até 10 eventos/mês',
          'Sem anúncios',
          'Estatísticas básicas',
        ];
      case SubscriptionPlan.professional:
        return [
          'Tudo do Básico',
          'Eventos ilimitados',
          'Análise avançada de público',
          'Exportação de dados (CSV/PDF)',
          'Badge Verificado ✓',
          'Dashboard Grafana do evento',
          'Relatórios personalizados',
        ];
      case SubscriptionPlan.enterprise:
        return [
          'Tudo do Profissional',
          'API de integração',
          'White-label',
          'Suporte prioritário',
          'Múltiplos organizadores',
        ];
    }
  }

  bool get hasAnalytics =>
      this == SubscriptionPlan.professional || this == SubscriptionPlan.enterprise;

  bool get hasExport =>
      this == SubscriptionPlan.professional || this == SubscriptionPlan.enterprise;

  bool get hasBlueCheck =>
      this == SubscriptionPlan.professional || this == SubscriptionPlan.enterprise;

  bool get hasGrafana =>
      this == SubscriptionPlan.professional || this == SubscriptionPlan.enterprise;

  bool get isAdFree => this != SubscriptionPlan.free;
}

/// Addon avulso que pode ser comprado separadamente
enum AddonType {
  analytics,
  blueCheck,
  exportReports,
  grafanaDashboard;

  String get label {
    switch (this) {
      case AddonType.analytics:
        return 'Análise Avançada';
      case AddonType.blueCheck:
        return 'Verificação Blue Check';
      case AddonType.exportReports:
        return 'Exportação e Relatórios';
      case AddonType.grafanaDashboard:
        return 'Dashboard Grafana';
    }
  }

  String get description {
    switch (this) {
      case AddonType.analytics:
        return 'Estatísticas avançadas, heatmap de participantes, evolução temporal';
      case AddonType.blueCheck:
        return 'Badge verificado, destaque nas buscas, selo de confiança';
      case AddonType.exportReports:
        return 'Exportar participantes CSV/PDF, certificados, relatórios';
      case AddonType.grafanaDashboard:
        return 'Dashboard Grafana em tempo real para seu evento';
    }
  }

  String get price {
    switch (this) {
      case AddonType.analytics:
        return 'R\$ 19,90/mês';
      case AddonType.blueCheck:
        return 'R\$ 29,90 (único)';
      case AddonType.exportReports:
        return 'R\$ 9,90/mês';
      case AddonType.grafanaDashboard:
        return 'R\$ 14,90/mês';
    }
  }

  String get icon {
    switch (this) {
      case AddonType.analytics:
        return '📊';
      case AddonType.blueCheck:
        return '✅';
      case AddonType.exportReports:
        return '📄';
      case AddonType.grafanaDashboard:
        return '📈';
    }
  }

  String get productId {
    switch (this) {
      case AddonType.analytics:
        return 'addon_analytics_pro';
      case AddonType.blueCheck:
        return 'addon_blue_check';
      case AddonType.exportReports:
        return 'addon_export_reports';
      case AddonType.grafanaDashboard:
        return 'addon_grafana_dashboard';
    }
  }
}

/// Estado da assinatura do usuário
class UserSubscription extends Equatable {
  final SubscriptionPlan plan;
  final List<AddonType> activeAddons;
  final DateTime? expiresAt;
  final bool isActive;

  const UserSubscription({
    this.plan = SubscriptionPlan.free,
    this.activeAddons = const [],
    this.expiresAt,
    this.isActive = true,
  });

  /// Verifica se o usuário tem acesso a um recurso
  bool hasFeature(AddonType addon) {
    // Plano profissional/enterprise inclui tudo
    switch (addon) {
      case AddonType.analytics:
        return plan.hasAnalytics || activeAddons.contains(addon);
      case AddonType.blueCheck:
        return plan.hasBlueCheck || activeAddons.contains(addon);
      case AddonType.exportReports:
        return plan.hasExport || activeAddons.contains(addon);
      case AddonType.grafanaDashboard:
        return plan.hasGrafana || activeAddons.contains(addon);
    }
  }

  bool get showAds => !plan.isAdFree;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      plan: SubscriptionPlan.values.firstWhere(
        (p) => p.name == json['plan'],
        orElse: () => SubscriptionPlan.free,
      ),
      activeAddons: (json['activeAddons'] as List<dynamic>?)
              ?.map((a) => AddonType.values.firstWhere(
                    (t) => t.name == a,
                    orElse: () => AddonType.analytics,
                  ))
              .toList() ??
          [],
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'plan': plan.name,
        'activeAddons': activeAddons.map((a) => a.name).toList(),
        'expiresAt': expiresAt?.toIso8601String(),
        'isActive': isActive,
      };

  UserSubscription copyWith({
    SubscriptionPlan? plan,
    List<AddonType>? activeAddons,
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return UserSubscription(
      plan: plan ?? this.plan,
      activeAddons: activeAddons ?? this.activeAddons,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [plan, activeAddons, expiresAt, isActive];
}
