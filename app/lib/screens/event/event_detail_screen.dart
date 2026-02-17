import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event.dart';
import '../../providers/app_providers.dart';
import '../../services/location_service.dart';
import '../../utils/theme.dart';
import '../../widgets/crowd_gauge.dart';
import '../../widgets/checkin_button.dart';

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

                // Botão Chat Telegram
                _TelegramChatButton(eventId: widget.eventId),
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
