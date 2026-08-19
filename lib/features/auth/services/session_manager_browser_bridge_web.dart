import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef BrowserSessionExpiredCallback = Future<void> Function();

class SessionManagerBrowserBridge {
  static const _sessionExpiredEventName = 'mineral-guide-session-expired';
  static const _redirectToLoginKey = 'redirect_to_login';
  static const _forceLoginRedirectKey = 'force_login_redirect';
  static const _redirectAfterLoginKey = 'redirectAfterLogin';
  static const _flutterBridgeReadyKey = 'flutter_session_bridge_ready';
  static const _pageHiddenAtKey = 'page_hidden_at';
  static const _managedStorageTokens = <String>[
    'company_data_',
    'employee_data_',
    'company_employees',
    'available_companies',
    'current_user_id',
  ];

  web.EventListener? _sessionExpiredListener;

  void initialize({required BrowserSessionExpiredCallback onSessionExpired}) {
    web.window.sessionStorage.setItem(_flutterBridgeReadyKey, 'true');
    if (_sessionExpiredListener != null) {
      web.window.removeEventListener(
        _sessionExpiredEventName,
        _sessionExpiredListener,
      );
    }
    _sessionExpiredListener = ((web.Event _) {
      unawaited(onSessionExpired());
    }).toJS;
    web.window.addEventListener(
      _sessionExpiredEventName,
      _sessionExpiredListener,
    );
  }

  String? consumeRedirectPath() {
    final sessionStorage = web.window.sessionStorage;
    final redirectPath =
        sessionStorage.getItem(_redirectAfterLoginKey) ??
        sessionStorage.getItem(_redirectToLoginKey);
    final forceLoginRedirect =
        sessionStorage.getItem(_forceLoginRedirectKey) == 'true';

    sessionStorage.removeItem(_redirectAfterLoginKey);
    sessionStorage.removeItem(_redirectToLoginKey);
    sessionStorage.removeItem(_forceLoginRedirectKey);
    sessionStorage.removeItem(_pageHiddenAtKey);

    if (redirectPath != null && redirectPath.isNotEmpty) {
      return redirectPath;
    }

    if (forceLoginRedirect) {
      return '/login';
    }

    return null;
  }

  Future<void> clearSessionState({String redirectPath = '/login'}) async {
    final localStorageKeys = _storageKeys(web.window.localStorage);
    for (final key in localStorageKeys) {
      if (_managedStorageTokens.any(key.contains)) {
        web.window.localStorage.removeItem(key);
      }
    }

    final sessionStorage = web.window.sessionStorage;
    sessionStorage.setItem(_forceLoginRedirectKey, 'true');
    sessionStorage.setItem(_redirectToLoginKey, redirectPath);
    sessionStorage.removeItem(_pageHiddenAtKey);
  }

  void dispose() {
    web.window.sessionStorage.removeItem(_flutterBridgeReadyKey);
    if (_sessionExpiredListener != null) {
      web.window.removeEventListener(
        _sessionExpiredEventName,
        _sessionExpiredListener,
      );
      _sessionExpiredListener = null;
    }
  }

  List<String> _storageKeys(web.Storage storage) {
    final keys = <String>[];
    for (var index = 0; index < storage.length; index++) {
      final key = storage.key(index);
      if (key != null) {
        keys.add(key);
      }
    }
    return keys;
  }
}
