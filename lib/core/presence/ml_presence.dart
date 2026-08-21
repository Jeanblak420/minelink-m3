/// One rule for whether somebody is online, away, or offline.
///
/// ## Why this is not three private copies
///
/// It was. `employee_register_screen.dart` and `employee_profile_screen.dart`
/// each declared `enum _Presence { online, away, offline }`, a
/// `const _awayWindow = Duration(minutes: 30)`, a `_bestLastSeen` that folds
/// the live channel's stamp into the database heartbeat, and a `_presenceOf`
/// that decides between the three — character for character the same in both.
/// The chat dock has a fourth variant that skips Away entirely and prints
/// "Last seen X". Four surfaces answering one question about the same person.
///
/// ## What was actually wrong with all of them
///
/// Every copy measured the age with **`DateTime.now()`**, and the two values it
/// was measuring against did not agree about what a `DateTime` even meant:
///
///   * `list_company_member_presence` came back through `MlTime.sast(...)` — a
///     South African **wall clock**, whose `millisecondsSinceEpoch` depends on
///     the reader's own device offset;
///   * the realtime channel wrote **`DateTime.now()`** — a device-local
///     instant.
///
/// `liveStamp.isAfter(db)` compared the two directly, and
/// `DateTime.now().difference(seen)` then measured the winner against a third
/// clock. On a device in South Africa the three agree and nothing looks wrong,
/// which is exactly why it survived. On a device left on UTC the database
/// stamp reads two hours in the FUTURE, so it always wins the `isAfter`, the
/// difference comes out negative, and `<= 30 minutes` is trivially true —
/// **everybody is "Away", forever, including someone last seen a year ago.**
/// Two hours the other way and someone seen a minute ago reads "Offline".
///
/// It was photographed in the frozen-clock render, which is the same fault
/// from a third angle: the register printed *"Last seen 11 min ago"* — through
/// `MlTime.ago`, which honours `MlTime.debugClock` — beside a dot and a
/// counter that read **Offline** and **AWAY 0**, through `DateTime.now()`,
/// which does not. One row, two clocks, contradicting each other in writing.
///
/// So the rule is here, it takes **instants**, and it measures with
/// [MlTime.instant] (CLAUDE.md §7.1). The two services that read
/// `profiles.last_seen_at` hand back instants now, and
/// `presenceLastSeenProvider` stamps with `MlTime.instant()`.
library;

import 'package:flutter_application_1/core/time/ml_time.dart';

/// How recently someone must have been seen — while NOT in the live presence
/// set — to count as [MlPresence.away] rather than [MlPresence.offline].
const Duration kPresenceAwayWindow = Duration(minutes: 30);

enum MlPresence { online, away, offline }

/// The newer of the database heartbeat and the live channel's stamp.
///
/// Both are instants. Returns null when neither source has ever seen them,
/// which is not the same as "offline for a long time" — it is "never active",
/// and the surfaces render it differently.
DateTime? mlLastSeen({DateTime? dbLastSeen, DateTime? liveLastSeen}) {
  if (liveLastSeen == null) return dbLastSeen;
  if (dbLastSeen == null) return liveLastSeen;
  return liveLastSeen.isAfter(dbLastSeen) ? liveLastSeen : dbLastSeen;
}

/// [online] is membership of the realtime presence set — the only positive
/// signal there is. Everything else is inferred from when they were last seen.
///
/// [asOf] exists so a list rendering many rows in one paint judges them all
/// against one moment, the same reason [MlTime.ago] takes one.
MlPresence mlPresenceOf({
  required bool online,
  DateTime? dbLastSeen,
  DateTime? liveLastSeen,
  DateTime? asOf,
}) {
  if (online) return MlPresence.online;
  final seen = mlLastSeen(dbLastSeen: dbLastSeen, liveLastSeen: liveLastSeen);
  if (seen == null) return MlPresence.offline;
  final age = (asOf?.toUtc() ?? MlTime.instant()).difference(seen.toUtc());
  // A stamp in the future is a clock disagreement, not recent activity. The
  // old rule treated it as recent, which is the whole shape of the bug above.
  if (age.isNegative) return MlPresence.offline;
  return age <= kPresenceAwayWindow ? MlPresence.away : MlPresence.offline;
}
