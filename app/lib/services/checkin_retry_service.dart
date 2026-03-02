import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Serviço de retry offline para check-ins.
///
/// Quando o usuário faz check-in sem internet, o check-in é salvo
/// localmente e retentado automaticamente em background até conseguir.
class CheckinRetryService {
  static final CheckinRetryService _instance = CheckinRetryService._internal();
  factory CheckinRetryService() => _instance;
  CheckinRetryService._internal();

  static const String _pendingKey = 'pending_checkins';
  static const Duration _retryInterval = Duration(seconds: 30);
  static const int _maxRetries = 100; // ~50 min de tentativas

  Timer? _retryTimer;
  bool _isRetrying = false;
  final ApiService _api = ApiService();

  /// Stream controller para notificar mudanças de status
  final _statusController = StreamController<CheckinRetryStatus>.broadcast();
  Stream<CheckinRetryStatus> get statusStream => _statusController.stream;

  /// Lista de callbacks para notificar sucesso de retry
  final List<void Function(PendingCheckin)> _onSuccessCallbacks = [];

  void onRetrySuccess(void Function(PendingCheckin) callback) {
    _onSuccessCallbacks.add(callback);
  }

  void removeOnRetrySuccess(void Function(PendingCheckin) callback) {
    _onSuccessCallbacks.remove(callback);
  }

  /// Adiciona um check-in pendente para retry
  Future<void> addPendingCheckin({
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

    final prefs = await SharedPreferences.getInstance();
    final list = _loadPendingList(prefs);
    
    // Evitar duplicatas para o mesmo evento
    list.removeWhere((p) => p.eventId == eventId);
    list.add(pending);
    
    await _savePendingList(prefs, list);

    debugPrint('📍 [CheckinRetry] Check-in pendente salvo para evento $eventId');
    _statusController.add(CheckinRetryStatus(
      pendingCount: list.length,
      lastEvent: eventId,
      message: 'Check-in salvo offline. Tentando enviar...',
    ));

    // Iniciar timer de retry se não estiver rodando
    _startRetryTimer();
  }

  /// Inicia o timer de retry em background
  void _startRetryTimer() {
    if (_retryTimer?.isActive == true) return;

    _retryTimer = Timer.periodic(_retryInterval, (_) {
      _processRetries();
    });

    // Tentar imediatamente na primeira vez
    _processRetries();
  }

  /// Processa todos os check-ins pendentes
  Future<void> _processRetries() async {
    if (_isRetrying) return;
    _isRetrying = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _loadPendingList(prefs);

      if (list.isEmpty) {
        _stopRetryTimer();
        _isRetrying = false;
        return;
      }

      debugPrint('📍 [CheckinRetry] Processando ${list.length} check-in(s) pendente(s)...');

      final toRemove = <String>[];
      final updated = <PendingCheckin>[];

      for (final pending in list) {
        try {
          await _api.checkin(pending.eventId, pending.latitude, pending.longitude);

          debugPrint('✅ [CheckinRetry] Check-in enviado com sucesso para evento ${pending.eventId}');
          toRemove.add(pending.eventId);

          // Notificar sucesso
          _statusController.add(CheckinRetryStatus(
            pendingCount: list.length - toRemove.length,
            lastEvent: pending.eventId,
            message: '✅ Check-in enviado com sucesso!',
            isSuccess: true,
          ));

          // Notificar callbacks
          for (final cb in _onSuccessCallbacks) {
            cb(pending);
          }
        } catch (e) {
          final newRetryCount = pending.retryCount + 1;
          
          if (newRetryCount >= _maxRetries) {
            debugPrint('❌ [CheckinRetry] Máximo de tentativas atingido para evento ${pending.eventId}');
            toRemove.add(pending.eventId);
            _statusController.add(CheckinRetryStatus(
              pendingCount: list.length - toRemove.length,
              lastEvent: pending.eventId,
              message: '❌ Check-in falhou após $newRetryCount tentativas',
              isFailed: true,
            ));
          } else {
            debugPrint('⏳ [CheckinRetry] Tentativa $newRetryCount falhou para evento ${pending.eventId}: $e');
            updated.add(pending.copyWith(retryCount: newRetryCount));
            _statusController.add(CheckinRetryStatus(
              pendingCount: list.length - toRemove.length,
              lastEvent: pending.eventId,
              message: 'Tentativa $newRetryCount — sem conexão. Retentando em ${_retryInterval.inSeconds}s...',
            ));
          }
        }
      }

      // Atualizar lista: remover os que foram enviados ou falharam definitivamente
      final remaining = updated.where((p) => !toRemove.contains(p.eventId)).toList();
      await _savePendingList(prefs, remaining);

      if (remaining.isEmpty) {
        _stopRetryTimer();
      }
    } catch (e) {
      debugPrint('❌ [CheckinRetry] Erro ao processar retries: $e');
    } finally {
      _isRetrying = false;
    }
  }

  /// Para o timer de retry
  void _stopRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    debugPrint('📍 [CheckinRetry] Timer de retry parado — nenhum check-in pendente');
  }

  /// Retorna a lista de check-ins pendentes
  Future<List<PendingCheckin>> getPendingCheckins() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadPendingList(prefs);
  }

  /// Retorna se há check-ins pendentes
  Future<bool> hasPending() async {
    final list = await getPendingCheckins();
    return list.isNotEmpty;
  }

  /// Remove um check-in pendente manualmente (ex: usuário cancelou)
  Future<void> removePending(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _loadPendingList(prefs);
    list.removeWhere((p) => p.eventId == eventId);
    await _savePendingList(prefs, list);

    if (list.isEmpty) {
      _stopRetryTimer();
    }
  }

  /// Força retry imediato
  Future<void> forceRetry() async {
    await _processRetries();
  }

  /// Inicializa o serviço — chamar no startup do app
  Future<void> init() async {
    final pending = await getPendingCheckins();
    if (pending.isNotEmpty) {
      debugPrint('📍 [CheckinRetry] ${pending.length} check-in(s) pendente(s) encontrado(s) ao iniciar');
      _startRetryTimer();
    }
  }

  /// Libera recursos
  void dispose() {
    _stopRetryTimer();
    _statusController.close();
  }

  // ─── Persistência local ────────────────────────────────

  List<PendingCheckin> _loadPendingList(SharedPreferences prefs) {
    final json = prefs.getString(_pendingKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => PendingCheckin.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('❌ [CheckinRetry] Erro ao decodificar pendentes: $e');
      return [];
    }
  }

  Future<void> _savePendingList(SharedPreferences prefs, List<PendingCheckin> list) async {
    final json = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_pendingKey, json);
  }
}

// ─── Modelos ─────────────────────────────────────────────

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
    required this.retryCount,
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
}

class CheckinRetryStatus {
  final int pendingCount;
  final String lastEvent;
  final String message;
  final bool isSuccess;
  final bool isFailed;

  const CheckinRetryStatus({
    required this.pendingCount,
    required this.lastEvent,
    required this.message,
    this.isSuccess = false,
    this.isFailed = false,
  });
}
