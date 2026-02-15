import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          if (kIsWeb) {
            html.window.console.log('🔐 Token adicionado ao header: Bearer ${token.substring(0, 20)}...');
          }
        } else {
          if (kIsWeb) {
            html.window.console.warn('⚠️ Nenhum token disponível para a requisição');
          }
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          if (kIsWeb) {
            html.window.console.error('🚫 Erro 401 - Token expirado');
          }
          _deleteToken();
        }
        handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  // ─── Token Storage (com suporte para Web) ────────────
  Future<String?> _readToken() async {
    try {
      final token = await _storage.read(key: AppConstants.tokenKey);
      if (token != null) {
        if (kIsWeb) html.window.console.log('✅ Token lido de FlutterSecureStorage: ${token.substring(0, 20)}...');
        return token;
      }
      
      // No web, tentar fallback para localStorage
      if (kIsWeb) {
        final localStorage = html.window.localStorage;
        final localToken = localStorage[AppConstants.tokenKey];
        if (localToken != null) {
          html.window.console.log('✅ Token lido de localStorage: ${localToken.substring(0, 20)}...');
          return localToken;
        } else {
          html.window.console.log('❌ Nenhum token encontrado (nem em storage, nem em localStorage)');
        }
      }
    } catch (e) {
      if (kIsWeb) {
        html.window.console.error('❌ Erro ao ler token: $e');
      }
    }
    return null;
  }

  Future<void> _writeToken(String token) async {
    try {
      await _storage.write(key: AppConstants.tokenKey, value: token);
    } catch (_) {}
    
    // No web, também salvar em localStorage como fallback
    if (kIsWeb) {
      try {
        html.window.localStorage[AppConstants.tokenKey] = token;
      } catch (_) {}
    }
  }

  Future<void> _deleteToken() async {
    try {
      await _storage.delete(key: AppConstants.tokenKey);
    } catch (_) {}
    
    // No web, também remover de localStorage
    if (kIsWeb) {
      try {
        html.window.localStorage.remove(AppConstants.tokenKey);
      } catch (_) {}
    }
  }

  // ─── Auth ─────────────────────────────────────────────
  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await _dio.post('/auth/register', data: {
      'name': name, 'email': email, 'password': password,
    });
    final token = response.data['token'];
    await _writeToken(token);
    return response.data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email, 'password': password,
    });
    final token = response.data['token'];
    await _writeToken(token);
    return response.data;
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await _dio.post('/auth/google', data: {
      'idToken': idToken,
    });
    final token = response.data['token'];
    await _writeToken(token);
    return response.data;
  }

  Future<Map<String, dynamic>> loginWithGoogleAccessToken({
    required String accessToken,
    required String email,
    String? name,
    String? avatar,
    String? googleId,
  }) async {
    final response = await _dio.post('/auth/google-access-token', data: {
      'accessToken': accessToken,
      'email': email,
      'name': name,
      'avatar': avatar,
      'googleId': googleId,
    });
    final token = response.data['token'];
    await _writeToken(token);
    return response.data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await _dio.put('/auth/fcm-token', data: {'fcmToken': fcmToken});
  }

  Future<void> logout() async {
    await _deleteToken();
  }

  Future<bool> isAuthenticated() async {
    final token = await _readToken();
    return token != null;
  }

  // ─── Events ───────────────────────────────────────────
  Future<Map<String, dynamic>> getEvents({
    double? lat, double? lng, int? radius,
    String? status, String? category, String? city,
    int page = 1, int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;
    if (radius != null) params['radius'] = radius;
    if (status != null) params['status'] = status;
    if (category != null) params['category'] = category;
    if (city != null) params['city'] = city;

    if (kIsWeb) {
      html.window.console.log('📡 Chamando GET /events com parâmetros: $params');
    }
    
    try {
      final response = await _dio.get('/events', queryParameters: params);
      final events = response.data['events'] as List?;
      if (kIsWeb) {
        html.window.console.log('✅ Getting events returned ${events?.length ?? 0} eventos');
      }
      return response.data;
    } catch (e) {
      if (kIsWeb) {
        html.window.console.error('❌ Erro ao buscar eventos: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getEvent(String id) async {
    final response = await _dio.get('/events/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
    final response = await _dio.post('/events', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateEvent(String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/events/$id', data: data);
    return response.data;
  }

  // ─── Check-ins ────────────────────────────────────────
  Future<Map<String, dynamic>> checkin(String eventId, double lat, double lng) async {
    final response = await _dio.post('/checkins', data: {
      'eventId': eventId, 'latitude': lat, 'longitude': lng,
    });
    return response.data;
  }

  Future<void> checkout(String eventId) async {
    await _dio.delete('/checkins/$eventId');
  }

  Future<Map<String, dynamic>> getEventCheckins(String eventId) async {
    final response = await _dio.get('/checkins/event/$eventId');
    return response.data;
  }

  Future<Map<String, dynamic>> getMyCheckins() async {
    final response = await _dio.get('/checkins/me');
    return response.data;
  }

  // ─── Chat ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getMessages(String eventId, {int page = 1}) async {
    final response = await _dio.get('/chat/$eventId', queryParameters: {'page': page});
    return response.data;
  }

  Future<Map<String, dynamic>> sendMessage(String eventId, String content, {String type = 'text'}) async {
    final response = await _dio.post('/chat/$eventId', data: {
      'content': content, 'type': type,
    });
    return response.data;
  }

  // ─── Estimativas ──────────────────────────────────────
  Future<Map<String, dynamic>> getEstimates(String eventId) async {
    final response = await _dio.get('/estimates/$eventId');
    return response.data;
  }

  Future<Map<String, dynamic>> calculateEstimate(String eventId, {
    double? areaSquareMeters, String? densityLevel,
  }) async {
    final response = await _dio.post('/estimates/$eventId/calculate', data: {
      if (areaSquareMeters != null) 'areaSquareMeters': areaSquareMeters,
      if (densityLevel != null) 'densityLevel': densityLevel,
    });
    return response.data;
  }

  // ─── Notificações ─────────────────────────────────────
  Future<Map<String, dynamic>> getNotifications({int page = 1, bool unreadOnly = false}) async {
    final response = await _dio.get('/notifications', queryParameters: {
      'page': page, 'unreadOnly': unreadOnly.toString(),
    });
    return response.data;
  }

  Future<void> markNotificationRead(String id) async {
    await _dio.put('/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.put('/notifications/read-all');
  }
}
