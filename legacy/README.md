# `legacy/` — historical scratch, kept for reference, current for nothing

**S10-7.** 137 files moved here from the repo root on 2026-08-15 with `git mv`,
so history follows them.

CLAUDE.md §1 has said for a long time that these are *"historical artifacts, not
current architecture"* and that agents should not imitate them. That warning
was doing its work at the bottom of a file, while the artifacts themselves were
the first 166 things anyone saw on opening the repo. The root now holds 28
files and every one of them is live.

**Nothing in this folder is run, imported, or referenced by the application.**
`lib/` and `supabase/migrations/` are the product; if something here disagrees
with them, they are right.

## What is where

| folder | what | count |
|---|---|---|
| `legacy/sql` | one-off `fix_*`, `check_*`, `add_*`, `reset_*` SQL from past debugging. Superseded by `supabase/migrations/`, which is the schema's source of truth (CLAUDE.md §6). | 32 |
| `legacy/scripts` | `.ps1` / `.bat` / `.dart` / `.py` / `.js` helpers — migration pushers, deploy hooks, mock generators, canary runners. | 47 |
| `legacy/notes` | `.md` and `.txt` from earlier phases: troubleshooting write-ups, webhook implementation notes, six overlapping "Application Overview" documents. | 48 |
| `legacy/assets` | screenshots and the two standalone HTML pages, including `waybill_reference.html` — the earlier approximation of the waybill, superseded by `assets/Varsiwave waybil 2l.png`. | 5 |
| `legacy/credentials-DO-NOT-USE` | ⚠ **read the warning below.** | 5 |

## ⚠ `legacy/credentials-DO-NOT-USE`

These five files contain a **Postgres connection string with the password
inline** for Supabase project `kkcseqmpgzzrogatdoqi`:

```
DATABASE_CONNECTION.md · SBasEp · setup_db_connection.bat
setup_db_connection.ps1 · test_db_connection.ps1
```

Three things make this worse than the shared demo password recorded under S9-8:

1. **It is the database superuser, not an app credential.** A pooler
   connection string authenticates as `postgres.<ref>` and **bypasses RLS
   entirely** — none of the policy work in this repo applies to a session
   opened with it.
2. **The password looks personal**, not generated, so it is the kind that gets
   reused on other systems.
3. **One of the files is called `SBasEp`** — no extension, no hint. It was
   sitting in the repo root among 165 other files and nothing named it.

They are moved rather than deleted deliberately: **deleting does not fix
this.** Every one has been in git history since the initial commit
(`4df071c`), so the string is recoverable from any clone by anyone who has
ever had one. **Only rotating the password fixes it** — that is an account
action and belongs to the project owner.

`tool/release_guards.dart` carries a `committed-db-connection-string` guard so
a sixth copy cannot appear. It matches the *shape* of a connection string with
an inline password rather than the literal, deliberately: writing the password
into the guard to grep for it would have created that sixth copy.

Note the project ref is **not** the live one. Live is `yftazblpmicqtamyiwyb`
(CLAUDE.md, `config/supabase.live.json`); this is an older project. Whether it
still exists, and whether it holds real data, is worth checking as part of the
rotation.
