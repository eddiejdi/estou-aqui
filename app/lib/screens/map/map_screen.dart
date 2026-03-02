import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../utils/web_utils.dart' as web;
import '../../models/event.dart';
import '../../providers/app_providers.dart';
import '../../services/location_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/event_card.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  bool _isLoadingLocation = true;
  String? _selectedCategory;
  bool _showEventList = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadEvents();
  }

  Future<void> _initLocation() async {
    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentPosition();

    if (position != null && mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      _mapController.move(_currentLocation, 13);
      _loadEvents();
    } else {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _loadEvents() async {
    web.webConsoleLog('📍 _loadEvents chamado - Lat: ${_currentLocation.latitude}, Lng: ${_currentLocation.longitude}');
    await ref.read(eventsProvider.notifier).loadEvents(
      lat: _currentLocation.latitude,
      lng: _currentLocation.longitude,
      category: _selectedCategory,
    );
  }

  Color _getEventColor(SocialEvent event) {
    switch (event.status) {
      case EventStatus.active:
        return AppTheme.secondaryColor;
      case EventStatus.scheduled:
        return AppTheme.primaryColor;
      case EventStatus.ended:
        return Colors.grey;
      case EventStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  double _getMarkerSize(SocialEvent event) {
    if (event.estimatedAttendees > 10000) return 60;
    if (event.estimatedAttendees > 1000) return 50;
    if (event.estimatedAttendees > 100) return 40;
    return 35;
  }

  @override
  Widget build(BuildContext context) {
    final eventsState = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estou Aqui'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
          IconButton(
            icon: Icon(_showEventList ? Icons.map : Icons.list),
            onPressed: () => setState(() => _showEventList = !_showEventList),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: AppConstants.defaultZoom,
              onTap: (_, __) {},
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.estouaqui.app',
              ),
              // Marcadores dos eventos e localização do usuário
              eventsState.when(
                data: (events) => MarkerLayer(
                  markers: [
                    // Localização do usuário (ponto central com pulsação visual)
                    Marker(
                      point: _currentLocation,
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Círculo de sombra/halo (simula área de precisão)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                          ),
                          // Ponto principal do usuário
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Eventos com marcadores circulares ao fundo (simula área)
                    ...events.map((event) {
                      // Marcador de área (fundo)
                      return Marker(
                        point: LatLng(event.latitude, event.longitude),
                        width: _getMarkerSize(event) * 3,
                        height: _getMarkerSize(event) * 3,
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getEventColor(event).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getEventColor(event).withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    // Eventos - marcadores principales
                    ...events.map((event) => Marker(
                      point: LatLng(event.latitude, event.longitude),
                      width: _getMarkerSize(event),
                      height: _getMarkerSize(event) + 12,
                      child: GestureDetector(
                        onTap: () => context.push('/event/${event.id}'),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getEventColor(event),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${event.category.emoji} ${event.confirmedAttendees}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Icon(
                              Icons.location_on,
                              color: _getEventColor(event),
                              size: _getMarkerSize(event) - 12,
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
              ),
            ],
          ),

          // Lista de eventos (sobreposição)
          if (_showEventList)
            DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.15,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Eventos Próximos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: eventsState.when(
                          data: (events) => events.isEmpty
                              ? const Center(child: Text('Nenhum evento encontrado'))
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: events.length,
                                  itemBuilder: (context, index) => EventCard(
                                    event: events[index],
                                    onTap: () => context.push('/event/${events[index].id}'),
                                  ),
                                ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (error, _) => Center(child: Text('Erro: $error')),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Loading location
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),

          // Botão centralizar
          Positioned(
            bottom: _showEventList ? 320 : 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'center',
              onPressed: () {
                _mapController.move(_currentLocation, 14);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtrar por categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = null);
                    _loadEvents();
                    Navigator.pop(context);
                  },
                ),
                ...EventCategory.values.map((cat) => FilterChip(
                  label: Text('${cat.emoji} ${cat.label}'),
                  selected: _selectedCategory == cat.name,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? cat.name : null);
                    _loadEvents();
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
