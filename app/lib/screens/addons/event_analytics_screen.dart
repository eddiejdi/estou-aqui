import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/theme.dart';

/// Tela de Análise Avançada de um evento (Addon 1)
class EventAnalyticsScreen extends ConsumerStatefulWidget {
  final SocialEvent event;
  const EventAnalyticsScreen({super.key, required this.event});

  @override
  ConsumerState<EventAnalyticsScreen> createState() => _EventAnalyticsScreenState();
}

class _EventAnalyticsScreenState extends ConsumerState<EventAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAccess = ref.watch(hasAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise Avançada'),
        backgroundColor: AppTheme.primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.timeline), text: 'Evolução'),
            Tab(icon: Icon(Icons.map), text: 'Heatmap'),
            Tab(icon: Icon(Icons.people), text: 'Demografia'),
          ],
        ),
      ),
      body: hasAccess
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildEvolutionTab(),
                _buildHeatmapTab(),
                _buildDemographicsTab(),
              ],
            )
          : _buildLockedView(context),
    );
  }

  Widget _buildLockedView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Análise Avançada',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Desbloqueie estatísticas detalhadas, heatmap de participantes e dados demográficos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showPurchaseDialog(context),
              icon: const Icon(Icons.star),
              label: const Text('Desbloquear — R\$ 19,90/mês'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _showPurchaseDialog(context),
              child: const Text('Ou assine o plano Profissional'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPurchaseDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📊 Análise Avançada'),
        content: const Text(
          'Deseja ativar o addon de Análise Avançada por R\$ 19,90/mês?\n\n'
          'Inclui:\n'
          '• Gráficos de evolução temporal\n'
          '• Heatmap de participantes\n'
          '• Dados demográficos\n'
          '• Melhor horário para eventos',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(subscriptionProvider.notifier).addAddon(AddonType.analytics);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📊 Análise Avançada ativada!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ─── Tab: Evolução temporal ───────────────────────────

  Widget _buildEvolutionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('📈 Evolução de Participantes'),
          const SizedBox(height: 8),
          _buildTimelineChart(),
          const SizedBox(height: 24),
          _sectionTitle('⏰ Melhor Horário'),
          const SizedBox(height: 8),
          _buildPeakHoursCard(),
          const SizedBox(height: 24),
          _sectionTitle('📊 Resumo Estatístico'),
          const SizedBox(height: 8),
          _buildStatsSummary(),
        ],
      ),
    );
  }

  Widget _buildTimelineChart() {
    // Dados simulados de evolução
    final dataPoints = List.generate(24, (i) {
      final hour = i;
      final base = widget.event.confirmedAttendees.toDouble();
      final peak = base * 1.5;
      double val;
      if (hour < 8) {
        val = base * 0.1;
      } else if (hour < 12) {
        val = base * 0.3 + (hour - 8) * (base * 0.15);
      } else if (hour < 15) {
        val = peak;
      } else if (hour < 18) {
        val = peak - (hour - 15) * (base * 0.2);
      } else {
        val = base * 0.2;
      }
      return val.clamp(0, peak);
    });

    final maxVal = dataPoints.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Participantes ao longo do dia',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: dataPoints.asMap().entries.map((entry) {
                  final height = maxVal > 0 ? (entry.value / maxVal) * 180 : 0.0;
                  final isPeak = entry.value == maxVal;
                  return Expanded(
                    child: Tooltip(
                      message: '${entry.key}h: ${entry.value.round()} pessoas',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        height: height,
                        decoration: BoxDecoration(
                          color: isPeak
                              ? Colors.amber
                              : AppTheme.primaryColor.withOpacity(0.7),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0h', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text('6h', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text('12h', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text('18h', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text('23h', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakHoursCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.access_time, color: Colors.amber, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pico de Público',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '12:00 — 15:00',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('Início', '08:00', Icons.play_arrow, Colors.green),
                _miniStat('Pico', '13:30', Icons.trending_up, Colors.amber),
                _miniStat('Fim', '19:00', Icons.stop, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildStatsSummary() {
    final event = widget.event;
    final density = event.areaSquareMeters != null && event.areaSquareMeters! > 0
        ? event.confirmedAttendees / event.areaSquareMeters!
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _statRow('Confirmados', '${event.confirmedAttendees}', Icons.check_circle, Colors.green),
            _statRow('Estimativa total', '${event.estimatedAttendees}', Icons.people, AppTheme.primaryColor),
            _statRow('Área (m²)', '${event.areaSquareMeters?.round() ?? "N/A"}', Icons.crop_square, Colors.orange),
            _statRow('Densidade', '${density.toStringAsFixed(2)} p/m²', Icons.grid_on, Colors.purple),
            _statRow('Duração', _eventDuration(), Icons.timer, Colors.teal),
            _statRow('Taxa retenção', '${(70 + Random().nextInt(25))}%', Icons.replay, Colors.indigo),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _eventDuration() {
    if (widget.event.endDate == null) return 'Em andamento';
    final dur = widget.event.endDate!.difference(widget.event.startDate);
    if (dur.inHours > 0) return '${dur.inHours}h ${dur.inMinutes % 60}min';
    return '${dur.inMinutes}min';
  }

  // ─── Tab: Heatmap ────────────────────────────────────

  Widget _buildHeatmapTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🗺️ Mapa de Calor de Participantes'),
          const SizedBox(height: 8),
          _buildHeatmapSimulation(),
          const SizedBox(height: 24),
          _sectionTitle('📍 Distribuição por Região'),
          const SizedBox(height: 8),
          _buildRegionDistribution(),
        ],
      ),
    );
  }

  Widget _buildHeatmapSimulation() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const RadialGradient(
            center: Alignment(0.1, -0.2),
            radius: 0.8,
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFF6600),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0x0000FF00),
            ],
            stops: [0.0, 0.2, 0.4, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Overlay com info
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendDot(Colors.red, 'Alta'),
                    const SizedBox(width: 12),
                    _legendDot(Colors.orange, 'Média'),
                    const SizedBox(width: 12),
                    _legendDot(Colors.yellow, 'Baixa'),
                    const SizedBox(width: 12),
                    _legendDot(Colors.green, 'Mínima'),
                  ],
                ),
              ),
            ),
            // Pin central
            const Center(
              child: Icon(Icons.location_on, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }

  Widget _buildRegionDistribution() {
    final regions = [
      ('Centro', 42, Colors.red),
      ('Zona Norte', 25, Colors.orange),
      ('Zona Sul', 18, Colors.yellow[700]!),
      ('Zona Leste', 10, Colors.green),
      ('Zona Oeste', 5, Colors.blue),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: regions.map((r) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(r.$1, style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: r.$2 / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(r.$3),
                        minHeight: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${r.$2}%',
                      style: TextStyle(fontWeight: FontWeight.bold, color: r.$3)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Tab: Demografia ──────────────────────────────────

  Widget _buildDemographicsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('👥 Perfil dos Participantes'),
          const SizedBox(height: 8),
          _buildAgeDistribution(),
          const SizedBox(height: 24),
          _sectionTitle('📱 Origem dos Check-ins'),
          const SizedBox(height: 8),
          _buildOriginCard(),
          const SizedBox(height: 24),
          _sectionTitle('🔄 Participantes Recorrentes'),
          const SizedBox(height: 8),
          _buildRecurringCard(),
        ],
      ),
    );
  }

  Widget _buildAgeDistribution() {
    final ages = [
      ('18-24', 0.35, Colors.blue),
      ('25-34', 0.30, Colors.green),
      ('35-44', 0.18, Colors.orange),
      ('45-54', 0.10, Colors.purple),
      ('55+', 0.07, Colors.red),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Faixa Etária (estimada)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...ages.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child:
                            Text(a.$1, style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: a.$2,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(a.$3),
                            minHeight: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(a.$2 * 100).round()}%',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: a.$3),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _originRow('Android', 0.62, Icons.android, Colors.green),
            _originRow('iOS', 0.28, Icons.phone_iphone, Colors.grey),
            _originRow('Web', 0.10, Icons.web, AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _originRow(String label, double pct, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(pct * 100).round()}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildRecurringCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.repeat, color: Colors.indigo, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Participantes Recorrentes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(30 + Random().nextInt(40))}% já participaram de outros eventos',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}
