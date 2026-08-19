# Future work — deferred by client decision

Things the client was shown, understood, and chose **not** to do for v1.0. Each
one is a live gap in the product, not a closed item: they are here so that "we
decided that" survives the person who decided it.

This file is **not** a backlog of everything anyone might want. The bar for an
entry is: *somebody found a real gap, raised it, and the client ruled to defer.*
Anything ruled the other way gets fixed instead of listed.

Each entry names the ruling, the code that encodes it, and — the part that is
usually missing — **what has to be true before it can be done**, because most of
these are not waiting on effort.

---

## 1. Sign-in statistics are marketing placeholders

**Ruled 2026-08-16.** The sign-in brand panel shows three figures in large type
on the first screen a customer ever sees:

| shown | production, measured 2026-08-16 |
| :-- | :-- |
| `24+ Companies` | 26 companies |
| `480 Trucks live` | **7** vehicles |
| `1.2M t Hauled` | **1,227.9 t** hauled |

The fleet is overstated by roughly 68x and the tonnage by a factor of a
thousand. The client's ruling, verbatim:

> for now, no but add this to a list for future things to do, for now it can be
> the fake numbers that's on it but I'd like for it to be real numbers somewhere
> in the future when we have more companies registered with us.

**Where:** `lib/features/auth/widgets/signin/minelink_signin_brand.dart`, the
`stats` default. Held at exactly three by the `no-hardcoded-brand-stat` ratchet
in `tool/release_guards.dart` — a fourth invented figure fails the build.

**What has to be true first.** Not effort — a decision. The sign-in screen
renders *before any session exists*, so real figures need a **public,
unauthenticated** endpoint publishing how many customers MineLink has and how
much ore they move. That is a disclosure the client has to want; the current
numbers are ones they would presumably be happy to publish, and the real ones
they may not be. So this is: (a) decide to publish, (b) an RPC granted to
`anon` returning three scalars — deliberately only three, so it cannot become a
public analytics surface — (c) pass them as `stats:`.

**Do not** read them from an authenticated query with a fallback. A figure that
is real for a signed-in viewer and invented for everyone else is worse than one
that is consistently invented, because nobody can tell which they are looking
at.

**Constraint that outlives the fix:** nothing downstream may treat these as
data. They are rendered by `_stat` and read by nothing else. They must never
reach a report, an export, or a dashboard.

---

## 2. Waybill deep links are shareable but not discoverable

**Decided 2026-08-16** (agent's call under the client's standing "get the rest
done" instruction, recorded rather than escalated).

Four routes render a single waybill — `/portal/{mine,transporter,buyer,driver}/
trips/:id/waybill`. They work, they are party-scoped, and `route_reachability`
counts them reachable. But nothing in the app *emits* one: every waybill is
opened through `showWaybillModal`, so the only way to get the URL is to know the
route shape and the trip UUID.

v1.0 ships the copy-link affordance in the modal, which makes the URL
obtainable. What is deferred is the case the link is actually wanted for:
**sending a waybill to somebody who is not a MineLink user** — a receiving
clerk, an auditor. Today they cannot open it, and should not be able to: the
route is behind auth, and the waybill names the parties, the tonnage and the
price basis.

**What has to be true first.** A signed, expiring, single-document token —
scope one waybill, not one trip and not one route — plus a client decision on
its lifetime and on whether the recipient may print. That is a small feature
with a real security surface, which is exactly the kind of thing that should
not be improvised at the end of a hardening pass.

---

## 3. The shells overrode the OS text scale — ✅ FIXED 2026-08-17

Kept here rather than deleted, because the entry was wrong in a way worth
remembering, and because it is the worked example of this file's own advice
being followed in order.

**What it said.** `UiPrefs.textScale` clamps to 0.85–1.3 and is applied through
`MediaQuery`, *replacing* the platform scaler rather than composing with it, so
an admin running their OS at 200% gets 130% — and this is console-only, since
the portal and driver shells honour the OS setting.

**Both of those turned out to be understatements.**

- The portal shell had since picked up the identical line, when the setting was
  extended to non-admin roles. So it applied to mines, buyers, transporters and
  drivers too — the whole product, not the console.
- "An admin at 200% gets 130%" describes an admin who has *used* the slider.
  It ships at **1.0**, so a user who had never opened it — which is the normal
  case — got exactly **100%**. The OS accessibility setting was not capped. It
  was discarded.

**Done in the order this entry set out**, which was the right order:

1. `test/widgets/super_admin_overflow_sweep_test.dart` raised from 1.3 to 2.0.
2. It found **four** real overflows, none of which reproduced below 1.6: an
   org-type pill, an "Open workspace" button, two chart legends starved to
   under 12px by an unflexed axis caption beside them, and a leaderboard row.
   All fixed.
3. Only then did the shells start composing, via `mlTextScaler` in
   `lib/core/layout/text_scale.dart`.

**The cap is on the composed result, not on the preference** —
`kMaxEffectiveTextScale`, currently 2.0. Capping the preference is what caused
the original defect. The constant is a proof boundary rather than a taste: the
sweep asserts its own top scale is at least that value, so raising one without
the other fails, and `shell-composes-the-platform-text-scale` in
`tool/release_guards.dart` blocks a shell from installing `TextScaler.linear`
again. A unit test cannot hold that line — it would pass against either shell.

**Still deferred:** going past 2.0. An OS scale above 200% is now clamped rather
than honoured, which is a smaller version of the same defect. Closing it means
extending the sweep again and fixing whatever the next band finds.

---

## Related documents

- `docs/seed-data-inventory.md` — what is seeded and what that means for every
  tonnage figure in the product. **Read it before quoting a total.**
- `docs/rls-policy-verdicts.md` — per-policy verdicts from the RLS walk.
- `docs/route-reachability-verdicts.md` — per-route reachability verdicts.
