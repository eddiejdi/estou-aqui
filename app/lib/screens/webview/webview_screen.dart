import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tela principal — renderiza o site Estou Aqui como app nativo (modelo Open WebUI).
/// Suporta: GPS, câmera/upload, JavaScript, navigation gestures, pull-to-refresh.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  static const String siteUrl = 'https://estouaqui.rpa4all.com';

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('EstouAquiApp/1.0 (Android; Flutter WebView)')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            // Injetar CSS para esconder elementos nativos desnecessários (ex: barra de download do app)
            _controller.runJavaScript('''
              (function() {
                var style = document.createElement('style');
                style.textContent = '.app-download-banner, .install-prompt { display: none !important; }';
                document.head.appendChild(style);
              })();
            ''');
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            // Links externos — abrir no browser do sistema
            if (!request.url.startsWith(WebViewScreen.siteUrl) &&
                !request.url.startsWith('https://estouaqui.rpa4all.com') &&
                !request.url.contains('accounts.google.com') &&
                !request.url.contains('googleapis.com') &&
                uri.scheme.startsWith('http')) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setOnConsoleMessage((message) {
        debugPrint('🌐 JS: ${message.message}');
      })
      ..loadRequest(Uri.parse(WebViewScreen.siteUrl));

    // Configurar permissão de geolocalização para Android
    if (Platform.isAndroid) {
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (GeolocationPermissionsRequestParams params) async {
          return const GeolocationPermissionsResponse(allow: true, retain: true);
        },
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false; // Não sair do app, navegar para trás no WebView
    }
    // Confirmar saída do app
    if (!mounted) return true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do Estou Aqui?'),
        content: const Text('Deseja fechar o aplicativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Status bar transparente para experiência full-screen
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF1a1a2e),
      statusBarIconBrightness: Brightness.light,
    ));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1a1a2e),
        body: SafeArea(
          child: Stack(
            children: [
              // WebView principal
              if (!_hasError)
                WebViewWidget(controller: _controller),

              // Indicador de progresso
              if (_isLoading && !_hasError)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6c63ff),
                    ),
                    minHeight: 3,
                  ),
                ),

              // Splash/loading overlay
              if (_isLoading && _loadingProgress < 30)
                Container(
                  color: const Color(0xFF1a1a2e),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '📍',
                          style: TextStyle(fontSize: 64),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Estou Aqui',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Carregando...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 24),
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF6c63ff),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Tela de erro
              if (_hasError)
                Container(
                  color: const Color(0xFF1a1a2e),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white54,
                          size: 80,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sem conexão',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Verifique sua internet e tente novamente.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _isLoading = true;
                            });
                            _controller.loadRequest(
                              Uri.parse(WebViewScreen.siteUrl),
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6c63ff),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
