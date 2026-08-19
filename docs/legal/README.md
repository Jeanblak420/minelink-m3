# Legal documents

The three placeholder documents that used to live here have **moved to
`assets/legal/`** (2026-08-17) so the app can actually open them.

They are declared one by one in `pubspec.yaml` and read from the bundle by
`lib/core/legal/legal_documents.dart`, which the sign-in screen's "Terms of
Use" and "Privacy Policy" links open. Before that move the sentence asserted
agreement to two documents no user could reach.

They were **moved, not copied**. The `unreplaced-legal-placeholder` ratchet in
`tool/release_guards.dart` scans `docs/legal`, `lib` and `assets`, and its
baseline is exactly 3 — a copy would have made it 6 and failed the build, and
raising the baseline would have defeated the guard. The count is still 3, and
it still has to reach 0 before S10.

Each file's own opening paragraph says it has not been reviewed by an attorney.
The in-app viewer renders that paragraph first, in a red-ruled callout, rather
than stripping it.
