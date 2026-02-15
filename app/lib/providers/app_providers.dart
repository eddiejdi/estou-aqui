import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/geocode_service.dart';
import '../services/socket_service.dart';

// ─── Services ───────────────────────────────────────────
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
final geocodeServiceProvider = Provider<GeocodeService>((ref) => GeocodeService());
final socketServiceProvider = Provider<SocketService>((ref) => SocketService());

// ─── Auth State ─────────────────────────────────────────
final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final ApiService _api;

  AuthNotifier(this._api) : super(const AsyncValue.data(null));

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final data = await _api.login(email, password);
      state = AsyncValue.data(User.fromJson(data['user']));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final data = await _api.register(name, email, password);
      state = AsyncValue.data(User.fromJson(data['user']));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> checkAuth() async {
    try {
      if (await _api.isAuthenticated()) {
        final data = await _api.getProfile();
        state = AsyncValue.data(User.fromJson(data['user']));
      }
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> logout() async {
    await _api.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      // No web, o clientId vem da meta tag google-signin-client_id no index.html
      // No mobile, passamos explicitamente
      const webClientId = '666885877649-uhl98kcch60l4cqctt2e347nhlhsqta5.apps.googleusercontent.com';
      
      final google = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: kIsWeb ? null : webClientId,
      );
      
      final account = await google.signIn();
      if (account == null) {
        // Usuário cancelou
        state = const AsyncValue.data(null);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      
      if (idToken == null || idToken.isEmpty) {
        // No web, se idToken é null, criar usuário localmente como fallback
        if (kIsWeb) {
          final user = User(
            id: account.id,
            name: account.displayName ?? account.email,
            email: account.email,
            avatar: account.photoUrl,
          );
          state = AsyncValue.data(user);
          return;
        }
        state = AsyncValue.error(
          Exception('Não foi possível obter o token do Google'),
          StackTrace.current,
        );
        return;
      }

      // Enviar idToken ao backend para verificação e criação/login
      final data = await _api.loginWithGoogle(idToken);
      state = AsyncValue.data(User.fromJson(data['user']));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ─── Events ─────────────────────────────────────────────
final eventsProvider = StateNotifierProvider<EventsNotifier, AsyncValue<List<SocialEvent>>>((ref) {
  return EventsNotifier(ref.read(apiServiceProvider));
});

class EventsNotifier extends StateNotifier<AsyncValue<List<SocialEvent>>> {
  final ApiService _api;

  EventsNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> loadEvents({double? lat, double? lng, String? status, String? category}) async {
    state = const AsyncValue.loading();
    try {
      final data = await _api.getEvents(lat: lat, lng: lng, status: status, category: category);
      final events = (data['events'] as List)
          .map((e) => SocialEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(events);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh({double? lat, double? lng}) async {
    await loadEvents(lat: lat, lng: lng);
  }
}

// ─── Selected Event ─────────────────────────────────────
final selectedEventProvider = StateNotifierProvider<SelectedEventNotifier, AsyncValue<SocialEvent?>>((ref) {
  return SelectedEventNotifier(ref.read(apiServiceProvider));
});

class SelectedEventNotifier extends StateNotifier<AsyncValue<SocialEvent?>> {
  final ApiService _api;

  SelectedEventNotifier(this._api) : super(const AsyncValue.data(null));

  Future<void> loadEvent(String id) async {
    state = const AsyncValue.loading();
    try {
      final data = await _api.getEvent(id);
      state = AsyncValue.data(SocialEvent.fromJson(data['event']));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ─── Checkin State ──────────────────────────────────────
final myCheckinsProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    final data = await api.getMyCheckins();
    return (data['checkins'] as List).map((c) => c['eventId'] as String).toList();
  } catch (_) {
    return [];
  }
});

// ─── Notifications Badge ────────────────────────────────
final unreadNotificationsProvider = StateProvider<int>((ref) => 0);
