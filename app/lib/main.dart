import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'screens/webview/webview_screen.dart';
import 'utils/web_utils.dart' as web;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Run quick web-only sanitation BEFORE anything else that might read
  // from localStorage (prevents dart:html Storage.forEach crashes).
  if (kIsWeb) {
    web.webSanitizeLocalStorage();
  }

  // Habilita WebView nativo no Android (registra implementação da plataforma)
  if (Platform.isAndroid) {
    AndroidWebViewPlatform.registerWith();
  }

  // Forçar orientação retrato (melhor experiência tipo app)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const EstouAquiApp());
}

class EstouAquiApp extends StatelessWidget {
  const EstouAquiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estou Aqui',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6c63ff),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}

