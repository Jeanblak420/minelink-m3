# Push notifications — what Jean must supply

Push is **code-complete and inert**. There is no Firebase project yet, so
`PushService.initialise()` (`lib/core/push/push_service.dart`) lands in an
unavailable state on every machine and in CI, and the app behaves exactly as
it did before push existed — the same degrade-not-throw contract
`PlaceIndexConfig` already has for the extras project (CLAUDE.md §1, §6).

Nothing below is optional if push is to actually deliver to a handset. Do
these **in order** — several depend on the one before it.

## The six artifacts

| # | artifact | from | goes |
|---|---|---|---|
| 1 | `google-services.json` | Firebase console → Project settings → your Android app | `android/app/` (gitignored — see below) |
| 2 | `GoogleService-Info.plist` | Firebase console → Project settings → your iOS app | `ios/Runner/` (gitignored — see below) |
| 3 | APNs auth key `.p8` | Apple Developer → Certificates, IDs & Profiles → Keys | uploaded **into Firebase** (Project settings → Cloud Messaging → Apple app configuration), **not into this repo** |
| 4 | `FCM_SERVICE_ACCOUNT` | Firebase console → Project settings → Service accounts → **Generate new private key** (downloads a JSON file) | `supabase secrets set FCM_SERVICE_ACCOUNT='<paste the whole JSON file>'` |
| 5 | `FCM_VAPID_KEY` | Firebase console → Project settings → Cloud Messaging → Web Push certificates → **Generate key pair** | passed at build time via `--dart-define=FCM_VAPID_KEY=...`, **web only** |
| 6 | the service-role key the *database trigger* uses | Supabase dashboard → Project settings → API → `service_role` secret (the same key already used everywhere else in this project — do not create a new one) | see "Artifact 6" below — this one is **not** a Firebase artifact and is easy to miss |

Artifacts 1–2 are gitignored on purpose:

```gitignore
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

**Do not commit a placeholder for either file "to make the build pass."** A
fake `google-services.json` does not degrade — it breaks the Gradle
`google-services` plugin with a parse/validation error that reads like a
build bug, not like a missing-feature message. Worse, a file shaped like a
credential is exactly the class of thing that once shipped a real ArcGIS
token from this repo (see the `config/` comment in `pubspec.yaml`). The
Gradle side is written to build cleanly with the file simply absent:

```kotlin
// android/app/build.gradle.kts
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
```

Web push (artifact 5) degrades independently and separately from the rest:
`FCM_VAPID_KEY` absent just means web clients never call
`FirebaseMessaging.instance.getToken(vapidKey: ...)`, while Android/iOS still
work once artifacts 1–4 and 6 are in place.

### Artifact 6 — the piece that is easy to forget, because it is not a Firebase artifact

`public.notifications_push_fanout()` (migration `20260819090000`) is the
`AFTER INSERT` trigger on `public.notifications` that POSTs to the
`push-fanout` edge function. It needs a bearer token to call that function
with, and it resolves one in this order:

1. Supabase Vault secret named `push_fanout_service_role_key`
   (`select vault.create_secret('<key>', 'push_fanout_service_role_key');`), or
2. the database setting `app.settings.service_role_key`
   (`alter database postgres set app.settings.service_role_key = '<key>';`).

**Both are currently unset on production** — measured directly, not assumed.
Until one is set, the trigger returns immediately after the notification
insert, without posting anything. That is silent and *by design*: a database
trigger that raised or warned on every single notification insert while this
is normally unset would be noise nobody could tell apart from a real fault
(see the migration's own header comment for the full reasoning).

The value stored **must be exactly** the project's `service_role` key — the
same one `push-fanout` itself checks incoming requests against
(`SUPABASE_SERVICE_ROLE_KEY`, set automatically for every edge function by
Supabase, not something you configure separately).

🚨 **The stored secret must have no leading or trailing whitespace.** The
trigger trims it before use (`btrim`, fixed in `20260819150000`), but a
pasted secret with a trailing newline is still the single most likely way
this setup step goes wrong — and the symptom is **nothing happening at all**,
with nothing in any log pointing at whitespace as the cause. Whichever of the
two commands above you run, paste the key with no surrounding blank line and
verify there's no trailing newline in your terminal history before you run
it.

## Order of operations

1. Create the Firebase project (if it does not exist yet) and add an Android
   app (package `org.minelink` — see `android/app/build.gradle.kts`'s
   `namespace`, not the Dart package `flutter_application_1`) and an iOS app
   (bundle id from `ios/Runner.xcodeproj`).
2. Download artifacts 1–2, drop them in place (paths in the table above).
3. Generate the APNs key (artifact 3) in the Apple Developer portal and
   upload it into Firebase's Cloud Messaging → Apple app configuration —
   Firebase will not send anything to an iOS device without this, even with
   artifact 2 in place.
4. Generate artifact 4 (the FCM service account JSON) and run
   `supabase secrets set FCM_SERVICE_ACCOUNT='<the whole JSON>'`. Until this
   is set, `push-fanout` returns `HTTP 200 {"ok":true,"skipped":"no FCM
   credentials"}` for every call — itself a useful signal that everything
   *up to* FCM is wired correctly, see "How to verify" below.
5. Set artifact 6 (the trigger's own key) — see above. This is independent
   of step 4 and both must be done; step 4 without step 6 means the trigger
   never even calls `push-fanout`, and step 6 without step 4 means it calls
   `push-fanout` and gets the "no FCM credentials" response.
6. If web push matters for this release, generate artifact 5 and add
   `--dart-define=FCM_VAPID_KEY=...` to the web build command.
7. Rebuild the app with `google-services.json` / `GoogleService-Info.plist`
   present — `PushService.initialise()` will now actually initialise Firebase
   instead of landing in the unavailable state, and `isAvailable` becomes
   `true` at runtime.

## How to verify it worked, end to end

Each step below should be checkable independently, so a failure narrows down
to one of the six artifacts rather than "push doesn't work."

1. **Register a device.** Sign in on a real build that has artifacts 1–2 (or
   1 alone, for an Android-only check). `PushService.registerCurrentDevice()`
   runs automatically on sign-in (wired in `lib/main.dart`); confirm a row
   landed:
   ```sql
   select id, user_id, platform, app_version, created_at, disabled_at
   from public.device_tokens
   where user_id = '<your user id>'
   order by created_at desc limit 1;
   ```
2. **Insert a test notification** for that same user — either through the
   app's own notification-producing flow, or directly:
   ```sql
   insert into public.notifications (user_id, title, message, type)
   values ('<your user id>', 'Push test', 'If this rings, it works.', 'system')
   returning id;
   ```
3. **Check `net._http_response`** for the POST the trigger fired to
   `push-fanout`:
   ```sql
   select id, status_code, content, created
   from net._http_response
   order by created desc limit 5;
   ```
   - No row at all → artifact 6 is not set (the trigger returned before
     calling `pg_net` at all — re-check for trailing whitespace first).
   - `status_code = 401` → the stored key in artifact 6 does not match the
     project's real `service_role` key.
   - `status_code = 200` and the body is
     `{"ok":true,"skipped":"no FCM credentials"}` → artifact 6 is correct but
     artifact 4 (`FCM_SERVICE_ACCOUNT`) is not set yet.
   - `status_code = 200` and the body has no `"skipped"` key → the function
     attempted a real FCM send; check its own logs
     (`mcp__supabase__query_logs` / `get_edge_function` on `push-fanout`, or
     the Supabase dashboard) for per-token results if the handset still
     didn't ring.
4. **Confirm the handset rings.** This is the one step nothing in Postgres
   can prove — a `200` from FCM means Google accepted the send, not that the
   device displayed it (a stale/uninstalled-app token still gets accepted
   and then silently fails downstream). Physically check the device.

`verify_jwt` is deliberately **`false`** on the `push-fanout` function — it
does its own authentication instead, comparing the incoming `Authorization`
header against `SUPABASE_SERVICE_ROLE_KEY` with `timingSafeEqualStrings()`
(`supabase/functions/push-fanout/index.ts`) before any database or FCM work
runs, rather than expecting a normal user JWT. That is correct and not a gap
to "fix" — the caller is a database trigger carrying a service-role key,
never an end-user session.

## What is proven today, and what is not

- **Proven:** the Dart service degrades correctly with no Firebase project
  (`test/core/push_service_test.dart`), the DB schema/RPCs/trigger exist and
  were exercised live, and `flutter build web --release` succeeds with no
  Firebase config present.
- **Not proven, and not provable without the artifacts above:** an actual FCM
  delivery to a handset. There is no Firebase project to test against yet.
