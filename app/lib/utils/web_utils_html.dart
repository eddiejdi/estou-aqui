import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// Log to browser console
void webConsoleLog(String message) {
  html.window.console.log(message);
}

/// Warn to browser console
void webConsoleWarn(String message) {
  html.window.console.warn(message);
}

/// Error to browser console
void webConsoleError(String message) {
  html.window.console.error(message);
}

/// Read from localStorage
String? webLocalStorageRead(String key) {
  return html.window.localStorage[key];
}

/// Write to localStorage
void webLocalStorageWrite(String key, String value) {
  html.window.localStorage[key] = value;
}

/// Remove from localStorage
void webLocalStorageRemove(String key) {
  html.window.localStorage.remove(key);
}

/// Sanitize localStorage by removing entries with null/undefined values or
/// other inconsistent state that can crash dart:html Storage iteration.
/// This is defensive and should run very early on web app startup.
void webSanitizeLocalStorage() {
  try {
    // Iterate by index (safe) and validate values explicitly.
    for (var i = html.window.localStorage.length - 1; i >= 0; --i) {
      // Use JS interop to call the DOM `Storage.key(index)` method directly —
      // dart:html does not expose `key` and higher-level iterables may call
      // Storage.forEach which can throw on corrupted entries.
      final key = js_util.callMethod(html.window.localStorage, 'key', [i]) as String?;
      if (key == null) continue;
      // Use direct lookup and treat null/undefined as corrupted.
      final value = html.window.localStorage[key];
      if (value == null) {
        // Remove corrupted entry to avoid dart:html Storage.forEach crashes
        html.window.localStorage.remove(key);
        html.window.console.warn('webSanitizeLocalStorage — removed corrupted key: $key');
      }
    }
  } catch (err, st) {
    // Best-effort — do not rethrow (must not block app startup)
    html.window.console.error('webSanitizeLocalStorage failed: $err');
    html.window.console.debug(st.toString());
  }
}
