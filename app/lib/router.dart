import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/event/event_detail_screen.dart';
import 'screens/event/create_event_screen.dart';
import 'screens/event/events_list_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/addons/event_analytics_screen.dart';
import 'screens/addons/export_reports_screen.dart';
import 'screens/addons/event_grafana_screen.dart';
import 'screens/addons/blue_check_screen.dart';
import 'screens/coalition/coalitions_list_screen.dart';
import 'screens/coalition/coalition_detail_screen.dart';
import 'models/event.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/events',
            builder: (context, state) => const EventsListScreen(),
          ),
          GoRoute(
            path: '/coalitions',
            builder: (context, state) => const CoalitionsListScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/event/create',
        builder: (context, state) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/event/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EventDetailScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/chat/:eventId',
        builder: (context, state) {
          final eventId = state.pathParameters['eventId']!;
          return ChatScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/event/:id/analytics',
        builder: (context, state) {
          final event = state.extra as SocialEvent;
          return EventAnalyticsScreen(event: event);
        },
      ),
      GoRoute(
        path: '/event/:id/export',
        builder: (context, state) {
          final event = state.extra as SocialEvent;
          return ExportReportsScreen(event: event);
        },
      ),
      GoRoute(
        path: '/event/:id/grafana',
        builder: (context, state) {
          final event = state.extra as SocialEvent;
          return EventGrafanaScreen(event: event);
        },
      ),
      GoRoute(
        path: '/blue-check',
        builder: (context, state) => const BlueCheckScreen(),
      ),
      GoRoute(
        path: '/coalition/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CoalitionDetailScreen(coalitionId: id);
        },
      ),
    ],
  );
});
