import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

                // Botão Chat
                OutlinedButton.icon(
                  onPressed: () => context.push('/chat/${widget.eventId}'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat do Evento'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
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
}
