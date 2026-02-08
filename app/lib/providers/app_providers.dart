import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';

// ─── Services ───────────────────────────────────────────
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
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
