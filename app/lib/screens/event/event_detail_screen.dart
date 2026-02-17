import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/theme.dart';
import '../../widgets/crowd_gauge.dart';
import '../../widgets/checkin_button.dart';
import '../addons/event_analytics_screen.dart';
import '../addons/export_reports_screen.dart';
import '../addons/event_grafana_screen.dart';
import '../addons/blue_check_screen.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(selectedEventProvider.notifier).loadEvent(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    final eventState = ref.watch(selectedEventProvider);

    return Scaffold(
      body: eventState.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Evento não encontrado'));
          }
          return _buildEventDetail(context, event);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  Widget _buildEventDetail(BuildContext context, SocialEvent event) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return CustomScrollView(
      slivers: [
        // App Bar com imagem
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(event.title, style: const TextStyle(fontSize: 16)),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (event.imageUrl != null)
                  Image.network(event.imageUrl!, fit: BoxFit.cover)
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        event.category.emoji,
                        style: const TextStyle(fontSize: 80),
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                // TODO: Compartilhar evento
              },
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Row(
                  children: [
                    _buildStatusBadge(event.status),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${event.category.emoji} ${event.category.label}'),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                    if (event.isVerified) ...[
                      const SizedBox(width: 8),
                      const Chip(
                        avatar: Icon(Icons.verified, size: 16, color: AppTheme.primaryColor),
                        label: Text('Verificado'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Estimativa de público ───────────────
                CrowdGauge(
                  confirmedCheckins: event.confirmedAttendees,
                  estimatedAttendees: event.estimatedAttendees,
                ),
                const SizedBox(height: 24),

                // ─── Check-in ────────────────────────────
                CheckinButton(eventId: widget.eventId, event: event),
                const SizedBox(height: 24),

                // ─── Informações ─────────────────────────
                const Text('Sobre', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(event.description, style: const TextStyle(fontSize: 15, height: 1.5)),
                const SizedBox(height: 24),

                // Data e hora
                _infoRow(Icons.calendar_today, 'Início', dateFormat.format(event.startDate)),
                if (event.endDate != null)
                  _infoRow(Icons.calendar_today, 'Término', dateFormat.format(event.endDate!)),
                _infoRow(Icons.location_on, 'Local', event.locationDisplay),

                // Percurso da passeata (início → fim)
                if (event.isMarcha) ...[
                  _infoRow(Icons.flag, 'Chegada', event.endLocationDisplay),
                  // Botão para ver percurso completo no mapa
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => _openRoute(event),
                        icon: const Icon(Icons.route, size: 20),
                        label: const Text(
                          'Ver percurso completo',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],

                // Botão "Ir para lá" — abre app de navegação
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openNavigation(event),
                      icon: const Icon(Icons.navigation, size: 22),
                      label: const Text(
                        'Ir para lá',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                    ),
                  ),
                ),

                if (event.organizer != null)
                  _infoRow(Icons.person, 'Organizador', event.organizer!.name),
                const SizedBox(height: 24),

                // Tags
                if (event.tags.isNotEmpty) ...[
                  const Text('Tags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: event.tags.map((tag) => Chip(label: Text('#$tag'))).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Coalizão vinculada
                if (event.coalitionId != null) ...[
                  InkWell(
                    onTap: () => context.push('/coalition/${event.coalitionId}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.groups, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Parte de uma Coalizão',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Toque para ver todos os eventos da causa',
                                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Botão para vincular a uma coalizão (reunir protestos pela mesma causa)
                  _JoinCoalitionButton(event: event, onJoined: () {
                    ref.read(selectedEventProvider.notifier).loadEvent(widget.eventId);
                  }),
                  const SizedBox(height: 16),
                ],

                // Botão Chat Telegram
                _TelegramChatButton(eventId: widget.eventId),
                const SizedBox(height: 24),

                // ━━━ Premium Features ━━━
                _PremiumFeaturesSection(event: event),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(EventStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case EventStatus.active:
        color = AppTheme.secondaryColor;
        label = 'AO VIVO';
        icon = Icons.circle;
        break;
      case EventStatus.scheduled:
        color = AppTheme.primaryColor;
        label = 'AGENDADO';
        icon = Icons.schedule;
        break;
      case EventStatus.ended:
        color = Colors.grey;
        label = 'ENCERRADO';
        icon = Icons.check_circle;
        break;
      case EventStatus.cancelled:
        color = AppTheme.errorColor;
        label = 'CANCELADO';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Abre percurso completo da passeata (ponto A → ponto B) no Google Maps
  Future<void> _openRoute(SocialEvent event) async {
    if (event.endLatitude == null || event.endLongitude == null) return;

    final originLat = event.latitude;
    final originLng = event.longitude;
    final destLat = event.endLatitude!;
    final destLng = event.endLongitude!;

    // Google Maps directions URL com origem e destino + modo a pé
    final mapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$originLat,$originLng'
      '&destination=$destLat,$destLng'
      '&travelmode=walking',
    );

    try {
      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhum app de mapas encontrado'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir mapa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Abre app de navegação (Google Maps, Waze, etc.) com chooser do sistema
  Future<void> _openNavigation(SocialEvent event) async {
    final lat = event.latitude;
    final lng = event.longitude;
    final label = Uri.encodeComponent(event.title);

    // geo: URI abre o chooser do sistema para o usuário escolher o app
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');

    // Fallback: Google Maps URL (funciona em qualquer plataforma)
    final mapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhum app de navegação encontrado'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir navegação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Widget de botão para abrir/criar grupo Telegram do evento
class _TelegramChatButton extends ConsumerStatefulWidget {
  final String eventId;
  const _TelegramChatButton({required this.eventId});

  @override
  ConsumerState<_TelegramChatButton> createState() => _TelegramChatButtonState();
}

class _TelegramChatButtonState extends ConsumerState<_TelegramChatButton> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _groups = [];
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getTelegramGroups(widget.eventId);
      if (mounted) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
          _hasLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasLoaded = true);
    }
  }

  Future<void> _joinGroup() async {
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.joinTelegramGroup(widget.eventId);

      if (!mounted) return;

      if (data['success'] == true) {
        final group = data['group'] as Map<String, dynamic>;
        final inviteLink = group['inviteLink'] as String?;

        if (inviteLink != null && inviteLink.startsWith('http')) {
          final uri = Uri.parse(inviteLink);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] as String? ?? 'Grupo disponível!'),
            backgroundColor: Colors.green,
          ),
        );

        _loadGroups();
      } else if (data['needsManualSetup'] == true) {
        _showManualSetupDialog();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showManualSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final linkController = TextEditingController();
        return AlertDialog(
          title: const Text('Vincular Grupo Telegram'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Crie um grupo no Telegram e cole o link de convite abaixo:'),
              const SizedBox(height: 16),
              TextField(
                controller: linkController,
                decoration: const InputDecoration(
                  hintText: 'https://t.me/+...',
                  labelText: 'Link de convite',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final link = linkController.text.trim();
                if (link.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final api = ref.read(apiServiceProvider);
                  await api.linkTelegramGroup(widget.eventId, inviteLink: link);
                  _loadGroups();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Grupo vinculado!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Vincular'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openGroup(String inviteLink) async {
    final uri = Uri.parse(inviteLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _joinGroup,
            icon: _isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.telegram, size: 24),
            label: Text(
              _groups.isEmpty ? 'Abrir Chat no Telegram' : 'Entrar no Grupo Telegram',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0088CC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_groups.length > 1) ...[
          const SizedBox(height: 8),
          Text(
            '${_groups.length} grupos disponíveis',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          ..._groups.map((g) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: OutlinedButton.icon(
              onPressed: () => _openGroup(g['inviteLink'] as String),
              icon: const Icon(Icons.group, size: 18),
              label: Row(
                children: [
                  Expanded(child: Text(g['title'] as String? ?? 'Grupo')),
                  Text(
                    '${g['memberCount'] ?? 0} membros',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (g['isFull'] == true) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.warning, size: 14, color: Colors.orange),
                  ],
                ],
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          )),
        ],
      ],
    );
  }
}

/// Botão para vincular o evento a uma coalizão existente ou criar nova
class _JoinCoalitionButton extends StatefulWidget {
  final SocialEvent event;
  final VoidCallback onJoined;
  const _JoinCoalitionButton({required this.event, required this.onJoined});

  @override
  State<_JoinCoalitionButton> createState() => _JoinCoalitionButtonState();
}

class _JoinCoalitionButtonState extends State<_JoinCoalitionButton> {
  bool _loading = false;

  Future<void> _showCoalitionPicker() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiService().getCoalitions();
      final list = (resp['coalitions'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (!mounted) return;
      setState(() => _loading = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.groups, color: AppTheme.primaryColor, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reunir Protestos pela Mesma Causa',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Vincule este evento a uma coalizão para agregar forças com outros protestos pela mesma causa.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.groups, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Nenhuma coalizão disponível',
                                style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.push('/coalitions');
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Criar Coalizão'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                child: const Icon(Icons.groups, color: AppTheme.primaryColor),
                              ),
                              title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${c['totalEvents'] ?? 0} eventos · ${c['totalAttendees'] ?? 0} participantes',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                              onTap: () async {
                                Navigator.pop(ctx);
                                try {
                                  await ApiService().joinCoalition(c['id'], widget.event.id);
                                  widget.onJoined();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Evento vinculado à coalizão!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar coalizões: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _loading ? null : _showCoalitionPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          gradient: LinearGradient(
            colors: [Colors.amber.withValues(alpha: 0.05), Colors.orange.withValues(alpha: 0.03)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.groups, color: Colors.amber),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reunir Protestos pela Mesma Causa',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Vincule a uma coalizão para agregar forças',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline, color: Colors.amber),
          ],
        ),
      ),
    );
  }
}

/// Seção de funcionalidades premium no detalhe do evento
class _PremiumFeaturesSection extends ConsumerWidget {
  final SocialEvent event;
  const _PremiumFeaturesSection({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAnalytics = ref.watch(hasAnalyticsProvider);
    final hasExport = ref.watch(hasExportProvider);
    final hasGrafana = ref.watch(hasGrafanaProvider);
    final hasBlueCheck = ref.watch(hasBlueCheckProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Funcionalidades Premium',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Analytics
        _premiumTile(
          context,
          icon: Icons.analytics,
          title: 'Análise Avançada',
          subtitle: 'Evolução, heatmap e demografia',
          color: Colors.deepPurple,
          isUnlocked: hasAnalytics,
          price: 'R\$ 19,90/mês',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventAnalyticsScreen(event: event)),
          ),
        ),

        // Grafana Dashboard
        _premiumTile(
          context,
          icon: Icons.dashboard,
          title: 'Dashboard em Tempo Real',
          subtitle: 'Métricas ao vivo estilo Grafana',
          color: const Color(0xFFFF6600),
          isUnlocked: hasGrafana,
          price: 'R\$ 14,90/mês',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventGrafanaScreen(event: event)),
          ),
        ),

        // Export & Reports
        _premiumTile(
          context,
          icon: Icons.description,
          title: 'Exportação e Relatórios',
          subtitle: 'CSV, PDF, Excel e certificados',
          color: Colors.teal,
          isUnlocked: hasExport,
          price: 'R\$ 9,90/mês',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExportReportsScreen(event: event)),
          ),
        ),

        // Blue Check
        _premiumTile(
          context,
          icon: Icons.verified,
          title: 'Verificação Blue Check',
          subtitle: 'Selo de organizador verificado',
          color: Colors.blue,
          isUnlocked: hasBlueCheck,
          price: 'R\$ 29,90 único',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BlueCheckScreen()),
          ),
        ),
      ],
    );
  }

  Widget _premiumTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isUnlocked,
    required String price,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUnlocked ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.2)),
        color: isUnlocked ? color.withOpacity(0.05) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (isUnlocked) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
            ],
          ],
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: isUnlocked
            ? const Icon(Icons.chevron_right)
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(price, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
        onTap: onTap,
      ),
    );
  }
}
