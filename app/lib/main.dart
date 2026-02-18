import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/webview/webview_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

