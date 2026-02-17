import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/theme.dart';

/// Tela de Verificação Blue Check (Addon 3)
class BlueCheckScreen extends ConsumerWidget {
  const BlueCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasBlueCheck = ref.watch(hasBlueCheckProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificação Blue Check'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: hasBlueCheck ? _buildActiveView(context) : _buildPurchaseView(context, ref),
    );
  }

  Widget _buildActiveView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Badge grande
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1DA1F2), Color(0xFF0D8BD9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1DA1F2).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.verified,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Você é Verificado! ✓',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1DA1F2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seu badge de organização verificada está ativo',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Benefícios ativos
          _benefitCard(
            icon: Icons.verified,
            title: 'Badge Verificado',
            description: 'Visível em todos os seus eventos e perfil',
            color: const Color(0xFF1DA1F2),
            isActive: true,
          ),
          const SizedBox(height: 12),
          _benefitCard(
            icon: Icons.search,
            title: 'Destaque nas Buscas',
            description: 'Seus eventos aparecem primeiro nos resultados',
            color: Colors.green,
            isActive: true,
          ),
          const SizedBox(height: 12),
          _benefitCard(
            icon: Icons.shield,
            title: 'Selo de Confiança',
            description: 'Participantes veem que você é um organizador confiável',
            color: Colors.amber,
            isActive: true,
          ),
          const SizedBox(height: 12),
          _benefitCard(
            icon: Icons.trending_up,
            title: 'Prioridade de Visibilidade',
            description: '+40% mais visualizações nos seus eventos',
            color: Colors.purple,
            isActive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseView(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Badge desabilitado
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey[300]!, width: 3),
            ),
            child: Icon(
              Icons.verified_outlined,
              color: Colors.grey[400],
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Verificação Blue Check',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ganhe credibilidade e destaque como organizador',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Preview dos benefícios
          _benefitCard(
            icon: Icons.verified,
            title: 'Badge Verificado',
            description: 'Visível em eventos e perfil — transmita confiança',
            color: const Color(0xFF1DA1F2),
          ),
          const SizedBox(height: 12),
          _benefitCard(
            icon: Icons.search,
            title: 'Destaque nas Buscas',
            description: 'Seus eventos aparecem primeiro nos resultados',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _benefitCard(
            icon: Icons.shield,
            title: 'Selo de Confiança',
            description: 'Participantes saberão que você é confiável',
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          _benefitCard(
            icon: Icons.trending_up,
            title: '+40% Visibilidade',
            description: 'Mais pessoas descobrem seus eventos',
            color: Colors.purple,
          ),
          const SizedBox(height: 32),

          // Preço e botão
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1DA1F2), Color(0xFF0D8BD9)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1DA1F2).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Pagamento Único',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'R\$ 29,90',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vitalício — pague uma vez, use para sempre',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _purchase(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1DA1F2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Obter Verificação',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            child: const Text('Incluído no plano Profissional'),
          ),
        ],
      ),
    );
  }

  Widget _benefitCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    bool isActive = false,
  }) {
    return Card(
      elevation: isActive ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: color.withOpacity(0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchase(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF1DA1F2)),
            SizedBox(width: 8),
            Text('Verificação Blue Check'),
          ],
        ),
        content: const Text(
          'Confirmar compra da Verificação Blue Check por R\$ 29,90?\n\n'
          'Este é um pagamento único e vitalício.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DA1F2),
            ),
            child: const Text('Comprar R\$ 29,90'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(subscriptionProvider.notifier).addAddon(AddonType.blueCheck);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Verificação Blue Check ativada!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

/// Widget pequeno de badge verificado para uso em cards/perfil
class VerifiedBadge extends ConsumerWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 18});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCheck = ref.watch(hasBlueCheckProvider);
    if (!hasCheck) return const SizedBox.shrink();

    return Tooltip(
      message: 'Organizador Verificado',
      child: Icon(
        Icons.verified,
        color: const Color(0xFF1DA1F2),
        size: size,
      ),
    );
  }
}
