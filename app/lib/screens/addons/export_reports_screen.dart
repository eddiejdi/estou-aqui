import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/theme.dart';

/// Tela de Exportação e Relatórios (Addon 4 — R$ 9,90/mês)
class ExportReportsScreen extends ConsumerWidget {
  final SocialEvent event;
  const ExportReportsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(hasExportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportação e Relatórios'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: hasAccess
          ? _buildExportView(context, ref)
          : _buildLockedView(context, ref),
    );
  }

  Widget _buildLockedView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.file_download_off, size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text(
              'Exportação e Relatórios',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Exporte listas de participantes, gere certificados de participação e relatórios personalizados.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _purchaseAddon(context, ref),
              icon: const Icon(Icons.lock_open),
              label: const Text('Desbloquear — R\$ 9,90/mês'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {},
              child: const Text('Incluído no plano Profissional'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportView(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info do evento
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(event.category.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${event.confirmedAttendees} participantes confirmados',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _sectionTitle('📄 Exportar Dados'),
          const SizedBox(height: 12),

          _exportOption(
            context,
            icon: Icons.table_chart,
            title: 'Lista de Participantes (CSV)',
            description: 'Nome, email, horário de check-in/checkout',
            format: 'CSV',
            color: Colors.green,
            onTap: () => _simulateExport(context, 'CSV'),
          ),
          const SizedBox(height: 8),
          _exportOption(
            context,
            icon: Icons.picture_as_pdf,
            title: 'Relatório Completo (PDF)',
            description: 'Estatísticas, gráficos, resumo do evento',
            format: 'PDF',
            color: Colors.red,
            onTap: () => _simulateExport(context, 'PDF'),
          ),
          const SizedBox(height: 8),
          _exportOption(
            context,
            icon: Icons.grid_on,
            title: 'Planilha Detalhada (Excel)',
            description: 'Todos os dados do evento em formato Excel',
            format: 'XLSX',
            color: Colors.teal,
            onTap: () => _simulateExport(context, 'Excel'),
          ),
          const SizedBox(height: 8),
          _exportOption(
            context,
            icon: Icons.code,
            title: 'Dados Brutos (JSON)',
            description: 'Para integrações com outros sistemas',
            format: 'JSON',
            color: Colors.purple,
            onTap: () => _simulateExport(context, 'JSON'),
          ),

          const SizedBox(height: 32),
          _sectionTitle('📜 Certificados de Participação'),
          const SizedBox(height: 12),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber, width: 2),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.withOpacity(0.05),
                          Colors.orange.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                        const SizedBox(height: 8),
                        const Text(
                          'CERTIFICADO DE PARTICIPAÇÃO',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.title,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(event.startDate),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _simulateExport(context, 'Certificados'),
                      icon: const Icon(Icons.card_membership),
                      label: Text(
                        'Gerar ${event.confirmedAttendees} Certificados',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          _sectionTitle('📊 Relatórios Personalizados'),
          const SizedBox(height: 12),

          _reportTemplate(
            title: 'Resumo Executivo',
            description: 'Visão geral para apresentação a stakeholders',
            icon: Icons.summarize,
            color: AppTheme.primaryColor,
            onTap: () => _simulateExport(context, 'Resumo Executivo'),
          ),
          const SizedBox(height: 8),
          _reportTemplate(
            title: 'Relatório de Impacto',
            description: 'Alcance, engajamento e métricas de impacto social',
            icon: Icons.public,
            color: Colors.green,
            onTap: () => _simulateExport(context, 'Relatório de Impacto'),
          ),
          const SizedBox(height: 8),
          _reportTemplate(
            title: 'Relatório de Segurança',
            description: 'Densidade, fluxo de pessoas e pontos críticos',
            icon: Icons.shield,
            color: Colors.red,
            onTap: () => _simulateExport(context, 'Relatório de Segurança'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _exportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String format,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            format,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _reportTemplate({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: Icon(Icons.arrow_forward_ios, color: color, size: 16),
          onPressed: onTap,
        ),
        onTap: onTap,
      ),
    );
  }

  void _simulateExport(BuildContext context, String format) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 2), () {
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ $format exportado com sucesso!'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'ABRIR',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
        });
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Text('Gerando $format...'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _purchaseAddon(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download, color: Colors.orange),
            SizedBox(width: 8),
            Text('Exportação e Relatórios'),
          ],
        ),
        content: const Text(
          'Ativar addon de Exportação e Relatórios por R\$ 9,90/mês?\n\n'
          'Inclui:\n'
          '• Export CSV, PDF, Excel, JSON\n'
          '• Certificados de participação\n'
          '• Relatórios personalizados',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Ativar R\$ 9,90/mês'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(subscriptionProvider.notifier).addAddon(AddonType.exportReports);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 Exportação e Relatórios ativado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
