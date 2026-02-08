import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../providers/app_providers.dart';
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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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

        await api.checkin(widget.eventId, pos.latitude, pos.longitude);
        setState(() => _isCheckedIn = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📍 Estou Aqui! Check-in realizado!'), backgroundColor: AppTheme.secondaryColor),
          );
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
    return AnimatedBuilder(
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
                backgroundColor: _isCheckedIn ? AppTheme.errorColor : AppTheme.secondaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: _isCheckedIn ? 2 : 6,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_isCheckedIn ? Icons.logout : Icons.location_on, size: 28),
              label: Text(
                _isCheckedIn ? 'Fazer Check-out' : '📍 Estou Aqui!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }
}
