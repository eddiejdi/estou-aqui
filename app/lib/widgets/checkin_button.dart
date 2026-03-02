import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../providers/app_providers.dart';
import '../services/checkin_retry_service.dart';
import '../services/location_service.dart';
import '../utils/theme.dart';

class CheckinButton extends ConsumerStatefulWidget {
  final String eventId;
  final SocialEvent event;

  const CheckinButton({super.key, required this.eventId, required this.event});

  @override
  ConsumerState<CheckinButton> createState() => _CheckinButtonState();
}

class _CheckinButtonState extends ConsumerState<CheckinButton>
    with SingleTickerProviderStateMixin {
  bool _isCheckedIn = false;
  bool _isLoading = false;
  bool _isPendingOffline = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final CheckinRetryService _retryService = CheckinRetryService();
  StreamSubscription<CheckinRetryStatus>? _retrySubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Escutar status de retry offline
    _retrySubscription = _retryService.statusStream.listen((status) {
      if (!mounted) return;
      if (status.lastEvent == widget.eventId) {
        if (status.isSuccess) {
          setState(() {
            _isCheckedIn = true;
            _isPendingOffline = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Check-in enviado com sucesso!'),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
          ref.read(selectedEventProvider.notifier).loadEvent(widget.eventId);
        } else if (status.isFailed) {
          setState(() => _isPendingOffline = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });

    // Verificar se já tem check-in pendente para este evento
    _checkPendingStatus();
  }

  Future<void> _checkPendingStatus() async {
    final pending = await _retryService.getPendingCheckins();
    if (mounted && pending.any((p) => p.eventId == widget.eventId)) {
      setState(() => _isPendingOffline = true);
    }
  }

  @override
  void dispose() {
    _retrySubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleCheckin() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final location = ref.read(locationServiceProvider);

      if (_isCheckedIn || _isPendingOffline) {
        if (_isPendingOffline) {
          // Cancelar retry pendente
          await _retryService.removePending(widget.eventId);
          setState(() {
            _isPendingOffline = false;
            _isCheckedIn = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Check-in pendente cancelado'), backgroundColor: Colors.grey),
            );
          }
        } else {
          // Check-out normal
          await api.checkout(widget.eventId);
          setState(() => _isCheckedIn = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Check-out realizado! 👋'), backgroundColor: Colors.grey),
            );
          }
        }
      } else {
        // Check-in
        final pos = await location.getCurrentPosition();
        if (pos == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Não foi possível obter localização'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        try {
          await api.checkin(widget.eventId, pos.latitude, pos.longitude);
          setState(() => _isCheckedIn = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('📍 Estou Aqui! Check-in realizado!'), backgroundColor: AppTheme.secondaryColor),
            );
          }
        } catch (e) {
          // Falhou — salvar para retry offline em background
          await _retryService.addPendingCheckin(
            eventId: widget.eventId,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
          setState(() => _isPendingOffline = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📍 Sem conexão — check-in será enviado automaticamente quando houver internet'),
                backgroundColor: AppTheme.warningColor,
                duration: Duration(seconds: 4),
              ),
            );
          }
          // Não propagar o erro — já foi tratado
          return;
        }
      }

      // Recarregar evento
      ref.read(selectedEventProvider.notifier).loadEvent(widget.eventId);
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicador de retry pendente
        if (_isPendingOffline)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Check-in pendente — aguardando conexão...',
                    style: TextStyle(fontSize: 12, color: AppTheme.warningColor, fontWeight: FontWeight.w500),
                  ),
                ),
                GestureDetector(
                  onTap: () => _retryService.forceRetry(),
                  child: const Icon(Icons.refresh, size: 18, color: AppTheme.warningColor),
                ),
              ],
            ),
          ),

        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: (_isCheckedIn || _isPendingOffline) ? 1.0 : _pulseAnimation.value,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _toggleCheckin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPendingOffline
                        ? AppTheme.warningColor
                        : _isCheckedIn
                            ? AppTheme.errorColor
                            : AppTheme.secondaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: (_isCheckedIn || _isPendingOffline) ? 2 : 6,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _isPendingOffline
                              ? Icons.cloud_off
                              : _isCheckedIn
                                  ? Icons.logout
                                  : Icons.location_on,
                          size: 28,
                        ),
                  label: Text(
                    _isPendingOffline
                        ? 'Cancelar Check-in Pendente'
                        : _isCheckedIn
                            ? 'Fazer Check-out'
                            : '📍 Estou Aqui!',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
