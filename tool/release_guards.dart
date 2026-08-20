#!/usr/bin/env dart
// Release guards — the greps that must hold before Mine-Link v1.0 ships.
//
// Checklist gates S1-5 and S1-8. Run from the repo root:
//
//     dart run tool/release_guards.dart
//     dart run tool/release_guards.dart --update-baseline   (after real cleanup)
//     dart run tool/release_guards.dart --selftest          (prove each guard bites)
//
// Exit code 1 on any failure, so this is usable from a pre-commit hook or CI.
//
// ── Why two modes ────────────────────────────────────────────────────────────
// `block` guards must be at zero. `ratchet` guards may not exceed a recorded
// baseline. The design-token guards started at ~1,300 real violations that
// stage S5 existed to clear; making them `block` then would have failed every
// commit until S5 landed, so they ratcheted instead. A guard that is always
// red is a guard everybody learns to ignore.
//
// **Both flipped to `block` on 2026-08-15, when S5-19 reached zero.** The rule
// they now enforce is one sentence: a raw colour literal may appear in
// `lib/core/design/tokens/` and nowhere else in `lib/`. The token layer is
// exempted by path, not by living outside the scanned roots — `lib/core` used
// to be unscanned entirely, which hid 40 real violations and made moving a
// palette into the token layer indistinguishable from hiding it.
//
// ── Why --selftest exists ────────────────────────────────────────────────────
// A grep that matches nothing reports green forever and everyone believes it.
// `--selftest` plants a known violation for each guard in a temp tree and
// asserts the guard finds it. This is the S1-8 requirement that each grep be
// demonstrated failing on a deliberately planted violation.

import 'dart:convert';
import 'dart:io';

enum Mode { block, ratchet }

class Guard {
  final String id;
  final String why;
  final Mode mode;

  /// Files or directories to search, repo-root-relative.
  final List<String> roots;

  /// Restrict directory walks to this extension. Null searches every file.
  final String? extension;
  final RegExp pattern;

  /// A line matching this is not a violation.
  final RegExp? exempt;

  /// A file whose repo-relative path matches this is not scanned at all.
  ///
  /// Added 2026-08-15 (S5-19) for one case: the design-token layer is the one
  /// place raw colour literals are *supposed* to live, and until now the two
  /// colour guards avoided it by only scanning `lib/features`. That left
  /// `lib/core` — 40 real violations in `core/widgets/` and
  /// `core/design/shell/` — unguarded entirely, and it meant moving a palette
  /// table into the token layer looked like satisfying a grep rather than the
  /// architectural statement it is. Scanning all of `lib` with the token layer
  /// exempted makes the rule sayable in one line: **raw colour literals live
  /// in `core/design/tokens/` and nowhere else.**
  final RegExp? exemptPath;

  /// Match [pattern] against the whole file rather than one line at a time,
  /// so a match may span line breaks.
  ///
  /// ## Why this had to be added (2026-08-16)
  ///
  /// `no-hardcoded-brand-stat` matched `MlBrandStat\(\s*value:\s*[0-9]`. The
  /// three literals were then reformatted — by `dart format`, doing its job —
  /// from
  ///
  /// ```dart
  /// MlBrandStat(value: 24, suffix: '+', label: 'Companies',
  ///     icon: Icons.domain_rounded),
  /// ```
  ///
  /// to the same call with `value:` wrapped onto the next line. The scanner
  /// tests one line at a time, `\s*` never crossed the break, and the guard
  /// went from watching three literals to watching **nothing** — while
  /// printing `PASS no-hardcoded-brand-stat: 0`, which reads like the
  /// strongest possible result.
  ///
  /// That is the worst failure mode a guard has: not red when it should be
  /// green, but green while blind. The trigger was a formatter, so it needs no
  /// mistake by anybody to happen again, and it is invisible in review because
  /// the diff is pure whitespace.
  ///
  /// **Any guard whose pattern contains `\s` should set this.** A pattern that
  /// can match a space can meet a newline there one reformat later.
  final bool spanLines;

  /// The violation `--selftest` plants, and the filename it plants it under.
  final String plantFile;
  final String plantLine;

  /// The same violation written across **more than one line**, as the
  /// formatter would leave it. **Required when [spanLines] is set**, and the
  /// selftest fails the guard if it is missing.
  ///
  /// This is the check that did not exist on 2026-08-16, and its absence is
  /// why a blinded guard reported `BITES` for a day: the selftest planted one
  /// line, so it only ever exercised the case that was never broken. A claim
  /// to span lines is worth nothing unless something plants a violation that
  /// actually spans them.
  ///
  /// Hand-written per guard rather than derived by re-wrapping [plantLine],
  /// because where the break has to fall to be meaningful differs by pattern
  /// — after `MlBrandStat(` for one, between `)` and `{` for another — and a
  /// generic re-wrap would happily produce a break the pattern never had to
  /// cross, proving nothing while looking thorough.
  final String? plantWrapped;

  const Guard({
    required this.id,
    required this.why,
    required this.mode,
    required this.roots,
    required this.pattern,
    required this.plantFile,
    required this.plantLine,
    this.extension,
    this.exempt,
    this.exemptPath,
    this.spanLines = false,
    this.plantWrapped,
  });
}

final guards = <Guard>[
  Guard(
    id: 'no-config-asset-dir',
    why: 'pubspec declaring config/ as an asset dir bundles every secret in it '
        'into the web and Windows artifacts (P11-03).',
    mode: Mode.block,
    roots: ['pubspec.yaml'],
    pattern: RegExp(r'^\s*-\s*config/\s*$'),
    plantFile: 'pubspec.yaml',
    plantLine: '    - config/',
  ),
  Guard(
    id: 'no-arcgis-token',
    why: 'an Esri ArcGIS token literal committed anywhere is a live credential '
        '(P0-04).',
    mode: Mode.block,
    roots: ['lib', 'web', 'pubspec.yaml', 'android/app/src', 'windows/runner'],
    pattern: RegExp(r'AAPT[A-Za-z0-9_\-]{20,}'),
    plantFile: 'planted.dart',
    plantLine: "const t = 'AAPTaYIqV1NAgHvtsROlAnWPGzwUOWVN42ZLcCbZ2V1MxH2Gzt';",
  ),
  Guard(
    id: 'no-raw-color-hex',
    why: 'raw Color(0x...) bypasses MlTokens/MlSemantic and breaks light mode '
        '(P6-23). BLOCKING since S5-19 closed on 2026-08-15 — the only place a '
        'colour literal may live is lib/core/design/tokens/, exempted below.',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    exemptPath: RegExp(r'lib/core/design/tokens/'),
    pattern: RegExp(r'Color\(0x'),
    // Comments are prose ABOUT colour, not colour. Without this, writing
    // "was Color(0x5900B5D8)" to explain why the line beneath it changed counts
    // as the very thing the comment is explaining away — which is exactly what
    // happened on 2026-08-14 and pushed this ratchet one over its limit.
    // Every other guard already exempted comments; these two were the outliers.
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'planted.dart',
    plantLine: 'const c = Color(0xFF00B5D8);',
  ),
  Guard(
    id: 'no-material-colors',
    why: 'Colors.* is not theme-aware and is not in the design system (P6-23). '
        'BLOCKING since S5-19 closed on 2026-08-15.',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    exemptPath: RegExp(r'lib/core/design/tokens/'),
    pattern: RegExp(r'\bColors\.'),
    // Comments: same reasoning as no-raw-color-hex above.
    //
    // `Colors.transparent`: exempted 2026-08-15 after counting what this guard
    // was actually measuring. Of 342 hits, **100 — 29.2% — were
    // `Colors.transparent`**, and it is not a design-system violation on any
    // reading. It carries no colour decision, it is identical in both themes
    // by definition, and it is Flutter's idiom for "no fill"
    // (`Material(color: Colors.transparent)`, a zero-width border, an
    // `AnimatedContainer` fading a fill out). The only way to satisfy the guard
    // was to invent `MlTokens.transparent = Color(0x00000000)` — a token
    // expressing no decision, added purely to move a grep. That is the same
    // failure this repo already wrote down about lint rules: a rule you satisfy
    // by mechanical substitution teaches people to substitute mechanically.
    //
    // So S5-19's target is **242, not 342**, and the 100 are not debt.
    exempt: RegExp(r'^\s*(//|///|\*|/\*)|\bColors\.transparent\b'),
    plantFile: 'planted.dart',
    plantLine: 'const c = Colors.red;',
  ),
  Guard(
    id: 'no-coming-soon',
    why: 'a "coming soon" string is a dead end shipped to a paying user '
        '(P0-12).',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    pattern: RegExp('coming soon', caseSensitive: false),
    // Both live hits are comments recording that a dead "coming soon" stub was
    // REMOVED. Deleting the note to satisfy a grep would delete the reason the
    // code looks the way it does, so the guard skips comment lines instead.
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'planted.dart',
    plantLine: "const s = 'Coming Soon';",
  ),
  Guard(
    id: 'no-const-spark-series',
    why: 'a const list handed to a spark: argument is a hardcoded trend — a '
        'chart rendering invented data (P9, S3-12).',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    // Requires at least one non-] character inside the brackets. All five live
    // matches are `spark: const []`, which is an empty series — "no data", the
    // honest state — not an invented one. Matching those would have the guard
    // demand that a chart fabricate something to render.
    pattern: RegExp(r'spark\s*:\s*const\s*\[\s*[^\]\s]'),
    spanLines: true, // `\s*` between `spark:` and `const` can meet a newline.

    // Comments, like every other guard in this file. This one was the last
    // outlier, and it bit on 2026-08-16 the first time somebody wrote the
    // rule down in prose: a comment in `minelink_signin_brand.dart` explaining
    // that a NEW defect had escaped the sweep because "the guards look for
    // MlSampleData and `spark: const [...]`" was itself read as a hardcoded
    // trend. A guard that forbids describing it is one people route around.
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'planted.dart',
    plantLine: 'spark: const [1, 2, 3],',
    plantWrapped: 'spark:\n        const [1, 2, 3],',
  ),
  Guard(
    id: 'no-raw-exception-in-ui',
    why: 'interpolating a caught exception into a user-facing message shows a '
        'customer text like "PostgrestException(message: , code: 400 …)" and, '
        'on a permission failure, discloses that the row exists. Use '
        'friendlyError(e).',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    // Two shapes, because fixing only the first left sixteen screens rendering
    // a bare `PostgrestException(...)` centred on an empty page — no icon, no
    // title, no retry. Worse than the one this guard was written for.
    //
    // ⚠ READ THIS BEFORE TRUSTING A GREEN FROM THIS GUARD. It recognises
    // SHAPES, not the defect. On 2026-08-15, with this guard passing at
    // Mode.block, four real leaks were found by reading:
    //
    //   company_selection_screen.dart:73   Text('… ${e.toString()}')
    //   company_employees_screen.dart      'Error: ${error.toString()}'  (x6)
    //   partner_load_error.dart:50         '…\n\n$error'
    //   employee_profile_screen.dart:293   Text('$e',
    //
    // The last one missed by a SINGLE CHARACTER — the pattern required
    // `Text('$e')` and the call had a trailing comma. That is fixed below by
    // dropping the closing paren.
    //
    // The other three are NOT added, and the reason matters. The obvious
    // widening — matching `${e.toString()}` — was measured against the tree
    // and hits 17 sites, of which the large majority are legitimate: logger
    // calls, `throw Exception('… ${e.toString()}')` rethrows, and
    // `fleet_provider`'s `error:` state fields. A grep cannot tell an
    // exception going to a log from one going to a `Text`. Making this
    // Mode.block guard match them would fail every commit until somebody
    // suppressed it, which is how a guard stops being read.
    //
    // So: this guard raises the floor, it does not prove absence. The real
    // protection is that `friendlyError` never echoes its input — every branch
    // returns a fixed sentence — so a raw exception that reaches it is
    // absorbed. Checked while fixing the above: `fleet_provider` bakes
    // `PostgrestException(...)` into `FleetState.error`, which
    // `FleetManagementScreen` now hands to `MlLoadFailure`; that renders
    // safely only because of this property, not because the state is clean.
    // Not a raw string: the pattern now ENDS in a quote, and `r'''…''''`
    // is four quotes in a row, which Dart cannot parse.
    pattern: RegExp("message:\\s*'\\\$e'|Text\\('\\\$e'"),
    // `message:` and its argument are routinely wrapped apart by the
    // formatter, which would take this branch of the pattern out of service.
    spanLines: true,
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'planted.dart',
    plantLine: "MlEmptyState(title: 'x', message: '\$e');",
    plantWrapped: "MlEmptyState(\n    title: 'x',\n    message:\n        '\$e');",
  ),
  Guard(
    id: 'no-sample-data-in-lib',
    why: 'MlSampleData/MlTargetsSample are widget-test fixtures. In lib/ they '
        'ship inside the app and carry hardcoded spark trends — invented '
        'platform figures rendered as fact (S3-11, S3-12). They live in '
        'test/fixtures/ now.',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    pattern: RegExp(r'\b(MlSampleData|MlTargetsSample)\b'),
    // A comment recording that the defaults were removed (P9-03) is the reason
    // the code looks the way it does, not a violation of the rule.
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'planted.dart',
    plantLine: 'final d = MlSampleData.orgAggregates;',
  ),
  Guard(
    id: 'no-example-app-id',
    why: 'com.example.* is the Flutter template identifier. Play REJECTS it, '
        'and the application id is permanent after first publish (P11-01, '
        'S1-1). EVERY platform is org.minelink now — Android since the client '
        'ruling of 2026-08-13, and iOS / macOS / Linux since S1-1a was closed '
        'on 2026-08-16. Roots widened from `android` alone at that point: the '
        'guard was blocking one platform while the template id sat in ten '
        'places across the other three, which is the same shape as the '
        'brand-stat guard watching one of two copies.',
    mode: Mode.block,
    roots: ['android', 'ios', 'macos', 'linux', 'windows'],
    // Generated build scaffolding that symlinks into third-party plugin
    // sources. Those packages ship their own example apps, which are full of
    // `com.example.*` — none of it reaches this app and none of it is ours to
    // change. 62 hits on the widened roots, every single one under here.
    exemptPath: RegExp(r'(^|[\\/])(ephemeral|\.plugin_symlinks|Pods|build)([\\/]|$)'),
    pattern: RegExp(r'com\.example\b'),
    plantFile: 'build.gradle.kts',
    plantLine: '    applicationId = "com.example.flutter_application_1"',
  ),
  Guard(
    id: 'no-empty-catch',
    why: 'an empty catch swallows the failure silently — the fault class that '
        'hid the presence bug and the POD upload bug (P0-11, S1-7). Log via '
        'LoggerFactory or rethrow.',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    // `catch (e) {}` and `} catch (_) {}` alike — anything whose body is empty.
    // A doc comment quoting the pattern (employee_register_service.dart:26
    // does) is prose about the rule, not a violation of it.
    pattern: RegExp(r'catch\s*\([^)]*\)\s*\{\s*\}'),
    // The most exposed of the lot. An empty catch whose braces sit on separate
    // lines is the commonest way to write one, and the line scanner could
    // never see it — so the guard most relied on to be at zero was the one
    // least able to prove it.
    spanLines: true,
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'planted.dart',
    plantLine: 'try { risky(); } catch (_) {}',
    plantWrapped: 'try {\n  risky();\n} catch (_) {\n}',
  ),
  Guard(
    id: 'no-widgets-in-router',
    why: 'screen classes declared in app_router.dart make the router '
        'un-navigable and un-testable (P4-01…P4-07, S7-1).',
    mode: Mode.block,
    roots: ['lib/core/routing/app_router.dart'],
    pattern: RegExp(
      r'^\s*class\s+\w+\s+extends\s+'
      r'(StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget)',
      // `multiLine` so `^` keeps meaning line-start once the scan spans the
      // whole file. Without it `^` would anchor to the start of the file and
      // this would match at most once, in the first line.
      multiLine: true,
    ),
    // `class Foo\n    extends ConsumerWidget` is exactly what the formatter
    // produces for a long class name — the shape this guard exists to catch.
    spanLines: true,
    plantFile: 'app_router.dart',
    plantLine: 'class PlantedScreen extends StatelessWidget {}',
    plantWrapped:
        'class PlantedScreenWithAVeryLongName\n    extends StatelessWidget {}',
  ),
  Guard(
    id: 'no-demo-data-banner',
    why: 'the "Demo Data Active — showing example content" banner told real '
        'customers their live screens were examples. It fired whenever '
        '`showcase_data` was non-empty — i.e. always — while no widget has '
        'ever rendered `ShowcaseItem.data`, so it labelled real data as demo. '
        'Removed 2026-08-12 by client ruling P10-D8, which kept the 14 rows '
        'and deleted the banner. This stops it coming back (S3-10).',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    pattern: RegExp(r'''['"]Demo Data Active'''),
    // The removal is recorded in two comments; a comment naming the string is
    // history, not a reintroduction.
    exempt: RegExp(r'^\s*(//|///|\*)'),
    plantFile: 'planted.dart',
    plantLine: "const banner = 'Demo Data Active — showing example content';",
  ),
  Guard(
    id: 'unreplaced-legal-placeholder',
    why: 'a legal document still carrying the PLACEHOLDER banner has not been '
        'reviewed by an attorney and must not ship. Placeholder legal text '
        'that reaches a customer is worse than none: the current sign-in '
        'screen already asserts "you agree to the Terms of Use and Privacy '
        'Policy", and pointing that sentence at invented text turns a missing '
        'document into a false representation (S9-9).',
    // RATCHET, not block, and deliberately so — the same reasoning the S5
    // design guards are set up under. These three files are expected to carry
    // the banner until the client's attorney replaces them, and a guard that
    // is red on every commit is one everybody learns to ignore. The ratchet
    // still catches a FOURTH placeholder appearing, or one being copied into
    // lib/. **S10 requires this to read 0** — that is where it becomes a
    // blocker, and where it should be flipped to Mode.block.
    mode: Mode.ratchet,
    roots: ['docs/legal', 'lib', 'assets'],
    pattern: RegExp(r'PLACEHOLDER — NOT A LEGAL DOCUMENT'),
    plantFile: 'planted.md',
    plantLine: '# PLACEHOLDER — NOT A LEGAL DOCUMENT. DO NOT PUBLISH.',
  ),
  Guard(
    id: 'no-hardcoded-brand-stat',
    why: 'the sign-in screen shipped "24+ Companies · 480 Trucks live · '
        '1.2M t Hauled" as three hardcoded `MlBrandStat` literals. Measured '
        'against production 2026-08-16: 26 companies, 7 vehicles, 1,227.9 t — '
        'the fleet overstated 68x and the tonnage by a factor of a thousand, '
        'in large type on the first screen a customer sees. S3-11/S3-12 exist '
        'to stop invented figures rendering as fact and did not catch this, '
        'because they look for MlSampleData and const spark series and this '
        'is neither.',
    // RATCHET at the three the client decided to keep (2026-08-16), not block.
    //
    // This guard was Mode.block for one day, with the strip emptied. The
    // client was shown the gap between the figures and production and chose
    // to keep them for now — a marketing panel on a pre-launch product, with
    // real ones wanted "when we have more companies registered with us"
    // (docs/future-work.md item 1). Blocking would mean the build fails on
    // their own decision, and the way that gets resolved is by deleting the
    // guard.
    //
    // Ratcheted, it still does the job it was written for: a FOURTH invented
    // figure fails, and so does one appearing anywhere other than the sign-in
    // panel. **When the client wires real figures this must go back to
    // Mode.block with the baseline removed** — a real stat is built from a
    // variable and will not match this pattern.
    mode: Mode.ratchet,
    roots: ['lib'],
    extension: '.dart',
    // Any MlBrandStat built with a literal value. A real one will be built
    // from a variable, so this does not stand in the way of wiring them up.
    pattern: RegExp(r'MlBrandStat\(\s*value:\s*[0-9]'),
    // See `Guard.spanLines`: this exact pattern is the one that went blind
    // when `dart format` wrapped `value:` onto its own line.
    spanLines: true,
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'planted.dart',
    plantLine: 'MlBrandStat(value: 480, label: "Trucks live"),',
    // The exact shape that blinded this guard on 2026-08-16 — `dart format`
    // wrapping `value:` onto the next line.
    plantWrapped: 'MlBrandStat(\n    value: 480, label: "Trucks live"),',
  ),
  Guard(
    id: 'committed-db-connection-string',
    why: 'a Postgres connection string with the password inline is the '
        'database superuser, not an app credential: it bypasses RLS entirely. '
        'Found 2026-08-15 in FIVE tracked files at the repo root, for project '
        '`kkcseqmpgzzrogatdoqi` — including a file called `SBasEp` whose '
        'name gives no hint of what it holds. **Only rotation fixes it**; '
        'deleting the files leaves them in git history. This guard exists to '
        'stop it SPREADING while the owner rotates.',
    // RATCHET at the five that exist, so the tree is not red on every commit
    // while the rotation is somebody else's to do. A SIXTH occurrence fails.
    mode: Mode.ratchet,
    roots: [
      'lib', 'scripts', 'supabase', 'test', 'web', 'android', 'windows',
      // The five known copies live here since S10-7. Scanned so the ratchet
      // counts them and cannot silently gain a sixth, and so that moving one
      // back out to the root shows up as a change rather than as nothing.
      'legacy',
    ],
    // `supabase/.temp/pooler-url` holds the SAME shape with the literal
    // placeholder `[YOUR-PASSWORD]` — the CLI writes it. A placeholder is the
    // correct form of this string, so it is exempted by name rather than by
    // narrowing the pattern, which would have taught the pattern to miss a
    // real password that happened to contain a bracket.
    // Deliberately a SHAPE, not the literal. Writing the password into this
    // file to grep for it would add a sixth copy of it — the same reasoning
    // `committed-test-credential` records for excluding `tool/` from its own
    // roots, taken one step further. This matches any Supabase pooler or
    // direct connection string carrying an inline password, including ones
    // nobody has written yet.
    pattern: RegExp(r'postgres(ql)?://postgres[.:][^\s@]*:[^\s@/]+@'),
    exempt: RegExp(r'^\s*(//|///|\*|/\*|--|#)|\[YOUR-PASSWORD\]|<password>'),
    plantFile: 'planted.md',
    plantLine: 'postgresql://postgres.abcdefghijklmnopqrst:hunter2@aws-0-eu-central-1.pooler.supabase.com:6543/postgres',
  ),
  Guard(
    id: 'committed-test-credential',
    why: 'the shared live test password is committed in plaintext. Measured '
        '2026-08-15 (S9-8): it opens 26 confirmed accounts on the production '
        'project — 13 of them on Iron Hills Mining / Atlas Buyer Group / '
        'Roadhaul Logistics, which are status=active with tokens valid to '
        '2027 and hold all 41 trips. Every org type and role is covered; none '
        'is a platform admin. Rotating it is the only real fix, because '
        'deleting the files does not remove them from git history — this '
        'guard exists to stop it SPREADING while the client decides.',
    // RATCHET. Two of the sources are working references somebody still uses:
    // supabase/seed.sql (13) creates the demo accounts, and
    // assets/work_flow_test_accounts.md (1) is the sheet the workflow walk is
    // driven from. Editing either changes behaviour or usability, so both are
    // an ASK, not a unilateral fix. The 37 occurrences in output/ were pure
    // test scratch and are gone; the 2 hardcoded defaults in scripts/ now
    // require LIVE_VALIDATION_PASSWORD from the environment.
    //
    // Roots deliberately exclude tool/ (this file states the literal, and a
    // guard that flags itself is noise) and docs/ (the design-upload tree
    // under `docs/new system design/` mirrors the whole repo, so counting it
    // would bury a real new occurrence under six stale copies).
    //
    // **S10 requires this to read 0**, at which point it flips to Mode.block.
    mode: Mode.ratchet,
    roots: ['lib', 'assets', 'scripts', 'supabase', 'test', 'web'],
    pattern: RegExp(r'MineralGuide123!'),
    plantFile: 'planted.md',
    plantLine: 'Common Password for All Accounts: MineralGuide123!',
  ),
  Guard(
    id: 'no-bitwise-in-polyline-codec',
    why: 'a bitwise operator in the polyline codec breaks navigation on the '
        'web and nowhere else. Dart bitwise ops are UNSIGNED 32-BIT on the '
        'web: `~5` is -6 on the VM and 4294967290 under dart2js, so the '
        'zig-zag step every polyline decoder is written with turned a real '
        '10.0 km Valhalla route into a 599 295.4 km one in a browser '
        '(measured 2026-08-16). In the running app that meant no route line, '
        'a dead ETA/distance HUD, "In 2194.2 km" on a 10 km trip, and '
        '`trip_nav_state.route_polyline` published to every watcher as 13 '
        'characters of junk. NO TEST CAUGHT IT: `flutter test` runs on the '
        'VM, where the code is correct. That is why this is a source guard '
        'and not a unit test — the defect is invisible to the runtime the '
        'suite uses. The codec is arithmetic-only (+ * % ~/), which is exact '
        'and identical on both runtimes below 2^53.',
    mode: Mode.block,
    roots: ['lib/features/portal/models/nav_route.dart'],
    extension: '.dart',
    // `~/` is integer division, not bitwise, and is safe. `<<`/`>>` are the
    // other two that silently truncate to 32 bits on the web.
    pattern: RegExp(r'~(?!/)|<<|>>'),
    // Prose describing the trap has to be allowed to name the operators, or
    // the comment explaining the guard trips the guard.
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'nav_route.dart',
    plantLine: 'final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);',
  ),
  Guard(
    id: 'no-half-point-font-size',
    why: 'a half-point font size belongs to neither scale this app has — not '
        'MlTokens.fs* (34/26/22/18/16/15/13/12/11) and not the M3 TextTheme '
        '(45/36/32/28/24/22/16/14/12/11). It is somebody nudging a number '
        'until one string fitted one box on one day. Measured 2026-08-20: '
        '1,015 hand-written fontSize literals across THIRTY-SEVEN distinct '
        'values, TEN of them half-points (7.5 8.5 9.5 10.5 11.5 12.5 13.5 '
        '14.5 15.5 16.5) over ~380 sites. All rounded up — up rather than '
        'nearest, because shrinking text is the direction that makes '
        'something unreadable without making it look broken, while growing it '
        'can only cause an overflow, which the sweeps catch. The token layer '
        'is exempt: it is where the scale is defined.',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    exemptPath: RegExp(r'lib/core/design/tokens/'),
    pattern: RegExp(r'fontSize:\s*[0-9]+\.[0-9]'),
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'planted.dart',
    plantLine: 'style: TextStyle(fontSize: 12.5),',
  ),
  Guard(
    id: 'text-scale-sweep-reaches-the-ceiling',
    why: 'a sweep that stops below the scale the shells actually install '
        'leaves real sizes unrendered while reporting that a screen "survives '
        'every width x text scale". Since 2026-08-17 the shells COMPOSE the '
        "in-app slider with the platform's own scaler and cap the product at "
        'kMaxEffectiveTextScale = 2.0, so everything between 1.3 and 2.0 is a '
        'size a real user can be sitting at. FOURTEEN sweep sites across '
        'ELEVEN files stopped at 1.3. Raising them all found seven real '
        'overflows — an employee-register KPI chip, three targets rows, a '
        'targets tab bar, a closed-cycle header and the target dial, none of '
        'which reproduced at or below 1.3. Include 2.0, or the claim in the '
        "test's own name is false.",
    mode: Mode.block,
    roots: ['test'],
    extension: '.dart',
    pattern: RegExp(r'(?:final scale in|_scales\s*=)\s*<double>\[(?![^\]]*2\.0)'),
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'some_sweep_test.dart',
    plantLine: 'const _scales = <double>[0.85, 1.0, 1.3];',
  ),
  Guard(
    id: 'no-off-scale-corner-radius',
    why: 'a corner radius written as a number is a guess at the shape scale. '
        'Measured across lib/ on 2026-08-20: 320 sites carrying TWENTY-FOUR '
        'distinct values — 1, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, '
        '14, 15, 16, 18, 20, 24, 26, 28, 30 and 999. That is not a design '
        'system, it is 320 independent guesses at one, and it is the single '
        'most visible reason two MineLink screens do not look like the same '
        'product. `MlShape` names the seven M3 steps; use them. The token '
        'layer is exempt because it is the layer that DEFINES the scale, and '
        'a definition written in terms of itself is circular — the same '
        'exemption, for the same reason, as the two colour guards.',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    exemptPath: RegExp(r'lib/core/design/tokens/'),
    pattern: RegExp(r'Radius\.circular\(\s*[0-9]'),
    // Prose about the rule has to be able to quote what the rule forbids.
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'planted.dart',
    plantLine: 'borderRadius: BorderRadius.circular(11),',
  ),
  Guard(
    id: 'test-renders-under-the-app-theme',
    why: 'a bare `MaterialApp` in a test renders in stock Material\'s type '
        'scale and stock Material\'s font family — a measurement of text the '
        'app will never draw. That was survivable while every component '
        'hard-coded its own TextStyle; it stopped being survivable the moment '
        'they started taking type from the theme, which is the whole point of '
        'one design system. TWENTY test files hosted this way, including the '
        'console and portal layout sweeps, and it is why widening those sweeps '
        'to phone widths surfaced anything at all: they had been measuring the '
        'wrong metrics the whole time. Same family as the fallback-font trap '
        'in CLAUDE.md §10.5 — green about a rendering nobody sees. Pass '
        '`theme: AppTheme.darkTheme` (or lightTheme, or AppTheme.build).',
    mode: Mode.block,
    roots: ['test'],
    extension: '.dart',
    // `MaterialApp(` with no `theme:` before the next `MaterialApp(`.
    //
    // Three iterations to get right, and each failure is worth naming:
    //
    //  * "theme must be the NEXT token" — four false positives. `theme:` is
    //    rarely the first named argument; `navigatorKey`,
    //    `debugShowCheckedModeBanner` and a `builder` all commonly precede it.
    //  * "theme within 400 characters" — one more false positive, on the file
    //    that explains IN A COMMENT why it uses the real theme. The comment
    //    ate the window.
    //  * A plain wide window would then be satisfied by the NEXT
    //    MaterialApp's theme, turning a false positive into a false negative
    //    — the worse of the two, and the failure mode this file's own header
    //    calls "green while blind".
    //
    // So: a generous window, bounded by the next constructor.
    //
    // spanLines because the formatter decides where the break falls.
    spanLines: true,
    pattern: RegExp(r'MaterialApp\((?!(?:(?!MaterialApp\()[\s\S]){0,900}?theme\s*:)'),
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'some_test.dart',
    plantLine: 'await tester.pumpWidget(MaterialApp(home: SizedBox()));',
    plantWrapped: 'await tester.pumpWidget(MaterialApp(\n  home: SizedBox()));',
  ),
  Guard(
    id: 'no-row-around-a-header-that-has-an-actions-slot',
    why: 'wrapping MlPageHeader or MlSectionTitle in a Row to put a button '
        'beside it hands that button UNBOUNDED width (CLAUDE.md §10.4), and a '
        'button cannot ellipsize its way out — clamping one truncates its hit '
        'target, not merely its label. Both components already have a slot '
        'for exactly this (`actions:` / `action:`) which lays the title and '
        'the actions out as siblings in one Wrap, so an action drops UNDER '
        'the title when the row runs out of width. Seven call sites did it by '
        'hand anyway. Two overflowed on a phone before this guard existed — '
        'mine production by 25px at 360px x text scale 2.0, where the button '
        'squeezed the Expanded title down to less than its own 22px icon — '
        'and the other five were latent. Pass the button to the slot.',
    mode: Mode.block,
    roots: ['lib/features'],
    extension: '.dart',
    // `Expanded(child: MlPageHeader` / `child: MlSectionTitle`, and the
    // Column-wrapped variant four of the screens used. spanLines, because the
    // formatter decides where these break and has already blinded one guard
    // here by moving a token onto the next line.
    spanLines: true,
    pattern: RegExp(r'Expanded\(\s*child:\s*(Column\([^)]*children:\s*\[\s*)?'
        r'Ml(PageHeader|SectionTitle)\('),
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'some_screen.dart',
    plantLine: 'Expanded(child: MlPageHeader(title: 1)),',
    plantWrapped: 'Expanded(\n      child: MlPageHeader(title: 1)),',
  ),
  Guard(
    id: 'no-hardcoded-month-in-ui',
    why: 'a month name and a year written into a UI string is a date that '
        'stopped moving. Found 2026-08-20 in TWO places on screens people '
        'read daily. The console dashboard headed its "Live operations … this '
        'calendar month" section with the literal `This month · Jul 2026` — '
        'written in July, still saying July in August, on the platform '
        "admin's landing screen. `MlFlagshipTrend` defaulted `priorLabel` to "
        "`'Jul 2026'` and `monthLabel` to `'Aug'`, and NOT ONE of its three "
        'call sites passes `monthLabel` — so the crosshair tooltip on the '
        'buyer, mine and transporter dashboards labelled every point AUG NN '
        'whatever the date. That one reads correctly for one month a year, '
        'which is exactly why it survived: it was written in August and '
        'looked right. Dates come from the clock — MlTime, in South African '
        'time (CLAUDE.md §7.1) — never from a literal. Test fixtures pin '
        'dates on purpose and are not scanned.',
    mode: Mode.block,
    roots: ['lib'],
    extension: '.dart',
    // A month abbreviation or full name followed by a four-digit year, or a
    // bare quoted month abbreviation used as a default value. Both shapes were
    // live.
    pattern: RegExp(
      r"'[^']*\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+20\d\d\b"
      r"|=\s*'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)',",
    ),
    // Prose explaining the trap has to be able to quote the literals it is
    // about, or the doc comment recording this fix trips the guard that the
    // fix installed. Same exemption, and same reason, as the polyline codec's.
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'minelink_charts.dart',
    plantLine: "    this.priorLabel = 'Jul 2026',",
  ),
  Guard(
    id: 'mockito-not-in-dependencies',
    why: 'mockito in `dependencies` ships a mocking library inside the '
        'consumer binary. It is tree-shaken only by luck, and it is a '
        'supply-chain surface in a released app. It belongs in '
        '`dev_dependencies` (R-4).',
    mode: Mode.block,
    roots: ['pubspec.yaml'],
    // A plain `^  mockito:` line-anchor would match a `dev_dependencies:`
    // entry at the same two-space indent too, so the pattern is anchored to
    // the `dependencies:` block itself instead: start at `dependencies:`,
    // consume anything EXCEPT a line that starts `dev_dependencies:` (the
    // negative lookahead blocks the scan from crossing that boundary at
    // all, so it can never accidentally match a `mockito:` that lives past
    // it, no matter how many other deps sit in between), then require
    // `  mockito:`. Ruling 2026-08-19: keep `mockito: ^5.4.4` as a plain
    // top-level dev_dependencies entry (a `version:` sub-key is not
    // idiomatic pub syntax and risks failing `flutter pub get`) and narrow
    // the guard instead of contorting the pubspec.
    pattern: RegExp(
      r'^dependencies:(?:(?!^dev_dependencies:)[\s\S])*?^  mockito:',
      multiLine: true,
    ),
    spanLines: true,
    plantFile: 'pubspec.yaml',
    plantLine: 'dependencies:\n  mockito: ^5.4.4',
    // Proves the span is real, not just "adjacent line": several other deps
    // sit between `dependencies:` and `mockito:`, the way a real pubspec
    // reads, and the lazy `[\s\S]*?` still has to cross all of them.
    plantWrapped: 'dependencies:\n  flutter:\n    sdk: flutter\n'
        '  http: ^1.2.2\n  uuid: ^4.5.1\n  mockito: ^5.4.4',
  ),
  Guard(
    id: 'no-prerelease-sdk-constraint',
    why: 'An sdk constraint carrying a prerelease marker (-beta, -dev) means '
        'the app is built against a non-stable Dart. Shipping a consumer '
        'release off the beta channel is a real risk (R-4).',
    mode: Mode.block,
    roots: ['pubspec.yaml'],
    pattern: RegExp(r'^\s*sdk:\s*\^?[0-9.]+-'),
    plantFile: 'pubspec.yaml',
    plantLine: '  sdk: ^3.8.0-278.1.beta',
  ),
  Guard(
    id: 'shell-composes-the-platform-text-scale',
    why: 'a shell that installs `TextScaler.linear(...)` REPLACES the '
        'platform text scaler instead of composing with it, and silently '
        'discards the operating system accessibility setting for every user '
        'of every screen behind that shell. Recorded in docs/future-work.md '
        'as "an admin who runs their OS at 200% gets 130%", which understated '
        'it: the in-app slider ships at 1.0, so anyone who had never opened '
        'it got exactly 100% no matter what they had set at the OS level. '
        'Both shells now go through `mlTextScaler`, which multiplies the two '
        'and caps the PRODUCT at kMaxEffectiveTextScale — capping the '
        'preference alone is what caused this. A unit test cannot hold the '
        'line here because it would pass against either shell; what has to be '
        'guarded is which scaler the shell installs.',
    mode: Mode.block,
    roots: [
      'lib/features/super_admin/widgets/super_admin_shell_layout.dart',
      'lib/features/portal/widgets/portal_shell_layout.dart',
    ],
    extension: '.dart',
    pattern: RegExp(r'TextScaler\.linear'),
    // The comments above each call site explain the trap by naming it.
    exempt: RegExp(r'^\s*(//|///|\*|/\*)'),
    plantFile: 'portal_shell_layout.dart',
    plantLine: 'textScaler: TextScaler.linear(uiPrefs.textScale),',
  ),
];

class Hit {
  final String file;
  final int line;
  final String text;
  Hit(this.file, this.line, this.text);
  @override
  String toString() => '$file:$line: ${text.trim()}';
}

List<Hit> scan(Guard g, {List<String>? rootsOverride}) {
  final hits = <Hit>[];
  for (final root in rootsOverride ?? g.roots) {
    final type = FileSystemEntity.typeSync(root);
    final files = <File>[];
    if (type == FileSystemEntityType.file) {
      files.add(File(root));
    } else if (type == FileSystemEntityType.directory) {
      files.addAll(
        Directory(root).listSync(recursive: true).whereType<File>().where(
              (f) => g.extension == null || f.path.endsWith(g.extension!),
            ),
      );
    }
    for (final f in files) {
      String content;
      try {
        content = f.readAsStringSync();
      } on FileSystemException {
        continue; // unreadable / binary — not a violation
      }
      final norm = f.path.replaceAll(r'\', '/');
      if (g.exemptPath?.hasMatch(norm) ?? false) continue;
      final lines = content.split('\n');

      if (g.spanLines) {
        // Match against the whole file, then attribute each match to the line
        // it STARTS on — that is the line a reader is sent to, and the line
        // `exempt` is judged against, so a commented-out example stays exempt
        // however it wraps.
        for (final m in g.pattern.allMatches(content)) {
          final lineIndex = '\n'.allMatches(content.substring(0, m.start)).length;
          final line = lines[lineIndex];
          if (g.exempt?.hasMatch(line) ?? false) continue;
          hits.add(Hit(norm, lineIndex + 1, line));
        }
        continue;
      }

      for (var i = 0; i < lines.length; i++) {
        if (!g.pattern.hasMatch(lines[i])) continue;
        if (g.exempt?.hasMatch(lines[i]) ?? false) continue;
        hits.add(Hit(norm, i + 1, lines[i]));
      }
    }
  }
  return hits;
}

Map<String, int> loadBaseline() {
  final f = File('tool/release_guards_baseline.json');
  if (!f.existsSync()) return {};
  return (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as int));
}

void main(List<String> args) {
  if (args.contains('--selftest')) exit(selftest());

  final baseline = loadBaseline();
  final counts = <String, int>{};
  var failed = false;

  for (final g in guards) {
    final hits = scan(g);
    counts[g.id] = hits.length;
    final limit = g.mode == Mode.block ? 0 : (baseline[g.id] ?? 0);

    if (hits.length > limit) {
      failed = true;
      stderr.writeln('FAIL  ${g.id}: ${hits.length} violation(s), limit $limit');
      stderr.writeln('      ${g.why}');
      for (final h in hits.take(8)) {
        stderr.writeln('      $h');
      }
      if (hits.length > 8) stderr.writeln('      … ${hits.length - 8} more');
    } else if (g.mode == Mode.ratchet && hits.length < limit) {
      stdout.writeln('PASS  ${g.id}: ${hits.length} (baseline $limit — '
          'ratchet down with --update-baseline)');
    } else {
      stdout.writeln('PASS  ${g.id}: ${hits.length}');
    }
  }

  if (args.contains('--update-baseline')) {
    final next = <String, int>{
      for (final g in guards)
        if (g.mode == Mode.ratchet) g.id: counts[g.id]!,
    };
    File('tool/release_guards_baseline.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(next)}\n',
    );
    stdout.writeln('\nbaseline written: $next');
    exit(0);
  }

  exit(failed ? 1 : 0);
}

/// Plants each guard's violation in a temp tree and asserts the guard finds it.
///
/// Deliberately *not* planted into the real working tree: more than one agent
/// session writes this repo, and a stray planted violation swept into somebody
/// else's commit is exactly the accident this file exists to catch.
int selftest() {
  final tmp = Directory.systemTemp.createTempSync('mlguards');
  var allBit = true;
  try {
    for (final g in guards) {
      final dir = Directory('${tmp.path}/${g.id}')..createSync(recursive: true);
      final clean = File('${dir.path}/${g.plantFile}')..writeAsStringSync('// nothing here\n');
      final beforeHits = scan(g, rootsOverride: [dir.path]);

      clean.writeAsStringSync('// planted below\n${g.plantLine}\n');
      final afterHits = scan(g, rootsOverride: [dir.path]);

      if (beforeHits.isEmpty && afterHits.isNotEmpty) {
        stdout.writeln('SELFTEST  ${g.id}: BITES '
            '(clean ${beforeHits.length} → planted ${afterHits.length})');
      } else {
        allBit = false;
        stderr.writeln('SELFTEST  ${g.id}: DID NOT BITE '
            '(clean ${beforeHits.length} → planted ${afterHits.length})');
        stderr.writeln('          planted: ${g.plantLine}');
      }

      // ── The wrapped plant ──────────────────────────────────────────────
      //
      // The plant above is one line, which is the case that was never broken.
      // On 2026-08-16 `no-hardcoded-brand-stat` was reformatted so its
      // `value:` moved to the next line; the guard stopped matching anything
      // and reported `PASS … : 0`, and **this selftest went on saying BITES**
      // the whole time — because it only ever planted one line.
      //
      // So a guard that claims to span lines must prove it on a violation
      // that actually does. `_wrapAtFirstSpace` reflows the plant the way the
      // formatter would; if the guard still finds it, `spanLines` is real.
      if (g.spanLines) {
        final wrapped = g.plantWrapped;
        if (wrapped == null) {
          allBit = false;
          stderr.writeln('SELFTEST  ${g.id}: declares spanLines but has no '
              'plantWrapped — the span is unproven');
        } else {
          clean.writeAsStringSync('// planted below\n$wrapped\n');
          final wrappedHits = scan(g, rootsOverride: [dir.path]);
          if (wrappedHits.isNotEmpty) {
            stdout.writeln('          + WRAPPED plant also caught');
          } else {
            allBit = false;
            stderr.writeln('SELFTEST  ${g.id}: DID NOT BITE ON A WRAPPED '
                'VIOLATION — spanLines is not doing what it claims');
            stderr.writeln('          planted:\n$wrapped');
          }
        }
      }
    }
  } finally {
    tmp.deleteSync(recursive: true);
  }
  stdout.writeln(allBit ? '\nall guards bite' : '\nSOME GUARDS DO NOT BITE');
  return allBit ? 0 : 1;
}
