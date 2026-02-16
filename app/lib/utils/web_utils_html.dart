import 'dart:html' as html;

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
