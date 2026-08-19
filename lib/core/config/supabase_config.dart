import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String _configuredUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _configuredPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  static const String _configuredLegacyAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static bool _debugMode = kDebugMode;
  static String _resolvedUrl = _configuredUrl;
  static String _resolvedPublishableKey = _configuredPublishableKey;
  static String _resolvedLegacyAnonKey = _configuredLegacyAnonKey;
  static String _resolvedConfigurationSource = _deriveDartDefineSource();
  static final _logger = LoggerFactory.getLogger('SupabaseConfig');
  static const _bundledConfigAssets = <String>[
    'config/supabase.local.json',
    'config/supabase.live.json',
  ];

  static SupabaseClient get client => Supabase.instance.client;
  static bool get hasOverrideConfig =>
      _configuredUrl.isNotEmpty ||
      _configuredPublishableKey.isNotEmpty ||
      _configuredLegacyAnonKey.isNotEmpty;
  static String get url => _resolvedUrl;
  static String get publishableKey => _resolvedPublishableKey;
  static String get legacyAnonKey => _resolvedLegacyAnonKey;
  static String get anonKey =>
      publishableKey.isNotEmpty ? publishableKey : legacyAnonKey;
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
  static bool get isUsingDefaultConfig => !hasOverrideConfig && isConfigured;
  static String get configurationSource => _resolvedConfigurationSource;

  static bool get debugMode => _debugMode;

  static set debugMode(bool value) {
    _debugMode = value;
    _logger.d('Supabase debug mode ${value ? 'enabled' : 'disabled'}');
  }

  static String get configurationHelp =>
      'Missing Supabase configuration. Provide SUPABASE_URL and '
      'SUPABASE_PUBLISHABLE_KEY (preferred) or SUPABASE_ANON_KEY via '
      '--dart-define or --dart-define-from-file. If you use plain '
      '`flutter run`, the app will also look for bundled config files in '
      '`config/supabase.local.json` and then `config/supabase.live.json`.';

  static String _deriveDartDefineSource() {
    if (_configuredPublishableKey.isNotEmpty) {
      return 'SUPABASE_PUBLISHABLE_KEY dart-define';
    }
    if (_configuredLegacyAnonKey.isNotEmpty) {
      return 'SUPABASE_ANON_KEY dart-define';
    }
    return 'missing configuration';
  }

  static Future<void> _resolveConfiguration() async {
    if (hasOverrideConfig) {
      _resolvedUrl = _configuredUrl;
      _resolvedPublishableKey = _configuredPublishableKey;
      _resolvedLegacyAnonKey = _configuredLegacyAnonKey;
      _resolvedConfigurationSource = _deriveDartDefineSource();
      return;
    }

    // Which of the candidates were actually bundled. `supabase.local.json` is
    // developer-optional and usually absent; asking the bundle for it anyway
    // makes the web engine log "failed to fetch … HTTP status 404" before Dart
    // can catch anything, so the manifest is consulted first.
    final bundled = await _bundledAssetPaths();

    for (final assetPath in _bundledConfigAssets) {
      if (bundled != null && !bundled.contains(assetPath)) {
        continue;
      }
      final bundledConfig = await _tryLoadBundledConfig(assetPath);
      if (bundledConfig == null) {
        continue;
      }

      _resolvedUrl = bundledConfig.url;
      _resolvedPublishableKey = bundledConfig.publishableKey;
      _resolvedLegacyAnonKey = bundledConfig.legacyAnonKey;
      _resolvedConfigurationSource = bundledConfig.source;
      return;
    }

    _resolvedUrl = _configuredUrl;
    _resolvedPublishableKey = _configuredPublishableKey;
    _resolvedLegacyAnonKey = _configuredLegacyAnonKey;
    _resolvedConfigurationSource = 'missing configuration';
  }

  /// Asset keys present in this build, or null if the manifest can't be read
  /// (in which case callers fall back to attempting the load).
  static Future<Set<String>?> _bundledAssetPaths() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().toSet();
    } catch (e) {
      _logger.d('Asset manifest unavailable, probing config assets directly: $e');
      return null;
    }
  }

  static Future<_ResolvedSupabaseConfig?> _tryLoadBundledConfig(
    String assetPath,
  ) async {
    try {
      final rawJson = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(rawJson);

      if (decoded is! Map<String, dynamic>) {
        _logger.w('Ignoring invalid Supabase config asset at $assetPath');
        return null;
      }

      final url = (decoded['SUPABASE_URL'] ?? '').toString().trim();
      final publishableKey = (decoded['SUPABASE_PUBLISHABLE_KEY'] ?? '')
          .toString()
          .trim();
      final legacyAnonKey = (decoded['SUPABASE_ANON_KEY'] ?? '')
          .toString()
          .trim();

      if (url.isEmpty || (publishableKey.isEmpty && legacyAnonKey.isEmpty)) {
        _logger.w('Ignoring incomplete Supabase config asset at $assetPath');
        return null;
      }

      return _ResolvedSupabaseConfig(
        url: url,
        publishableKey: publishableKey,
        legacyAnonKey: legacyAnonKey,
        source: '$assetPath bundled asset',
      );
    } catch (e) {
      if (!assetPath.endsWith('supabase.local.json')) {
        _logger.d('Supabase config asset $assetPath is not available: $e');
      }
      return null;
    }
  }

  static void _ensureConfigured() {
    if (!isConfigured) {
      throw StateError(configurationHelp);
    }
  }

  static Future<void> _initializeSupabase({required bool debug}) async {
    await _resolveConfiguration();
    _ensureConfigured();
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: debug,
      authOptions: const FlutterAuthClientOptions(),
    );
  }

  static Future<void> initialize() async {
    try {
      try {
        final _ = Supabase.instance.client;
        _logger.i('Supabase already initialized');
        return;
      } catch (_) {
        // Expected when Supabase has not been initialized yet.
      }

      await _initializeSupabase(debug: _debugMode);

      _logger.i(
        'Supabase initialized with $configurationSource for $url, '
        'debug mode: $_debugMode, and session persistence enabled',
      );
    } on StateError {
      rethrow;
    } catch (e) {
      _logger.e('Error initializing Supabase: $e');
      throw Exception(
        'Failed to initialize the application. Please check your '
        'Supabase configuration and internet connection, then try again.',
      );
    }
  }

  static Future<void> reinitialize({bool debug = false}) async {
    bool wasInitialized = false;

    try {
      try {
        final _ = Supabase.instance.client;
        wasInitialized = true;
        _debugMode = debug;
        _logger.i('Supabase already initialized, updated debug mode: $debug');
        return;
      } catch (_) {
        wasInitialized = false;
      }
    } catch (e) {
      // This is expected if Supabase wasn't initialized yet
      _logger.d('Supabase instance not yet initialized: $e');
    }

    if (!wasInitialized) {
      _debugMode = debug;

      try {
        await _initializeSupabase(debug: debug);

        _logger.i(
          'Supabase initialized with $configurationSource and debug mode: $debug',
        );
      } on StateError {
        rethrow;
      } catch (e) {
        _logger.e('Error initializing Supabase', e);
      }
    }
  }
}

class _ResolvedSupabaseConfig {
  final String url;
  final String publishableKey;
  final String legacyAnonKey;
  final String source;

  const _ResolvedSupabaseConfig({
    required this.url,
    required this.publishableKey,
    required this.legacyAnonKey,
    required this.source,
  });
}
