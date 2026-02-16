/// Platform-safe web utilities.
/// On web: delegates to dart:html. On mobile: no-ops.
export 'web_utils_stub.dart' if (dart.library.html) 'web_utils_html.dart';
