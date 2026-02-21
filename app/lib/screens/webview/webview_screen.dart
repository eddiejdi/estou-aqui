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

  // URL da app web rodando no homelab (Docker na porta 8080)
  // Em produção, usar: 'https://estouaqui.rpa4all.com'
  // Em dev/homelab, usar: 'http://192.168.15.2:8080'
  static const String siteUrl = 'http://192.168.15.2:8080';

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasTimedOut = false;
  int _loadingProgress = 0;
  Timer? _initialLoadTimeout;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _initialLoadTimeout?.cancel();
    _initialLoadTimeout = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      if (_isLoading) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _hasTimedOut = true;
        });
      }
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Use user-agent compatível com Android Chrome (evita branches "in-app" que
      // podem ativar código diferente no web bundle e causar null checks).
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.5672.137 Mobile Safari/537.36')
      // Torna o background do WebView transparente para respeitar o scaffold
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('WebView onPageStarted: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onProgress: (progress) {
            debugPrint('WebView progress: $progress%');
            if (mounted) {
              setState(() => _loadingProgress = progress);
            }
          },
          onPageFinished: (url) {
            debugPrint('WebView onPageFinished: $url');
            _initialLoadTimeout?.cancel();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = false;
                _hasTimedOut = false;
              });
            }
            // Injetar CSS para esconder elementos nativos desnecessários (ex: barra de download do app)
            // + instalar um handler global de erros para evitar "tela branca" quando o
            // bundle web lançar uma exceção — mostra fallback amigável e loga mensagem.
            _controller.runJavaScript('''
              (function() {
                try {
                  var style = document.createElement('style');
                  style.textContent = '.app-download-banner, .install-prompt { display: none !important; }';
                  document.head.appendChild(style);

                  // Captura erros não tratados no app web e fornece fallback visível
                  window.addEventListener('error', function(e) {
                    console.error('WebViewGlobalError', e && e.message ? e.message : e);
                    try {
                      document.body.innerHTML = '\n                        <div style="display:flex;align-items:center;justify-content:center;height:100vh;background:#111;color:#fff;font-family:sans-serif;">\n                          <div style="text-align:center;max-width:480px;padding:24px;">\n                            <h2>Ops — erro no app web</h2>\n                            <p>Houve um problema ao inicializar a versão web dentro do WebView. Tente abrir no navegador ou atualize a página.</p>\n                            <button id="open-external" style="background:#6c63ff;color:#fff;padding:10px 16px;border-radius:6px;border:none;">Abrir no navegador</button>\n                          </div>\n                        </div>';
                      var btn = document.getElementById('open-external');
                      if (btn) btn.addEventListener('click', function(){ window.location.href = 'https://estouaqui.rpa4all.com'; });
                    } catch (_) { /* swallow */ }
                  });

                  window.addEventListener('unhandledrejection', function(ev){
                    console.error('WebViewUnhandledRejection', ev && ev.reason ? ev.reason : ev);
                  });
                } catch (e) { console.error('injection-failed', e); }
              })();
            ''');

            // Se o DOM ficar vazio (bundle travou antes de renderizar), substituir por
            // fallback para evitar tela em branco — verifique após curto atraso.
            Future.delayed(const Duration(milliseconds: 350), () async {
              try {
                final children = await _controller.runJavaScriptReturningResult('document.body && document.body.children.length');
                debugPrint('WebView DOM children count: $children');
                if (children == 0 || children == '0') {
                  await _controller.runJavaScript(
                    "document.body.innerHTML = '<div style=\"display:flex;align-items:center;justify-content:center;height:100vh;background:#111;color:#fff;font-family:sans-serif;\"><div style=\"text-align:center;max-width:480px;padding:24px;\"><h2>Versão web indisponível no WebView</h2><p>Tente abrir o app no navegador ou atualize.\n</p><a href=\"https://estouaqui.rpa4all.com\" style=\"background:#6c63ff;color:#fff;padding:10px 16px;border-radius:6px;text-decoration:none;\">Abrir no navegador</a></div></div>'",
                  );
                }
              } catch (e) {
                debugPrint('DOM-check failed: $e');
              }
            });
          },
          onWebResourceError: (error) {
            debugPrint('WebView resource error: code=${error.errorCode} description=${error.description} mainFrame=${error.isForMainFrame}');
            _initialLoadTimeout?.cancel();
            // Evita falso-positivo: erros de sub-recursos (favicon/css/etc)
            // não devem derrubar a página inteira para tela de erro.
            if (error.isForMainFrame != true) {
              return;
            }
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _hasTimedOut = false;
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            debugPrint('WebView navigation request: ${request.url}');
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

  @override
  void dispose() {
    _initialLoadTimeout?.cancel();
    super.dispose();
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
                          'Não foi possível carregar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _hasTimedOut
                                ? 'A página demorou para responder. Toque em "Tentar novamente".'
                                : 'Verifique sua internet e tente novamente.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
                              _hasTimedOut = false;
                              _loadingProgress = 0;
                            });
                            _initialLoadTimeout?.cancel();
                            _initialLoadTimeout = Timer(
                              const Duration(seconds: 15),
                              () {
                                if (!mounted) return;
                                if (_isLoading) {
                                  setState(() {
                                    _isLoading = false;
                                    _hasError = true;
                                    _hasTimedOut = true;
                                  });
                                }
                              },
                            );
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
