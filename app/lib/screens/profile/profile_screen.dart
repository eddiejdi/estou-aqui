import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../utils/theme.dart';

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

  Widget _menuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? AppTheme.errorColor : AppTheme.primaryColor),
      title: Text(title, style: TextStyle(color: isDestructive ? AppTheme.errorColor : null)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
