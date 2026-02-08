import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../providers/app_providers.dart';
import '../../services/location_service.dart';
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
  final _areaController = TextEditingController();

  EventCategory _category = EventCategory.manifestacao;
  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  DateTime? _endDate;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _useCurrentLocation = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    super.dispose();
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
      };

      final result = await api.createEvent(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento criado com sucesso!'), backgroundColor: AppTheme.secondaryColor),
        );
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
