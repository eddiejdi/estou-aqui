import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Serviço de retry para check-ins offline.
///
/// Quando o check-in falha por falta de internet, o pedido é persistido
/// localmente (SharedPreferences) e retentado em background com backoff
/// exponencial até ter sucesso.
class CheckinRetryService {
  static final CheckinRetryService _instance = CheckinRetryService._internal();
  factory CheckinRetryService() => _instance;
  CheckinRetryService._internal();

  static const _storageKey = 'pending_checkins';
  static const _maxRetries = 50; // ~2h30 de tentativas com backoff
  static const _baseDelay = Duration(seconds: 5);
  static const _maxDelay = Duration(minutes: 3);

  final ApiService _api = ApiService();
  final Map<String, Timer> _activeTimers = {};
  final _pendingController = StreamController<List<PendingCheckin>>.broadcast();

  /// Stream para ouvir mudanças nos checkins pendentes
  Stream<List<PendingCheckin>> get pendingStream => _pendingController.stream;

  bool _initialized = false;

  /// Inicializa o serviço e retoma retentativas de checkins pendentes da sessão anterior
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final pending = await _loadPending();
    if (pending.isNotEmpty) {
      debugPrint('📍 CheckinRetryService: ${pending.length} checkin(s) pendente(s) encontrado(s)');
      for (final checkin in pending) {
        _scheduleRetry(checkin);
      }
    }
  }

  /// Enfileira um check-in para retry em background
  Future<void> enqueue({
    required String eventId,
    required double latitude,
    required double longitude,
  }) async {
    final pending = PendingCheckin(
      eventId: eventId,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
      retryCount: 0,
    );

    await _savePending(pending);
    _notifyListeners();
    _scheduleRetry(pending);

    debugPrint('📍 CheckinRetryService: check-in para evento $eventId enfileirado');
  }

  /// Remove um checkin pendente (quando desistir ou cancelar)
  Future<void> cancel(String eventId) async {
    _activeTimers[eventId]?.cancel();
    _activeTimers.remove(eventId);
    await _removePending(eventId);
    _notifyListeners();
    debugPrint('📍 CheckinRetryService: check-in para evento $eventId cancelado');
  }

  /// Retorna a lista atual de checkins pendentes
  Future<List<PendingCheckin>> getPending() => _loadPending();

  /// Verifica se um evento tem checkin pendente
  Future<bool> hasPending(String eventId) async {
    final pending = await _loadPending();
    return pending.any((p) => p.eventId == eventId);
  }

  /// Tenta enviar todos os pendentes imediatamente (ex: quando internet voltar)
  Future<void> retryAllNow() async {
    final pending = await _loadPending();
    for (final checkin in pending) {
      _activeTimers[checkin.eventId]?.cancel();
      _attemptCheckin(checkin);
    }
  }

  // ─── Lógica interna ───────────────────────────────────

  void _scheduleRetry(PendingCheckin checkin) {
    // Calcula delay com backoff exponencial + jitter
    final backoffMs = (_baseDelay.inMilliseconds * (1 << checkin.retryCount.clamp(0, 10)))
        .clamp(0, _maxDelay.inMilliseconds);
    // Adiciona jitter de ±20%
    final jitter = (backoffMs * 0.2 * (DateTime.now().millisecond / 1000 - 0.5)).round();
    final delay = Duration(milliseconds: backoffMs + jitter);

    debugPrint('📍 Retry #${checkin.retryCount + 1} para evento ${checkin.eventId} em ${delay.inSeconds}s');

    _activeTimers[checkin.eventId]?.cancel();
    _activeTimers[checkin.eventId] = Timer(delay, () => _attemptCheckin(checkin));
  }

  Future<void> _attemptCheckin(PendingCheckin checkin) async {
    try {
      await _api.checkin(checkin.eventId, checkin.latitude, checkin.longitude);

      // Sucesso!
      debugPrint('✅ CheckinRetryService: check-in para evento ${checkin.eventId} realizado com sucesso!');
      await _removePending(checkin.eventId);
      _activeTimers.remove(checkin.eventId);
      _notifyListeners();
    } catch (e) {
      debugPrint('❌ CheckinRetryService: falha no retry #${checkin.retryCount + 1} para ${checkin.eventId}: $e');

      if (checkin.retryCount + 1 >= _maxRetries) {
        debugPrint('⚠️ CheckinRetryService: máximo de retentativas atingido para ${checkin.eventId}');
        await _removePending(checkin.eventId);
        _activeTimers.remove(checkin.eventId);
        _notifyListeners();
        return;
      }

      // Incrementa retry count e reagenda
      final updated = checkin.copyWith(retryCount: checkin.retryCount + 1);
      await _updatePending(updated);
      _scheduleRetry(updated);
    }
  }

  // ─── Persistência (SharedPreferences) ─────────────────

  Future<List<PendingCheckin>> _loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    return raw.map((json) => PendingCheckin.fromJson(jsonDecode(json))).toList();
  }

  Future<void> _savePending(PendingCheckin checkin) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    // Remove duplicata se existir
    raw.removeWhere((json) {
      final existing = PendingCheckin.fromJson(jsonDecode(json));
      return existing.eventId == checkin.eventId;
    });
    raw.add(jsonEncode(checkin.toJson()));
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> _updatePending(PendingCheckin checkin) async {
    await _savePending(checkin); // savePending já trata duplicatas
  }

  Future<void> _removePending(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    raw.removeWhere((json) {
      final existing = PendingCheckin.fromJson(jsonDecode(json));
      return existing.eventId == eventId;
    });
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> _notifyListeners() async {
    final pending = await _loadPending();
    _pendingController.add(pending);
  }

  void dispose() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _pendingController.close();
  }
}

// ─── Modelo de checkin pendente ──────────────────────────
class PendingCheckin {
  final String eventId;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final int retryCount;

  const PendingCheckin({
    required this.eventId,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.retryCount = 0,
  });

  PendingCheckin copyWith({int? retryCount}) {
    return PendingCheckin(
      eventId: eventId,
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory PendingCheckin.fromJson(Map<String, dynamic> json) {
    return PendingCheckin(
      eventId: json['eventId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'PendingCheckin(event=$eventId, retry=$retryCount, created=$createdAt)';
}
