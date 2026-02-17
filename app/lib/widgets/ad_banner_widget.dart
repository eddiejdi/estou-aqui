import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../providers/subscription_provider.dart';
import '../utils/theme.dart';

/// Widget de banner publicitário simulado (placeholder para AdMob real).
/// Esconde-se automaticamente quando o usuário é assinante.
class AdBannerWidget extends ConsumerWidget {
  final bool isTop;
  const AdBannerWidget({super.key, this.isTop = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAds = ref.watch(showAdsProvider);
    if (!showAds) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 60,
      margin: EdgeInsets.only(
        left: 8,
        right: 8,
        top: isTop ? 8 : 0,
        bottom: isTop ? 0 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showUpgradeDialog(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚡ Estou Aqui Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Remova anúncios + recursos exclusivos',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'UPGRADE',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, WidgetRef ref) {
    // Navega para a tela de planos
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _QuickUpgradeSheet()),
    );
  }
}

/// Bottom sheet rápido para upgrade
class _QuickUpgradeSheet extends ConsumerWidget {
  const _QuickUpgradeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Premium'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Estou Aqui Premium',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Desbloqueie todo o potencial',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            _planCard(
              context, ref,
              title: 'Básico',
              price: 'R\$ 9,90/mês',
              features: ['Sem anúncios', 'Até 10 eventos/mês', 'Estatísticas básicas'],
              color: Colors.blue,
              onTap: () => _purchase(context, ref, 'basic'),
            ),
            const SizedBox(height: 16),
            _planCard(
              context, ref,
              title: 'Profissional',
              price: 'R\$ 29,90/mês',
              features: [
                'Tudo do Básico',
                'Eventos ilimitados',
                'Análise avançada',
                'Exportação dados',
                'Badge Verificado ✓',
                'Dashboard Grafana',
              ],
              color: Colors.amber,
              isPopular: true,
              onTap: () => _purchase(context, ref, 'professional'),
            ),
            const SizedBox(height: 16),
            _planCard(
              context, ref,
              title: 'Enterprise',
              price: 'R\$ 99,90/mês',
              features: [
                'Tudo do Profissional',
                'API de integração',
                'White-label',
                'Suporte prioritário',
              ],
              color: Colors.deepPurple,
              onTap: () => _purchase(context, ref, 'enterprise'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _planCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String price,
    required List<String> features,
    required Color color,
    required VoidCallback onTap,
    bool isPopular = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          elevation: isPopular ? 8 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPopular
                ? BorderSide(color: color, width: 2)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f)),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Assinar Agora',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isPopular)
          Positioned(
            top: -12,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '⭐ MAIS POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _purchase(BuildContext context, WidgetRef ref, String plan) async {
    // TODO: Integrar com in_app_purchase real
    // Por enquanto, simula a compra com confirmação
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Assinatura'),
        content: Text(
          'Deseja assinar o plano ${plan.toUpperCase()}?\n\n'
          'Nota: A integração com Google Play/App Store será feita via in_app_purchase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final subPlan = plan == 'basic'
          ? SubscriptionPlan.basic
          : plan == 'professional'
              ? SubscriptionPlan.professional
              : SubscriptionPlan.enterprise;

      await ref.read(subscriptionProvider.notifier).upgradePlan(subPlan);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Plano $plan ativado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
