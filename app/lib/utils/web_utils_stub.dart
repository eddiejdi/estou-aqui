/// Stub implementations for non-web platforms (Android, iOS, etc.)

void webConsoleLog(String message) {}
void webConsoleWarn(String message) {}
void webConsoleError(String message) {}

String? webLocalStorageRead(String key) => null;
void webLocalStorageWrite(String key, String value) {}
void webLocalStorageRemove(String key) {}
