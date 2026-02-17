/// Stub para compilação não-web.
/// Quando rodando em plataformas nativas (Android/iOS),
/// as importações de dart:html e dart:ui_web não estão disponíveis.
/// Este arquivo fornece stubs vazios para que o código compile.

// Stubs mínimos para IFrameElement e platformViewRegistry
class IFrameElement {
  String? src;
  CssStyleDeclaration get style => CssStyleDeclaration();
  String? allow;
  void setAttribute(String name, String value) {}
}

class CssStyleDeclaration {
  String? border;
  String? width;
  String? height;
}

class PlatformViewRegistry {
  void registerViewFactory(String viewType, dynamic Function(int) factory) {}
}

final platformViewRegistry = PlatformViewRegistry();
