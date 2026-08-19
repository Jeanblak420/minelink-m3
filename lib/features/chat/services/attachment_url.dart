import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

final _log = LoggerFactory.getLogger('ChatAttachmentUrl');

/// How long a signed attachment URL stays valid. Long enough to open and read a
/// document, short enough that a leaked link is not a permanent one.
const int kChatAttachmentUrlTtlSeconds = 3600;

/// Buckets a chat/support attachment may live in. Both went private on
/// 2026-08-12 (P3-52 / P3-53, client ruling 3).
const String kChatAttachmentsBucket = 'chat-attachments';
const String kSupportAttachmentsBucket = 'support-attachments';

/// The *other* chat bucket. `chat_files` predates `chat-attachments` and has
/// always been private; `ChatScreen` still writes to it via `FileUploadWidget`
/// while `chat_dock` writes to `chat-attachments`. Which of the two survives is
/// P3-54's decision, not this file's — but until it is taken, a value written
/// by either writer has to resolve, or one of the two chat surfaces silently
/// shows every attachment as unavailable.
const String kChatFilesBucket = 'chat_files';

const Set<String> _knownBuckets = {
  kChatAttachmentsBucket,
  kSupportAttachmentsBucket,
  kChatFilesBucket,
};

/// Builds the value stored in `chat_messages.file_url` /
/// `support_messages.file_url`: a **bucket-qualified object path**, not a URL.
///
/// A signed URL expires, so persisting one would give attachments that work
/// until they silently stop. The path is stored and signed on read — the same
/// pattern `pod_uploads.photo_url` and `compliance_documents` already use. The
/// bucket is folded into the stored value because chat and support attachments
/// render through the same bubble and their paths are otherwise identical in
/// shape (`<uuid>/<uuid>.<ext>`).
String qualifiedAttachmentPath(String bucket, String path) => '$bucket/$path';

/// Resolves a stored attachment value to something an image widget or browser
/// can open, returning null when it cannot be signed.
///
/// Tolerant of three shapes, in this order:
///  * an `http…` value — returned unchanged. These are legacy public URLs from
///    before the buckets went private. There are none in production (both
///    buckets held 0 objects at the cutover, verified), but passing them
///    through costs nothing and mangling them would be irreversible.
///  * `bucket/path/to/object` where bucket is one of the two known attachment
///    buckets — signed against that bucket.
///  * anything else — treated as a bare path in `chat-attachments`, which is
///    where every unqualified legacy value would have come from.
///
/// Returns null rather than throwing: a failure here means the viewer is not a
/// participant of that room or ticket, and the caller renders a stated
/// "unavailable" state instead of a broken image.
/// Memoised [resolveAttachmentUrl], keyed by the stored value.
///
/// A `FutureBuilder` builds its future inside `build()`, and a chat bubble
/// rebuilds constantly — on every new message, reaction, hover and scroll. Left
/// unmemoised that is one signing round-trip per rebuild per attachment, and
/// the image would flash back to its placeholder each time. Entries are re-signed
/// after [_memoTtl], comfortably inside the URL's own one-hour life, so a long
/// session never serves a link that has expired underneath it.
Future<String?> resolveAttachmentUrlCached(String? stored) {
  final key = stored?.trim() ?? '';
  if (key.isEmpty) return Future.value(null);
  final hit = _memo[key];
  if (hit != null && DateTime.now().difference(hit.at) < _memoTtl) {
    return hit.url;
  }
  final future = resolveAttachmentUrl(stored);
  _memo[key] = (at: DateTime.now(), url: future);
  return future;
}

const Duration _memoTtl = Duration(minutes: 45);
final Map<String, ({DateTime at, Future<String?> url})> _memo = {};

/// Drops the memo — call after signing out so one user's signed links are not
/// handed to the next account on a shared device.
void clearAttachmentUrlCache() => _memo.clear();

Future<String?> resolveAttachmentUrl(String? stored) async {
  final value = stored?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;

  // `storage://bucket/path` — the shape StorageAssetService.toStorableReference
  // writes, used by ChatScreen's upload path. Stripped first so the
  // bucket/path split below sees the same shape from either writer.
  var rest = value.startsWith('storage://') ? value.substring(10) : value;

  var bucket = kChatAttachmentsBucket;
  var path = rest;
  final slash = rest.indexOf('/');
  if (slash > 0) {
    final head = rest.substring(0, slash);
    if (_knownBuckets.contains(head)) {
      bucket = head;
      path = rest.substring(slash + 1);
    }
  }
  if (path.isEmpty) return null;

  try {
    return await SupabaseConfig.client.storage
        .from(bucket)
        .createSignedUrl(path, kChatAttachmentUrlTtlSeconds);
  } catch (e) {
    // Not a participant, or the object is gone. Logged rather than swallowed —
    // a silent catch here is what hid the presence fault in P7-30 for as long
    // as it hid it.
    _log.w('could not sign attachment $bucket/$path: $e');
    return null;
  }
}
