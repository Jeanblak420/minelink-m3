// A temp directory for the plugins that insist on one.
//
// `flutter_map`'s tile layer runs through `flutter_cache_manager`, which asks
// `path_provider` where to keep its cache before it will even decide a tile is
// unavailable. In a widget test that is a `MissingPluginException` thrown from
// an async gap — so it does not fail the widget, it fails the TEST, after the
// frame, with a stack that points at a cache manager rather than at anything
// the screen did.
//
// This answers the channel with a real directory under the system temp, which
// is enough for the cache manager to start and then find nothing. It does not
// make tiles appear: `flutter_test` answers every HTTP request with a 400, so
// the map canvas stays the empty-tile colour. That is a known limit of
// photographing a map screen off a device, and the renders say so.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers the mock for the rest of the test run.
void installFakePathProvider() {
  final dir = Directory.systemTemp.createTempSync('minelink_render_');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      switch (call.method) {
        case 'getTemporaryDirectory':
        case 'getApplicationSupportDirectory':
        case 'getApplicationDocumentsDirectory':
        case 'getLibraryDirectory':
        case 'getApplicationCacheDirectory':
        case 'getDownloadsDirectory':
          return dir.path;
        case 'getExternalStorageDirectory':
          return dir.path;
        case 'getExternalCacheDirectories':
        case 'getExternalStorageDirectories':
          return <String>[dir.path];
        default:
          return null;
      }
    },
  );
}
