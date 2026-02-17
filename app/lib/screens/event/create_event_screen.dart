import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../providers/app_providers.dart';
import '../../services/location_service.dart';
import '../../services/geocode_service.dart';
import '../../utils/theme.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _cepController = TextEditingController();
  final _areaController = TextEditingController();
  final _endAddressController = TextEditingController();
  final _endCepController = TextEditingController();

  EventCategory _category = EventCategory.manifestacao;
  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  DateTime? _endDate;
  double? _latitude;
  double? _longitude;
  double? _endLatitude;
  double? _endLongitude;
  bool _isLoading = false;
  bool _useCurrentLocation = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _cepController.addListener(_onCepChanged);
    _endCepController.addListener(_onEndCepChanged);
  }

  Future<void> _getCurrentLocation() async {
    if (!_useCurrentLocation) return;
    final location = ref.read(locationServiceProvider);
    final pos = await location.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
      // Reverse geocode to fill address/city
      try {
        final geocode = ref.read(geocodeServiceProvider);
        final res = await geocode.reverseGeocode(pos.latitude, pos.longitude);
        if (res != null && mounted) {
          final display = res['displayName'] as String?;
          final city = res['city'] as String?;
          if (display != null && display.isNotEmpty) {
            _addressController.text = display;
          }
          if (city != null && city.isNotEmpty) {
            _cityController.text = city;
          }
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _cepController.removeListener(_onCepChanged);
    _cepController.dispose();
    _areaController.dispose();
    _endAddressController.dispose();
    _endCepController.removeListener(_onEndCepChanged);
    _endCepController.dispose();
    super.dispose();
  }

  void _onCepChanged() {
    final text = _cepController.text;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) {
      _lookupCep(digits);
    }
  }

  Future<void> _lookupCep(String cep) async {
    try {
      final geocode = ref.read(geocodeServiceProvider);
      final res = await geocode.lookupCep(cep);
      if (res != null && mounted) {
        final String address = (res['address'] ?? '') as String;
        final String city = (res['city'] ?? '') as String;
        if (address.isNotEmpty) _addressController.text = address;
        if (city.isNotEmpty) _cityController.text = city;
      }
    } catch (_) {}
  }

  void _onEndCepChanged() {
    final text = _endCepController.text;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) {
      _lookupEndCep(digits);
    }
  }

  Future<void> _lookupEndCep(String cep) async {
    try {
      final geocode = ref.read(geocodeServiceProvider);
      final res = await geocode.lookupCep(cep);
      if (res != null && mounted) {
        final String address = (res['address'] ?? '') as String;
        if (address.isNotEmpty) _endAddressController.text = address;
        // Tentar geocodificar para obter lat/lng
        final coords = await geocode.geocodeAddress(address);
        if (coords != null && mounted) {
          setState(() {
            _endLatitude = coords['latitude'] as double?;
            _endLongitude = coords['longitude'] as double?;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _geocodeEndAddress() async {
    final address = _endAddressController.text.trim();
    if (address.isEmpty) return;
    try {
      final geocode = ref.read(geocodeServiceProvider);
      final coords = await geocode.geocodeAddress(address);
      if (coords != null && mounted) {
        setState(() {
          _endLatitude = coords['latitude'] as double?;
          _endLongitude = coords['longitude'] as double?;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local de chegada encontrado!'), backgroundColor: Colors.green),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Endereço não encontrado'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao buscar endereço'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : (_endDate ?? _startDate)),
    );
    if (time == null || !mounted) return;

    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startDate = dateTime;
      } else {
        _endDate = dateTime;
      }
    });
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Localização não disponível'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category.name,
        'latitude': _latitude,
        'longitude': _longitude,
        'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        'city': _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        'startDate': _startDate.toIso8601String(),
        if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
        if (_areaController.text.isNotEmpty) 'areaSquareMeters': double.tryParse(_areaController.text),
        if (_endLatitude != null) 'endLatitude': _endLatitude,
        if (_endLongitude != null) 'endLongitude': _endLongitude,
        if (_endAddressController.text.trim().isNotEmpty) 'endAddress': _endAddressController.text.trim(),
      };

      final result = await api.createEvent(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento criado com sucesso!'), backgroundColor: AppTheme.secondaryColor),
        );
        // Atualiza a lista de eventos no mapa antes de fechar
        try {
          await ref.read(eventsProvider.notifier).refresh(lat: _latitude, lng: _longitude);
        } catch (_) {}
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Criar Evento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título do evento',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().length < 3) ? 'Mínimo 3 caracteres' : null,
              ),
              const SizedBox(height: 16),

              // Descrição
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().length < 10) ? 'Mínimo 10 caracteres' : null,
              ),
              const SizedBox(height: 16),

              // Categoria
              DropdownButtonFormField<EventCategory>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category),
                ),
                items: EventCategory.values.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text('${cat.emoji} ${cat.label}'),
                )).toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 16),

              // Endereço
              // CEP (opcional) — preenche endereço automaticamente
              TextFormField(
                controller: _cepController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CEP (opcional)',
                  prefixIcon: Icon(Icons.local_post_office),
                  helperText: 'Digite o CEP para preencher endereço automaticamente',
                ),
              ),
              const SizedBox(height: 12),
              // Endereço
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Endereço (opcional)',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),

              // Cidade
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Cidade (opcional)',
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 16),

              // ── Local de chegada (passeatas/marchas) ──
              if (_category == EventCategory.marcha ||
                  _category == EventCategory.manifestacao ||
                  _category == EventCategory.protesto) ...[
                const Divider(height: 32),
                Row(
                  children: [
                    const Icon(Icons.flag, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Local de Chegada (passeata)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_endLatitude != null)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Preencha se o evento tem percurso (ex: passeata, marcha)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _endCepController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CEP do local de chegada (opcional)',
                    prefixIcon: Icon(Icons.local_post_office),
                    helperText: 'Digite o CEP para preencher automaticamente',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _endAddressController,
                  decoration: InputDecoration(
                    labelText: 'Endereço de chegada',
                    prefixIcon: const Icon(Icons.flag),
                    suffixIcon: _endAddressController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _geocodeEndAddress,
                          )
                        : null,
                  ),
                ),
                if (_endLatitude != null && _endLongitude != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📍 ${_endLatitude!.toStringAsFixed(4)}, ${_endLongitude!.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
                const Divider(height: 32),
              ],

              // Localização
              SwitchListTile(
                title: const Text('Usar minha localização atual'),
                subtitle: _latitude != null
                    ? Text('${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}')
                    : const Text('Obtendo localização...'),
                value: _useCurrentLocation,
                onChanged: (v) {
                  setState(() => _useCurrentLocation = v);
                  if (v) _getCurrentLocation();
                },
              ),
              const SizedBox(height: 16),

              // Data início
              ListTile(
                leading: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                title: const Text('Data e hora de início'),
                subtitle: Text(dateFormat.format(_startDate)),
                trailing: const Icon(Icons.edit),
                onTap: () => _selectDate(true),
              ),

              // Data fim
              ListTile(
                leading: const Icon(Icons.event, color: AppTheme.primaryColor),
                title: const Text('Data e hora de término'),
                subtitle: Text(_endDate != null ? dateFormat.format(_endDate!) : 'Não definido'),
                trailing: const Icon(Icons.edit),
                onTap: () => _selectDate(false),
              ),
              const SizedBox(height: 16),

              // Área (para estimativa)
              TextFormField(
                controller: _areaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Área estimada (m²) — opcional',
                  prefixIcon: Icon(Icons.square_foot),
                  helperText: 'Ajuda a calcular a estimativa de público',
                ),
              ),
              const SizedBox(height: 32),

              // Botão criar
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _createEvent,
                icon: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_circle),
                label: const Text('Criar Evento'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
