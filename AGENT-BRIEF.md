You are finishing Mine-Link Consumer Release v1.0 in `worktree-2026-05-05T11-53-29`, branch `chore/release-v1-hardening`.

Three documents at the repo root govern this work. Read all three before you touch anything:

- **`COMPLETION-PLAN.md`** — how this gets finished, and §2 defines what a tick is allowed to mean. Read §2 twice.
- **`COMPLETION-CHECKLIST.md`** — 143 closure gates across 10 stages. This is what you tick.
- **`To-Do's.md`** — the 413 item-level tasks. Still the item-level source of truth; the checklist is the closure layer over it.

Current state, verified against live production rather than taken from the checklist's own claims: **109 of 413 items done, 0 of 143 gates.**

---

## The one rule that matters more than the rest

**A tick is a claim. On this project, claims have been wrong often enough to be worth systematising.**

Four times work was reported complete and was not: a badge test that asserted on throwing stubs and passed vacuously because Riverpod turns a throw inside a `FutureProvider` into `AsyncError`; an Employee Register sweep that went green because `onlineUsersProvider` throws without Supabase so every case rendered an error state and error states never overflow; a ledger repoint that silently rolled back because the `UPDATE` was batched with a `rollback`; and a progress counter that drifted twice in one day. Separately, twelve plan items turned out to be wrong about the code — including one raised as a release blocker and then disproved by executing the path.

**Reading the code is not proof. A green test is not proof unless you have seen it red.**

So: every ticked box carries an evidence line —

```
✅ <what changed> — <how it was proven> — <the observable result>
```

— and the proof must be one of four classes, marked on each gate in the checklist:

- **A — DB-proven.** A query run against the live project with its **actual output** recorded. Mutations proven in a rolled-back transaction showing both the success path and the refusal path.
- **B — Test-proven, red first.** The test must **fail against the pre-fix code**, and that red run must be recorded. This is non-negotiable — it is the single rule that would have caught three of the four failures above.
- **C — Build-proven.** An artifact built from a named commit and actually run, SHA recorded.
- **D — Walk-proven.** The running app, driven per role, result observed.

If something genuinely cannot be proven — an empty table with no path to a real row, a device test with no device — do **not** tick it and do **not** skip it silently. Mark it:

```
⏸ UNPROVABLE — <precisely why> — <what would make it provable>
```

An unprovable item is an honest state. A ticked unprovable item is a lie that ships.

Three phrases are banned in an evidence line: *"should now"*, *"appears to"*, and *"all tests pass"* on its own.

---

## Order

Work the stages **S0 → S10** in order. The ordering is not arbitrary — each stage removes rework from the ones after it. Two hard dependencies:

- **S3 (data truth) must complete before S6 (the workflow proof).** Walking the workflow against seeded data proves nothing and would have to be redone.
- **Phase 5 extraction strictly before Phase 6 migration** inside S5. Migrating screens onto tokens that have not been extracted means doing it twice.

S1 and S2 may overlap. S5 may run alongside S2–S4 since it touches presentation rather than data.

**S0 is six things only the client can do** — backup marker, Android keystore, token rotation, Play Console, a physical device, and deleting a plaintext-password file. Check their status first and report which are outstanding. **S3 does not run without S0-1**, the backup. If it has not been taken, stop and say so rather than running deletes on a production database with no staging.

---

## Standing constraints

- Package name stays `flutter_application_1`.
- Never `git stash` / `git checkout -- .` / `git clean` / branch-switch in this worktree.
- **The one Supabase project is PRODUCTION. There is no staging.** Additive changes and new RPCs freely. **Stop and ask before dropping or renaming anything** not explicitly authorised in the checklist. Gates marked `ASK` need the client's word before you act.
- One migration per file, applied then mirrored to disk, ledger repointed **in its own call** — never batched with a `rollback`.
- No `SupabaseConfig.client` from a screen. All DB access via a feature service or core repository.
- R (ZAR) only. No emoji in the UI. A dial with no target reads "Not set", never "0".
- **Progress is `grep -c '^- \[x\]'`. Recount, never increment.** More than one session edits these files.
- `flutter analyze` clean and `flutter test` green at every commit.

---

## What to expect, so you do not treat it as a surprise

Every significant feature examined so far has been **fully built and never once called** — the dismissal chain, the dispute system, seat serials, the POD upload. Assume S6 surfaces more of them. When it does, the finding is the deliverable: record it, correct the plan item, and wire the existing machinery rather than rebuilding it.

Also expect the dashboards to change after S3. The seeded trips stay by client ruling, so tonnage stays high, but delivered tonnage and every variance go to NULL. **That is correct, not a regression.** And say plainly in your report that ~94% of recorded tonnage remains invented by the client's choice — any KPI verified against those totals must be labelled *verified-against-seed*, never *proven*.

---

## Session protocol

Work stages in order; within a stage, order is yours. Commit in coherent chunks with real messages and push.

When context runs low: recount the progress figures in both files, regenerate the per-stage table rather than hand-editing it, update `HANDOFF.md` so the next session cold-starts from these three documents, push, and stop. **Do not start a gate you cannot finish** — a half-done gate with no evidence line is worse than an untouched one.

## Reporting back

1. Gate IDs ticked, each with its evidence line. Recounted figures.
2. Everything marked `⏸ UNPROVABLE`, with the reason.
3. **Anything that contradicts the plan or the checklist.** You have been right more often than the plan has — that is the single most valuable thing you produce.
4. Anything needing the client, as a question with your recommendation.

Do not ask permission to start. Begin by reporting the status of S0, then start S1.
