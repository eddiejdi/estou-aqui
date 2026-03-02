/// Stub para compilação não-web (coalition dashboard).
/// Quando rodando em plataformas nativas (Android/iOS),
/// as importações de dart:html e dart:ui_web não estão disponíveis.

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
