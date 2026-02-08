import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../utils/theme.dart';

class EventCard extends StatelessWidget {
  final SocialEvent event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: categoria + status
              Row(
                children: [
                  Text(event.category.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusBadge(event.status),
                ],
              ),
              const SizedBox(height: 8),

              // Descrição
              Text(
                event.description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Info row
              Row(
                children: [
                  // Data
                  Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(dateFormat.format(event.startDate), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const Spacer(),
                  // Check-ins
                  Icon(Icons.people, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${event.confirmedAttendees} confirmados',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  // Local
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.locationDisplay,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Estimativa
                  if (event.estimatedAttendees > 0) ...[
                    const Icon(Icons.trending_up, size: 14, color: AppTheme.accentColor),
                    const SizedBox(width: 4),
                    Text(
                      '~${_formatCount(event.estimatedAttendees)} estimados',
                      style: const TextStyle(fontSize: 12, color: AppTheme.accentColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(EventStatus status) {
    Color color;
    String label;

    switch (status) {
      case EventStatus.active:
        color = AppTheme.secondaryColor;
        label = 'AO VIVO';
        break;
      case EventStatus.scheduled:
        color = AppTheme.primaryColor;
        label = 'AGENDADO';
        break;
      case EventStatus.ended:
        color = Colors.grey;
        label = 'ENCERRADO';
        break;
      case EventStatus.cancelled:
        color = AppTheme.errorColor;
        label = 'CANCELADO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
