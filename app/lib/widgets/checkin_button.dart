import 'dart:async';
import 'package:dio/dio.dart';
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
  bool _isPendingRetry = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final CheckinRetryService _retryService = CheckinRetryService();
  StreamSubscription<List<PendingCheckin>>? _pendingSub;

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
    _checkPendingStatus();
    _listenPendingChanges();
  }

  Future<void> _checkPendingStatus() async {
    final hasPending = await _retryService.hasPending(widget.eventId);
    if (mounted && hasPending != _isPendingRetry) {
      setState(() => _isPendingRetry = hasPending);
    }
  }

  void _listenPendingChanges() {
    _pendingSub = _retryService.pendingStream.listen((pending) {
      if (!mounted) return;
      final hasPending = pending.any((p) => p.eventId == widget.eventId);
      if (hasPending != _isPendingRetry) {
        setState(() => _isPendingRetry = hasPending);
      }
      // Se saiu da fila pendente com sucesso, atualizar estado
      if (!hasPending && _isPendingRetry) {
        setState(() {
          _isCheckedIn = true;
          _isPendingRetry = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Check-in pendente realizado com sucesso!'),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
        }
        ref.read(selectedEventProvider.notifier).loadEvent(widget.eventId);
      }
    });
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Verifica se o erro é de conectividade (sem internet)
  bool _isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.unknown;
    }
    return false;
  }

  Future<void> _toggleCheckin() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final location = ref.read(locationServiceProvider);

      if (_isCheckedIn) {
        // Check-out
        await api.checkout(widget.eventId);
        setState(() => _isCheckedIn = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Check-out realizado! 👋'), backgroundColor: Colors.grey),
          );
        }
      } else if (_isPendingRetry) {
        // Já tem retry pendente — tentar forçar agora
        _retryService.retryAllNow();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏳ Tentando enviar check-in novamente...'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
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
              const SnackBar(
                content: Text('📍 Estou Aqui! Check-in realizado!'),
                backgroundColor: AppTheme.secondaryColor,
              ),
            );
          }
        } catch (e) {
          if (_isNetworkError(e)) {
            // Sem internet — enfileirar para retry em background
            await _retryService.enqueue(
              eventId: widget.eventId,
              latitude: pos.latitude,
              longitude: pos.longitude,
            );
            setState(() => _isPendingRetry = true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Sem internet. Check-in será enviado automaticamente quando a conexão voltar.'),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.warningColor,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          } else {
            // Erro não relacionado a rede — mostrar normalmente
            rethrow;
          }
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
        // Banner de checkin pendente
        if (_isPendingRetry)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warningColor),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Check-in pendente — aguardando conexão...',
                    style: TextStyle(fontSize: 12, color: AppTheme.warningColor, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.wifi_off, size: 16, color: AppTheme.warningColor),
              ],
            ),
          ),

        // Botão principal
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isCheckedIn ? 1.0 : _pulseAnimation.value,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _toggleCheckin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPendingRetry
                        ? AppTheme.warningColor
                        : (_isCheckedIn ? AppTheme.errorColor : AppTheme.secondaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: _isCheckedIn ? 2 : 6,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _isPendingRetry
                              ? Icons.sync
                              : (_isCheckedIn ? Icons.logout : Icons.location_on),
                          size: 28,
                        ),
                  label: Text(
                    _isPendingRetry
                        ? '⏳ Reenviando...'
                        : (_isCheckedIn ? 'Fazer Check-out' : '📍 Estou Aqui!'),
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
