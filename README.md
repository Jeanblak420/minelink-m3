# MineLink M3

A **Material Design 3 redesign of MineLink**, built as a standalone project so
the new look can be run, walked and judged in full before any of it is
considered for the shipping app.

Created 2026-08-20.

---

## 🛑 Read this first

This is **not** the MineLink you ship. The shipping app lives at:

```
C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29
```

That tree is **read-only** from this project. Nothing in it is edited, moved,
deleted or replaced by any work done here. This project has its **own git
repository** — no remote, no shared history, no merge path back.

---

## What this is

The MineLink logistics platform — same features, same domain, same database —
rebuilt on current Material Design 3:

- **One `ColorScheme` as the single source of truth.** The shipping app grew
  twelve token files alongside a Material scheme seeded from a colour
  (`teal700`) that isn't the brand accent (`#22D3EE`). Here there is one
  scheme, and the semantic layer reads *from* it rather than running parallel
  to it.
- **The M3 shape scale** — 4 / 8 / 12 / 16 / 28 / full.
- **M3 motion** — the `Durations` and `Easing` token families.
- **One shell for every role.** The shipping app has two shells and three
  interchangeable sidebar skins, which is why the super-admin console and the
  portal don't feel like the same product. Here every role gets the console's
  layout and the console's placement of things, on M3 window size classes.
- **Real M3 components** — `NavigationRail`, `NavigationBar`,
  `NavigationDrawer`, `FilledButton` and its tonal/outlined siblings,
  `SegmentedButton`, `SearchAnchor`, `Badge`, M3 chips and cards — instead of
  hand-drawn `Container`s.

The brand is unchanged on purpose: navy chrome, `#22D3EE` cyan, Plus Jakarta
Sans / JetBrains Mono / Fraunces. It should read as MineLink, rebuilt.

## What this is NOT

- Not a mockup. It is the real app against the real database.
- Not a fork you can merge. Different repository, deliberately.
- Not a place to change the schema. See below.

---

## ⚠️ It writes to live production

This project uses the **same Supabase projects as the shipping app**, and there
is **no write guard** — that was an explicit decision.

**Every button you press here does what it does in the real app.** Advancing a
trip advances a real trip. Recording a load records a real load and mints a
real waybill. Dispatching notifies real users on their real phones.

Neither Supabase project has a staging counterpart (`CLAUDE.md` §10.2), and
both are on the free plan.

**`supabase/` in this project is frozen.** It is present so the app builds and
so the schema is readable. No migration is ever created, applied or pushed from
here.

---

## Running it

Both apps can be installed and run side by side — the Android
`applicationId`, the app label, the Windows binary name and the web title all
differ from the shipping app's.

```bash
flutter pub get

# Web
flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...

# Windows
flutter run -d windows

# Android (installs as "MineLink M3", alongside the real "MineLink")
flutter run -d <device>
```

## Checks

```bash
flutter analyze
flutter test
dart tool/release_guards.dart
```

---

## Where the design lives

| Path | What |
|---|---|
| `lib/core/design/m3/` | the design system — scheme, shape, motion, type |
| `lib/core/design/tokens/` | the raw brand scale the scheme is built from |
| `lib/core/design/shell/` | `MlAppShell`, the one shell every role uses |
| `lib/core/design/components/` | shared components on M3 primitives |
| `docs/redesign/` | the design decisions and why each was made |
