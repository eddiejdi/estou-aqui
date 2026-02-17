import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/coalition.dart';
import '../../models/event.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

// Conditional imports for iframe on web
// ignore: avoid_web_libraries_in_flutter
import 'coalition_grafana_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'coalition_grafana_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;

const _kGrafanaBaseUrl = 'https://www.rpa4all.com/grafana';
const _kCoalitionDashboardToken = 'eb027d48df8e4c948975669d3be5ac54';

class CoalitionDetailScreen extends ConsumerStatefulWidget {
  final String coalitionId;
  const CoalitionDetailScreen({super.key, required this.coalitionId});

  @override
  ConsumerState<CoalitionDetailScreen> createState() => _CoalitionDetailScreenState();
}

class _CoalitionDetailScreenState extends ConsumerState<CoalitionDetailScreen>
    with SingleTickerProviderStateMixin {
  Coalition? _coalition;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  late TabController _tabCtrl;
  bool _iframeRegistered = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _load();
  }

  void _registerGrafanaIframe(String coalitionId) {
    if (!kIsWeb || _iframeRegistered) return;
    _iframeRegistered = true;

    final grafanaUrl =
        '$_kGrafanaBaseUrl/public-dashboards/$_kCoalitionDashboardToken?orgId=1&theme=dark&kiosk';
    final viewType = 'grafana-coalition-$coalitionId';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = grafanaUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen'
        ..setAttribute('loading', 'lazy');
      return iframe;
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      final data = await api.getCoalition(widget.coalitionId);
      final stats = await api.getCoalitionStats(widget.coalitionId);
      if (mounted) {
        _registerGrafanaIframe(widget.coalitionId);
        setState(() {
          _coalition = Coalition.fromJson(data);
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coalizão')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_coalition == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coalizão')),
        body: const Center(child: Text('Coalizão não encontrada')),
      );
    }

    final c = _coalition!;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(c.name, style: const TextStyle(fontSize: 15)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.6),
                      const Color(0xFF1A237E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (c.hashtag != null)
                          Text(c.hashtag!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _headerStat('${c.totalEvents}', 'Eventos'),
                            _headerStat('${c.totalAttendees}', 'Pessoas'),
                            _headerStat('${c.totalCities}', 'Cidades'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {/* share */},
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: 'Eventos'),
                Tab(text: 'Mapa'),
                Tab(text: 'Impacto'),
                Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Dashboard'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildEventsTab(c),
            _buildMapTab(c),
            _buildImpactTab(c),
            _buildDashboardTab(c),
          ],
        ),
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // ─── Events Tab ───
  Widget _buildEventsTab(Coalition c) {
    if (c.events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Nenhum evento vinculado', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: c.events.length,
      itemBuilder: (context, i) {
        final event = c.events[i];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(SocialEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          child: Text(event.category.emoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.city ?? event.locationDisplay,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${event.confirmedAttendees} participantes',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: event.status == EventStatus.active
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.status == EventStatus.active ? 'AO VIVO' : event.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: event.status == EventStatus.active ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => context.push('/event/${event.id}'),
      ),
    );
  }

  // ─── Map Tab ───
  Widget _buildMapTab(Coalition c) {
    if (c.events.isEmpty) {
      return const Center(child: Text('Sem eventos para exibir no mapa'));
    }

    // Mapa simplificado — grid visual mostrando cidades
    final cities = <String, List<SocialEvent>>{};
    for (final e in c.events) {
      final city = e.city ?? 'Sem cidade';
      cities.putIfAbsent(city, () => []).add(e);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribuição por Cidade',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...cities.entries.map((entry) {
            final attendees = entry.value.fold<int>(0, (sum, e) => sum + e.confirmedAttendees);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_city, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '${entry.value.length} evento${entry.value.length > 1 ? 's' : ''} · $attendees participantes',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Text('${entry.value.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Impact Tab ───
  Widget _buildImpactTab(Coalition c) {
    final stats = _stats;
    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalConfirmed = stats['totalConfirmedAttendees'] as int? ?? 0;
    final totalEstimated = stats['totalEstimatedAttendees'] as int? ?? 0;
    final totalCities = stats['totalCities'] as int? ?? 0;
    final totalStates = stats['totalStates'] as int? ?? 0;
    final timeline = (stats['timeline'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final cities = (stats['cities'] as List?)?.cast<String>() ?? [];
    final states = (stats['states'] as List?)?.cast<String>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPIs
          const Text('Impacto Nacional', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _kpiCard('Confirmados', '$totalConfirmed', Icons.people, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Estimados', '$totalEstimated', Icons.groups, Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _kpiCard('Cidades', '$totalCities', Icons.location_city, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Estados', '$totalStates', Icons.map, Colors.purple)),
            ],
          ),
          const SizedBox(height: 24),

          // Timeline
          if (timeline.isNotEmpty) ...[
            const Text('Timeline de Eventos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: timeline.map((entry) {
                  final count = entry['events'] as int? ?? 1;
                  final maxCount = timeline.fold<int>(1, (m, e) => max(m, e['events'] as int? ?? 1));
                  final heightFrac = count / maxCount;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            height: 80 * heightFrac,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (entry['date'] as String? ?? '').substring(5),
                            style: const TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // States
          if (states.isNotEmpty) ...[
            const Text('Estados Participantes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: states.map((s) => Chip(
                avatar: const Icon(Icons.flag, size: 16),
                label: Text(s),
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Cities
          if (cities.isNotEmpty) ...[
            const Text('Cidades Participantes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cities.map((c) => Chip(
                avatar: const Icon(Icons.location_on, size: 16),
                label: Text(c),
              )).toList(),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Dashboard Tab (Grafana público da Coalizão) ───
  Widget _buildDashboardTab(Coalition c) {
    final hasGrafana = ref.watch(hasGrafanaProvider);

    if (!hasGrafana) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6600), Color(0xFFF5A623)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6600).withValues(alpha: 0.3),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: const Icon(Icons.dashboard, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'Dashboard da Coalizão',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Visualize métricas em tempo real de todos os ${c.totalEvents} eventos da coalizão em um único painel.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {/* unlock dialog */},
                icon: const Icon(Icons.lock_open),
                label: const Text('Desbloquear — R\$ 14,90/mês'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Dashboard desbloqueado
    if (kIsWeb) {
      return _buildWebDashboard(c);
    }
    return _buildNativeDashboard(c);
  }

  Widget _buildWebDashboard(Coalition c) {
    // URL construída via constantes — sem hardcode
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: const Color(0xFF1A1D21),
          child: Row(
            children: [
              const Icon(Icons.shield, color: Colors.green, size: 14),
              const SizedBox(width: 6),
              Text(
                'Painel público da coalizão • ${c.totalEvents} eventos',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const Spacer(),
              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
              const SizedBox(width: 4),
              Text('LIVE', style: TextStyle(color: Colors.green[400], fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: HtmlElementView(viewType: 'grafana-coalition-${c.id}'),
        ),
      ],
    );
  }

  Widget _buildNativeDashboard(Coalition c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2228),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2C3036)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6600), Color(0xFFF5A623)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dashboard, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${c.totalEvents} eventos · ${c.totalCities} cidades',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.isActive ? Colors.green : Colors.grey,
                      )),
                      const SizedBox(width: 4),
                      Text(
                        c.isActive ? 'ATIVA' : 'ENCERRADA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: c.isActive ? Colors.green : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // KPIs
          Row(
            children: [
              Expanded(child: _dashKpi('Eventos', '${c.totalEvents}', Icons.event, Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _dashKpi('Participantes', '${c.totalAttendees}', Icons.people, Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _dashKpi('Cidades', '${c.totalCities}', Icons.location_city, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _dashKpi('Impacto', c.totalAttendees > 1000 ? 'ALTO' : c.totalAttendees > 100 ? 'MÉDIO' : 'BAIXO',
                  Icons.trending_up, c.totalAttendees > 1000 ? Colors.red : Colors.amber)),
            ],
          ),
          const SizedBox(height: 16),

          // Eventos por cidade (bar chart simulado)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2228),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C3036)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Participantes por Cidade', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                ...c.cities.take(5).map((city) {
                  final frac = 0.3 + Random().nextDouble() * 0.7;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 90, child: Text(city, style: const TextStyle(color: Colors.white60, fontSize: 12))),
                        Expanded(
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: const Color(0xFF2C3036),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: frac,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(colors: [Color(0xFFFF6600), Color(0xFFF5A623)]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lista de eventos com status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2228),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C3036)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Eventos da Coalizão', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                ...c.events.take(10).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.title, style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('${e.confirmedAttendees}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Center(
            child: Text(
              'Dados em tempo real via Grafana • Acesso restrito a eventos',
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _dashKpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2228),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C3036)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }
}
