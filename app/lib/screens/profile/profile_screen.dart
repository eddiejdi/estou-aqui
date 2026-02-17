import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/theme.dart';
import '../addons/blue_check_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: authState.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Não logado'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  backgroundImage: user.avatar != null ? NetworkImage(user.avatar!) : null,
                  child: user.avatar == null
                      ? Text(
                          user.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(user.email, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                if (user.bio != null) ...[
                  const SizedBox(height: 8),
                  Text(user.bio!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                ],
                const SizedBox(height: 32),

                // Meus check-ins ativos
                _menuItem(context, Icons.location_on, 'Meus Check-ins Ativos', () {}),
                _menuItem(context, Icons.event, 'Meus Eventos', () {}),
                _menuItem(context, Icons.history, 'Histórico', () {}),
                const Divider(height: 32),

                // Premium & Addons
                _SubscriptionTile(),
                _menuItem(context, Icons.workspace_premium, 'Minha Assinatura', () {
                  _showSubscriptionSheet(context, ref);
                }, isPremium: true),
                _menuItem(context, Icons.verified, 'Verificação Blue Check', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BlueCheckScreen()));
                }, isPremium: true),
                const Divider(height: 32),

                _menuItem(context, Icons.settings, 'Configurações', () {}),
                _menuItem(context, Icons.help_outline, 'Ajuda', () {}),
                const Divider(height: 32),
                _menuItem(
                  context,
                  Icons.logout,
                  'Sair',
                  () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  isDestructive: true,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool isDestructive = false, bool isPremium = false}) {
    final color = isDestructive
        ? AppTheme.errorColor
        : isPremium
            ? Colors.amber[700]!
            : AppTheme.primaryColor;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: isDestructive ? AppTheme.errorColor : null)),
      trailing: isPremium
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('PRO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showSubscriptionSheet(BuildContext context, WidgetRef ref) {
    final subscription = ref.read(subscriptionProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Text('Minha Assinatura', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Plano ${subscription.plan.label}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${subscription.activeAddons.length} addon(s) ativo(s)',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Planos Disponíveis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _planCard('Basic', 'R\$ 9,90/mês', 'Sem anúncios + Análise básica', Colors.blue),
              _planCard('Professional', 'R\$ 29,90/mês', 'Todos addons inclusos', Colors.purple),
              _planCard('Enterprise', 'R\$ 99,90/mês', 'API + suporte prioritário', Colors.orange),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planCard(String name, String price, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.workspace_premium, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Text(price, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Widget que mostra o plano atual no topo da seção premium
class _SubscriptionTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    final showAds = ref.watch(showAdsProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.withOpacity(0.08), Colors.orange.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plano ${subscription.plan.label}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  showAds ? 'Faça upgrade para remover anúncios' : '${subscription.activeAddons.length} addon(s) ativo(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (showAds)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('UPGRADE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
