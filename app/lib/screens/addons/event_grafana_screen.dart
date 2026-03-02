import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/theme.dart';

// ignore: avoid_web_libraries_in_flutter
import 'event_grafana_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'event_grafana_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;

/// URLs dos dashboards públicos Grafana (somente eventos, sem acesso ao homelab)
const _kGrafanaBaseUrl = 'https://www.rpa4all.com/grafana';
const _kEventDashboardToken = '20724d6938144eeba8287cfb475bcf52';
const _kCoalitionDashboardToken = 'eb027d48df8e4c948975669d3be5ac54';

/// Tela de Dashboard Grafana para um evento (Seção Bônus paga)
/// Na versão web, incorpora o dashboard real do Grafana via iframe público.
/// No mobile, exibe um dashboard simulado estilo Grafana.
/// Usuários só têm acesso aos painéis de eventos — nunca ao homelab.
class EventGrafanaScreen extends ConsumerStatefulWidget {
  final SocialEvent event;
  const EventGrafanaScreen({super.key, required this.event});

  @override
  ConsumerState<EventGrafanaScreen> createState() => _EventGrafanaScreenState();
}

class _EventGrafanaScreenState extends ConsumerState<EventGrafanaScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final _random = Random();
  String _activeTab = 'evento'; // 'evento' | 'coalizao'

  // Métricas simuladas "em tempo real"
  late int _currentAttendees;
  late int _peakAttendees;
  late double _avgDensity;
  late int _checkinsLast5Min;
  late double _sentiment;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _currentAttendees = widget.event.confirmedAttendees;
    _peakAttendees = (widget.event.confirmedAttendees * 1.3).round();
    _avgDensity = widget.event.areaSquareMeters != null &&
            widget.event.areaSquareMeters! > 0
        ? widget.event.confirmedAttendees / widget.event.areaSquareMeters!
        : 1.5;
    _checkinsLast5Min = 5 + _random.nextInt(20);
    _sentiment = 0.7 + _random.nextDouble() * 0.25;

    // Registrar factories de iframe para web (Grafana público)
    if (kIsWeb) {
      _registerGrafanaIframes();
    }
  }

  void _registerGrafanaIframes() {
    final eventUrl =
        '$_kGrafanaBaseUrl/public-dashboards/$_kEventDashboardToken?orgId=1&theme=dark&kiosk';
    final coalitionUrl =
        '$_kGrafanaBaseUrl/public-dashboards/$_kCoalitionDashboardToken?orgId=1&theme=dark&kiosk';

    final eventViewType = 'grafana-evento-${widget.event.id}';
    final coalitionViewType = 'grafana-coalizao-${widget.event.id}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(eventViewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = eventUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen'
        ..setAttribute('loading', 'lazy');
      return iframe;
    });

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(coalitionViewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = coalitionUrl
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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAccess = ref.watch(hasGrafanaProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF181B1F),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dashboard, size: 20),
            const SizedBox(width: 8),
            const Text('Dashboard'),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasAccess
                        ? Colors.green.withOpacity(0.5 + _pulseController.value * 0.5)
                        : Colors.grey,
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            Text(
              hasAccess ? 'LIVE' : 'LOCKED',
              style: TextStyle(
                fontSize: 10,
                color: hasAccess ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1D21),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: hasAccess
          ? (kIsWeb ? _buildGrafanaEmbedWeb(context) : _buildGrafanaDashboard(context))
          : _buildLockedView(context),
    );
  }

  /// Dashboard real via iframe público do Grafana (somente web).
  /// Usuário só vê painéis de eventos — sem acesso ao homelab.
  Widget _buildGrafanaEmbedWeb(BuildContext context) {
    return Column(
      children: [
        // Tab bar: Evento | Visão Nacional (Coalizão)
        Container(
          color: const Color(0xFF1A1D21),
          child: Row(
            children: [
              _tabButton('evento', 'Dashboard do Evento', Icons.event),
              _tabButton('coalizao', 'Visão Nacional', Icons.public),
            ],
          ),
        ),
        // Grafana iframe
        Expanded(
          child: Container(
            color: const Color(0xFF181B1F),
            child: HtmlElementView(
              viewType: _activeTab == 'evento'
                  ? 'grafana-evento-${widget.event.id}'
                  : 'grafana-coalizao-${widget.event.id}',
            ),
          ),
        ),
        // Footer de segurança
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: const Color(0xFF1A1D21),
          child: Row(
            children: [
              const Icon(Icons.shield, color: Colors.green, size: 14),
              const SizedBox(width: 6),
              Text(
                'Acesso restrito a painéis de eventos • Dados públicos',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(color: Colors.green[400], fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabButton(String tab, String label, IconData icon) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFFFF6600) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? const Color(0xFFFF6600) : Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedView(BuildContext context) {
    return Container(
      color: const Color(0xFF181B1F),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Grafana logo simulado
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6600), Color(0xFFF5A623)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6600).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.dashboard, color: Colors.white, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'Dashboard Grafana',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Painel em tempo real gerado automaticamente para seu evento',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              // Preview borrado
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Stack(
                  children: [
                    // Preview borrado
                    Opacity(
                      opacity: 0.15,
                      child: _buildGrafanaDashboard(context),
                    ),
                    // Cadeado central
                    const Center(
                      child: Icon(Icons.lock, color: Colors.white54, size: 48),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _purchaseAddon(context),
                icon: const Icon(Icons.lock_open),
                label: const Text('Desbloquear Dashboard — R\$ 14,90/mês'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Incluído no plano Profissional',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrafanaDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do evento
          _grafanaPanel(
            child: Row(
              children: [
                Text(widget.event.category.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.event.locationDisplay,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _statusBadge(),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Row 1: KPIs grandes
          Row(
            children: [
              Expanded(child: _kpiPanel(
                'Participantes Atual',
                '$_currentAttendees',
                Icons.people,
                Colors.green,
              )),
              const SizedBox(width: 8),
              Expanded(child: _kpiPanel(
                'Pico Máximo',
                '$_peakAttendees',
                Icons.trending_up,
                Colors.amber,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _kpiPanel(
                'Densidade',
                '${_avgDensity.toStringAsFixed(1)} p/m²',
                Icons.grid_on,
                _densityColor(_avgDensity),
              )),
              const SizedBox(width: 8),
              Expanded(child: _kpiPanel(
                'Check-ins (5 min)',
                '$_checkinsLast5Min',
                Icons.add_circle,
                Colors.cyan,
              )),
            ],
          ),
          const SizedBox(height: 12),

          // Gráfico de série temporal
          _grafanaPanel(
            title: 'Participantes — Série Temporal',
            height: 200,
            child: _buildTimeSeriesChart(),
          ),
          const SizedBox(height: 8),

          // Row 2: Gauges
          Row(
            children: [
              Expanded(
                child: _grafanaPanel(
                  title: 'Sentimento',
                  height: 160,
                  child: _buildSentimentGauge(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _grafanaPanel(
                  title: 'Capacidade',
                  height: 160,
                  child: _buildCapacityGauge(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tabela de últimos check-ins
          _grafanaPanel(
            title: 'Últimos Check-ins',
            height: 200,
            child: _buildCheckinTable(),
          ),
          const SizedBox(height: 8),

          // Histograma de permanência
          _grafanaPanel(
            title: 'Tempo de Permanência (minutos)',
            height: 160,
            child: _buildDurationHistogram(),
          ),
          const SizedBox(height: 8),

          // Alertas
          _grafanaPanel(
            title: 'Alertas',
            child: _buildAlerts(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _grafanaPanel({
    String? title,
    double? height,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2228),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C3036)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2C3036)),
                ),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiPanel(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2228),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C3036)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSeriesChart() {
    final points = List.generate(48, (i) {
      final t = i / 2.0;
      final base = _currentAttendees.toDouble();
      double val;
      if (t < 4) {
        val = base * 0.05;
      } else if (t < 8) {
        val = base * (0.05 + (t - 4) * 0.05);
      } else if (t < 14) {
        val = base * (0.25 + (t - 8) * 0.12);
      } else if (t < 16) {
        val = base * 0.97;
      } else if (t < 20) {
        val = base * (0.97 - (t - 16) * 0.15);
      } else {
        val = base * 0.25;
      }
      return val + _random.nextDouble() * base * 0.05;
    });

    final maxVal = points.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points.asMap().entries.map((entry) {
        final h = maxVal > 0 ? (entry.value / maxVal) * 150 : 0.0;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            height: h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFF73BF69).withOpacity(0.3),
                  const Color(0xFF73BF69),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(1)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSentimentGauge() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _sentiment,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFF2C3036),
                  valueColor: AlwaysStoppedAnimation(
                    _sentiment > 0.7
                        ? Colors.green
                        : _sentiment > 0.4
                            ? Colors.amber
                            : Colors.red,
                  ),
                ),
                Text(
                  '${(_sentiment * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sentiment > 0.7 ? '😊 Positivo' : _sentiment > 0.4 ? '😐 Neutro' : '😟 Negativo',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityGauge() {
    final capacity = _currentAttendees / (_peakAttendees * 1.2);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: capacity.clamp(0, 1),
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFF2C3036),
                  valueColor: AlwaysStoppedAnimation(
                    capacity > 0.9
                        ? Colors.red
                        : capacity > 0.7
                            ? Colors.amber
                            : Colors.green,
                  ),
                ),
                Text(
                  '${(capacity * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            capacity > 0.9 ? '🔴 Lotado' : capacity > 0.7 ? '🟡 Quase cheio' : '🟢 OK',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinTable() {
    final names = ['Ana S.', 'Carlos M.', 'Julia R.', 'Pedro L.', 'Maria F.', 'Lucas G.'];
    final now = DateTime.now();

    return ListView.builder(
      itemCount: names.length,
      itemBuilder: (_, i) {
        final time = now.subtract(Duration(minutes: i * 3 + _random.nextInt(5)));
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: i % 2 == 0 ? const Color(0xFF1E2228) : const Color(0xFF232830),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  names[i],
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Color(0xFF73BF69), fontSize: 12),
                ),
              ),
              Text(
                '${_random.nextInt(3) + 1} min atrás',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDurationHistogram() {
    final buckets = [
      ('0-15', 0.15),
      ('15-30', 0.25),
      ('30-60', 0.35),
      ('60-120', 0.18),
      ('120+', 0.07),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: buckets.map((b) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${(b.$2 * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Container(
                  height: b.$2 * 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5794F2),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  b.$1,
                  style: TextStyle(color: Colors.grey[500], fontSize: 9),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlerts() {
    final alerts = <_AlertItem>[];
    if (_avgDensity > 3.0) {
      alerts.add(_AlertItem(
        level: 'critical',
        message: 'Densidade crítica: ${_avgDensity.toStringAsFixed(1)} p/m²',
        time: '2 min atrás',
      ));
    }
    if (_currentAttendees > _peakAttendees * 0.9) {
      alerts.add(_AlertItem(
        level: 'warning',
        message: 'Capacidade acima de 90%',
        time: '5 min atrás',
      ));
    }
    alerts.add(_AlertItem(
      level: 'info',
      message: 'Dashboard atualizado automaticamente',
      time: 'agora',
    ));

    return Column(
      children: alerts.map((a) {
        final color = a.level == 'critical'
            ? Colors.red
            : a.level == 'warning'
                ? Colors.amber
                : Colors.cyan;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Row(
            children: [
              Icon(
                a.level == 'critical'
                    ? Icons.error
                    : a.level == 'warning'
                        ? Icons.warning
                        : Icons.info,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.message,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
              Text(
                a.time,
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statusBadge() {
    final isLive = widget.event.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isLive ? Colors.green : Colors.grey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLive ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isLive ? 'LIVE' : 'OFFLINE',
            style: TextStyle(
              color: isLive ? Colors.green : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _densityColor(double density) {
    if (density < 1.0) return Colors.green;
    if (density < 2.0) return Colors.amber;
    if (density < 3.5) return Colors.orange;
    return Colors.red;
  }

  Future<void> _purchaseAddon(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dashboard, color: Color(0xFFFF6600)),
            SizedBox(width: 8),
            Text('Dashboard Grafana'),
          ],
        ),
        content: const Text(
          'Ativar Dashboard Grafana em tempo real por R\$ 14,90/mês?\n\n'
          'Inclui:\n'
          '• KPIs em tempo real\n'
          '• Gráficos de série temporal\n'
          '• Gauge de sentimento e capacidade\n'
          '• Tabela de check-ins\n'
          '• Alertas automáticos',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6600),
            ),
            child: const Text('Ativar R\$ 14,90/mês'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(subscriptionProvider.notifier).addAddon(AddonType.grafanaDashboard);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📈 Dashboard Grafana ativado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

class _AlertItem {
  final String level;
  final String message;
  final String time;
  const _AlertItem({
    required this.level,
    required this.message,
    required this.time,
  });
}
