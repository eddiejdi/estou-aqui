import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/subscription.dart';

// ─── Subscription State ─────────────────────────────────

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, UserSubscription>((ref) {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends StateNotifier<UserSubscription> {
  SubscriptionNotifier() : super(const UserSubscription()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('user_subscription');
      if (json != null) {
        state = UserSubscription.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Mantém free por padrão
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_subscription', jsonEncode(state.toJson()));
  }

  /// Atualiza o plano do usuário (após compra confirmada)
  Future<void> upgradePlan(SubscriptionPlan plan) async {
    state = state.copyWith(
      plan: plan,
      isActive: true,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    await _saveToStorage();
  }

  /// Adiciona um addon avulso
  Future<void> addAddon(AddonType addon) async {
    if (!state.activeAddons.contains(addon)) {
      state = state.copyWith(
        activeAddons: [...state.activeAddons, addon],
      );
      await _saveToStorage();
    }
  }

  /// Remove um addon
  Future<void> removeAddon(AddonType addon) async {
    state = state.copyWith(
      activeAddons: state.activeAddons.where((a) => a != addon).toList(),
    );
    await _saveToStorage();
  }

  /// Restaura assinatura do servidor
  Future<void> restoreFromServer(Map<String, dynamic> data) async {
    state = UserSubscription.fromJson(data);
    await _saveToStorage();
  }

  /// Reseta para plano gratuito
  Future<void> resetToFree() async {
    state = const UserSubscription();
    await _saveToStorage();
  }
}

// ─── Convenience providers ──────────────────────────────

/// Verifica se deve mostrar anúncios
final showAdsProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).showAds;
});

/// Verifica se tem analytics
final hasAnalyticsProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).hasFeature(AddonType.analytics);
});

/// Verifica se tem blue check
final hasBlueCheckProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).hasFeature(AddonType.blueCheck);
});

/// Verifica se tem export
final hasExportProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).hasFeature(AddonType.exportReports);
});

/// Verifica se tem Grafana
final hasGrafanaProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).hasFeature(AddonType.grafanaDashboard);
});
