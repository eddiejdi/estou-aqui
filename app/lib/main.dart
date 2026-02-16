import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'router.dart';
import 'utils/theme.dart';
import 'services/checkin_retry_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar retry de check-ins pendentes
  CheckinRetryService().init();
  runApp(const ProviderScope(child: EstouAquiApp()));
}

class EstouAquiApp extends ConsumerWidget {
  const EstouAquiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Estou Aqui',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
    );
  }
}
