# Mine-Link — Completion Plan

**Purpose:** take the remaining work from 109/413 to a defensible consumer release, where every item marked resolved is *actually* resolved.
**Companions:** `COMPLETION-CHECKLIST.md` (the gates) · `To-Do's.md` (the 413 item-level tasks) · `PLAN.md` (the original audit).
**Written:** 2026-08-12 · **Project:** `yftazblpmicqtamyiwyb` (production — no staging) · **Branch:** `chore/release-v1-hardening`

---

## 1. Why this document exists

`To-Do's.md` already lists every task. It is not the problem. The problem is that **a tick in a checklist is a claim, and on this project claims have been wrong often enough to be worth systematising.**

Four times now, work was reported complete and was not:

| What happened | Why it passed |
|---|---|
| A badge-isolation test asserted on throwing stubs | Riverpod captures a throw inside a `FutureProvider` as `AsyncError`, so **every assertion passed vacuously** |
| An Employee Register sweep went green on first run | `onlineUsersProvider` throws without Supabase, so every case rendered an error state — **and error states never overflow** |
| A migration ledger repoint silently rolled back | The `UPDATE` was batched with a `rollback` in the same call |
| The progress counter drifted twice in one day | Two sessions hand-edited a literal against stale copies |

And separately, twelve plan items turned out to be wrong about the code — including one raised as a release blocker that was disproved by actually executing the path.

The lesson is consistent: **reading the code is not proof, and a green test is not proof unless you have seen it red.** This plan encodes that.

---

## 2. The evidence standard — the core of this document

> **An item may be ticked only when accompanied by an evidence line, and only when that evidence falls into one of the four classes below.**

### Evidence line format

Every ticked box carries one line, appended to the item in `To-Do's.md`:

```
✅ <what changed> — <how it was proven> — <the observable result>
```

Not "done". Not "implemented". Not "verified". Those are claims, not evidence.

### The four classes of proof

**A — DB-proven.** A query executed against the live project, with its **actual output** recorded. For anything mutating, a rolled-back transaction that demonstrates both the success path and the refusal path.
*Insufficient:* "the function checks org type." *Sufficient:* "assigning `security` to a buyer's employee raised `23514`; assigning `admin` succeeded; transaction rolled back."

**B — Test-proven, red first.** A test that **fails against the pre-fix code** and passes after. The red run must be recorded.
*This is non-negotiable and it is the single rule that would have caught three of the four failures above.* A test written after the fix, never seen failing, proves only that it does not crash.

**C — Build-proven.** An artifact built from a named commit and actually run. The commit SHA is recorded.
*Insufficient:* "the build succeeds." *Sufficient:* "built at `abc1234`, installed, signed in as a transporter admin, opened Routes, saw 3 real rows."

**D — Walk-proven.** A human or the agent driving the running app, per role, observing the result. Required for every one of the 22 workflow steps and for the nav matrix.
Screenshots or a recorded action log where the result is visual.

### When something cannot be proven

Some items genuinely cannot be proven right now — an empty table with no way to generate a real row, a device test with no device. Those are **not ticked and not silently skipped**. They are marked:

```
⏸ UNPROVABLE — <precisely why> — <what would make it provable>
```

and listed in the stage's gate report. An unprovable item is an honest state. A ticked unprovable item is a lie that ships.

### The three phrases that are banned in an evidence line

- *"should now"* — either it does or you have not checked.
- *"appears to"* — that is reading, not proving.
- *"all tests pass"* on its own — which test, and was it ever red?

---

## 3. Standing rules that survive every session

- Package name stays `flutter_application_1`.
- Never `git stash` / `git checkout -- .` / `git clean` / branch-switch in this worktree.
- **Production, no staging.** Additive DB changes and new RPCs freely. **Stop and ask before dropping or renaming anything** not explicitly authorised in the checklist.
- One migration per file, applied then mirrored to disk, ledger repointed **in its own call** — never batched with a `rollback`.
- No `SupabaseConfig.client` from a screen. All DB access via a feature service or core repository.
- R (ZAR) only. No emoji in the UI. A dial with no target reads "Not set", never "0".
- **Progress is `grep -c '^- \[x\]'`.** Recount, never increment. More than one session edits these files.
- `flutter analyze` clean and `flutter test` green at every commit.

---

## 4. Order of work, and why

Ten stages. The ordering is not arbitrary — each stage removes a class of rework from the ones after it.

**S0 — Human prerequisites.** Five things only Burger can do (backup marker, keystore, token rotation, Play Console, a physical Android device). They gate later stages, so they are surfaced first rather than discovered at the end.

**S1 — Distribution blockers.** Four items that individually prevent the app from being installed by anyone. Cheap, absolute, and pointless to defer.

**S2 — Security closure.** Cross-tenant reads, public buckets, the four auth-guard holes, and the unread policy bodies. Before the design migration, because a screen migrated onto a leaky query has to be revisited.

**S3 — Data truth.** The partial purge, mandatory POD photos, the demo banner, and removing `MlSampleData`. **Before any dashboard verification**, because verifying a KPI against seeded data proves nothing and has to be redone.

**S4 — The seat and commercial model.** Seats, serials, tokens, reassignment governance. This is the revenue logic and it currently does not function.

**S5 — Design system and portal migration.** 60 items, 54 screens. Extraction (Phase 5) strictly before migration (Phase 6) — migrating onto tokens that have not been extracted means doing it twice.

**S6 — The 22-step workflow proof.** The only stage that proves the product works. Deliberately after S2–S5 so it is walked against real data, correct security and the final design.

**S7 — Navigation and routing closure.** The nav matrix, orphan routes, deep links. After S5 so it is asserted against the migrated screens.

**S8 — Cross-cutting.** Chat hierarchy, group chat, notifications, signatures, company reg-ref.

**S9 — The blind spots.** Sixteen areas never audited. Two of them — no crash reporting, no offline testing — are genuine release risks for a mining app.

**S10 — Builds and the release gate.** Windows, Web, Android from one commit, then the 20 gate conditions.

### What runs in parallel

S1 and S2 can overlap. S5 (design) can run alongside S2–S4 if a second worker exists, since it touches presentation rather than data. **S6 cannot start before S3 completes** — that dependency is hard.

---

## 5. What will go wrong, stated in advance

1. **More "built but never called" features will surface.** Dismissal, the dispute system, seat serials and the POD upload all followed that pattern. Budget for it in S6; do not treat each discovery as a surprise.
2. **The dashboards will look nearly empty after S3.** By client ruling the seeded trips stay, so tonnage stays high — but delivered tonnage and every variance goes to NULL. That is correct, not a regression.
3. **The design migration will surface functional bugs.** Touching 54 screens always does. They belong to their own stage's item, not to S5.
4. **The workflow walk will be slow.** 22 steps × multiple roles, on a live project, with real accounts. This is the stage most likely to be under-estimated and it is the one that matters most.
5. **Some items will end `⏸ UNPROVABLE`.** That is the honest outcome for empty tables with no path to a real row. It must be visible in the final report, not buried.

---

## 6. What only a human can do

| # | Task | Why it cannot be delegated |
|---|---|---|
| 1 | PITR marker / backup on the Supabase dashboard | Console-only; gates all deletions |
| 2 | Generate the Android release keystore, store it safely | It is a permanent secret; losing it means never updating the app again |
| 3 | Rotate the Esri ArcGIS token | Held in an Esri account |
| 4 | Play Console: background-location declaration + demo video | Account-bound submission |
| 5 | Physical Android device road test | Real GPS, real signal loss |
| 6 | Approve anything the checklist marks **ASK** | Irreversible on production |

---

## 7. Definition of done

The release is complete when **all twenty release-gate conditions are true, each with an evidence line**, and the unprovable list is empty or every entry on it has been explicitly accepted by the client in writing.

Not when the checklist is all ticks. When the evidence stands up.
