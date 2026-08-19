typedef BrowserSessionExpiredCallback = Future<void> Function();

class SessionManagerBrowserBridge {
  void initialize({required BrowserSessionExpiredCallback onSessionExpired}) {}

  String? consumeRedirectPath() => null;

  Future<void> clearSessionState({String redirectPath = '/login'}) async {}

  void dispose() {}
}
