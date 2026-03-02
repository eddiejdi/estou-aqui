import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/event.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../widgets/ad_banner_widget.dart';


class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  List<SocialEvent> _events = [];
  bool _isLoading = true;
  String? _error;
  Position? _userPosition;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Tentar obter posição do usuário (não bloqueia se falhar)
      try {
        _userPosition = await LocationService().getCurrentPosition();
      } catch (_) {
        _userPosition = null; // Continua sem localização
      }

      // Buscar eventos da API
      final params = <String, dynamic>{};
      if (_statusFilter != 'all') {
        params['status'] = _statusFilter;
      }
      if (_userPosition != null) {
        params['lat'] = _userPosition!.latitude;
        params['lng'] = _userPosition!.longitude;
      }

      final response = await ApiService().getEvents(
        lat: _userPosition?.latitude,
        lng: _userPosition?.longitude,
        status: _statusFilter != 'all' ? _statusFilter : null,
        limit: 50,
      );

      final eventsList = response['events'] as List? ?? [];
      _events = eventsList
          .map((e) => SocialEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      // Ordenar por proximidade se temos posição do usuário
      if (_userPosition != null) {
        _events.sort((a, b) {
          final distA = _haversineDistance(
            _userPosition!.latitude, _userPosition!.longitude,
            a.latitude, a.longitude,
          );
          final distB = _haversineDistance(
            _userPosition!.latitude, _userPosition!.longitude,
            b.latitude, b.longitude,
          );
          return distA.compareTo(distB);
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erro ao carregar eventos: $e';
      });
    }
  }

  /// Calcula distância entre dois pontos usando fórmula de Haversine (km)
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${km.round()} km';
    }
  }

  Color _distanceColor(double km) {
    if (km < 1) return Colors.green;
    if (km < 5) return Colors.lightGreen;
    if (km < 20) return Colors.orange;
    if (km < 50) return Colors.deepOrange;
    return Colors.red;
  }

  Color _statusColor(EventStatus status) {
    switch (status) {
      case EventStatus.active:
        return Colors.green;
      case EventStatus.scheduled:
        return Colors.blue;
      case EventStatus.ended:
        return Colors.grey;
      case EventStatus.cancelled:
        return Colors.red;
    }
  }

  String _statusLabel(EventStatus status) {
    switch (status) {
      case EventStatus.active:
        return 'ATIVO';
      case EventStatus.scheduled:
        return 'AGENDADO';
      case EventStatus.ended:
        return 'ENCERRADO';
      case EventStatus.cancelled:
        return 'CANCELADO';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar',
            onSelected: (value) {
              setState(() => _statusFilter = value);
              _loadEvents();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('Todos')),
              const PopupMenuItem(value: 'active', child: Text('Ativos')),
              const PopupMenuItem(value: 'scheduled', child: Text('Agendados')),
              const PopupMenuItem(value: 'ended', child: Text('Encerrados')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando eventos...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum evento encontrado',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Puxe para baixo para atualizar',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const AdBannerWidget(isTop: true),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _events.length,
            itemBuilder: (context, index) => _buildEventCard(_events[index]),
          ),
        ),
        const AdBannerWidget(),
      ],
    );
  }

  Widget _buildEventCard(SocialEvent event) {
    double? distance;
    if (_userPosition != null) {
      distance = _haversineDistance(
        _userPosition!.latitude, _userPosition!.longitude,
        event.latitude, event.longitude,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/event/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: categoria + status + distância
              Row(
                children: [
                  // Emoji da categoria
                  Text(event.category.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  // Título
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Badge de distância
                  if (distance != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _distanceColor(distance).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _distanceColor(distance).withOpacity(0.5)),
                      ),
                      child: Text(
                        _formatDistance(distance),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _distanceColor(distance),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Descrição
              if (event.description.isNotEmpty)
                Text(
                  event.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              const SizedBox(height: 8),
              // Info row: localização, categoria, status
              Row(
                children: [
                  // Localização
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.locationDisplay,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Participantes
                  Icon(Icons.people, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${event.confirmedAttendees}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 12),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(event.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(event.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(event.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Data
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(event.startDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    event.category.label,
                    style: TextStyle(fontSize: 12, color: Colors.blue[300]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.isNegative) {
      if (diff.inDays.abs() == 0) return 'Hoje';
      if (diff.inDays.abs() == 1) return 'Ontem';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } else {
      if (diff.inDays == 0) return 'Hoje';
      if (diff.inDays == 1) return 'Amanhã';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }
}
