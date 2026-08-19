import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

/// Reads/writes the per-user profile signature (CLAUDE.md §4). The signature is
/// a transparent PNG stored in the private `signatures` bucket at
/// `<user_id>/signature.png`; `profiles.signature_url` holds that object path.
///
/// Every user has exactly one signature, reused wherever signing is required
/// (waybills, PODs, approvals).
class SignatureService {
  SignatureService({SupabaseClient? client, StorageAssetService? assets})
      : _client = client ?? SupabaseConfig.client,
        _assets = assets ?? StorageAssetService();

  final SupabaseClient _client;
  final StorageAssetService _assets;
  final _log = LoggerFactory.getLogger('SignatureService');

  String? get _uid => _client.auth.currentUser?.id;

  static String _objectPath(String userId) => '$userId/signature.png';

  /// Uploads the drawn signature (transparent PNG bytes) for the current user
  /// and records its path on the profile. Returns a resolved (signed) URL for
  /// immediate display.
  Future<String> saveMySignature(Uint8List pngBytes) async {
    final userId = _uid;
    if (userId == null) {
      throw StateError('Not signed in — cannot save a signature.');
    }

    final path = _objectPath(userId);
    try {
      await _client.storage.from(StorageAssetService.signaturesBucket).uploadBinary(
            path,
            pngBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/png',
            ),
          );

      await _client.rpc('set_my_signature', params: {'p_signature_path': path});

      final url = await _assets.resolveSignatureUrl(path);
      if (url == null) {
        throw StateError('Signature saved but URL could not be resolved.');
      }
      return url;
    } catch (e, s) {
      _log.e('Failed to save signature', e, s);
      rethrow;
    }
  }

  /// The current user's stored signature path (bucket-relative), or null if
  /// they have not drawn one yet.
  Future<String?> mySignaturePath() async {
    final userId = _uid;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('signature_url')
        .eq('id', userId)
        .maybeSingle();
    final path = (row?['signature_url'] as String?)?.trim();
    return (path == null || path.isEmpty) ? null : path;
  }

  /// A resolved (signed) URL for the current user's signature, or null.
  Future<String?> mySignatureUrl() async {
    final path = await mySignaturePath();
    if (path == null) return null;
    return _assets.resolveSignatureUrl(path);
  }

  /// Raw PNG bytes for a signature object path — used when compositing the
  /// signature into a generated document (e.g. the waybill PDF). Returns null
  /// if the path is empty or the object cannot be read.
  Future<Uint8List?> signatureBytes(String? objectPath) async {
    final path = objectPath?.trim();
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage
          .from(StorageAssetService.signaturesBucket)
          .download(path);
    } catch (e) {
      _log.w('Could not download signature bytes for "$path": $e');
      return null;
    }
  }
}

final signatureServiceProvider = Provider<SignatureService>(
  (ref) => SignatureService(),
);

/// The current user's signature URL (null until they draw one). Invalidate this
/// after a successful save to refresh any preview.
final mySignatureUrlProvider = FutureProvider.autoDispose<String?>((ref) {
  return ref.watch(signatureServiceProvider).mySignatureUrl();
});
