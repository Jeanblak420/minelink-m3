-- Corrects the `target_cycles.started_on` comment (2026-08-08).
--
-- The previous wording said "the client counts elapsed cycle days as calendar
-- days since this date". The VALUE is right — verified against the live
-- database: a cycle started 2026-03-01 reports 161 elapsed days on 2026-08-08,
-- and 2026-03-01 → 2026-08-08 inclusive is 161 days. The MECHANISM was wrong,
-- and in the place someone would go to check it.
--
-- The v1 client holds no date at all. `MlCycle` has no start field and
-- `elapsedCycleDays` is simply `dailySeries.length` — the length of the
-- flattened per-day tonnage array. The two agree only because
-- `get_targets_state` emits months from the cycle's start month through today
-- with one entry per elapsed calendar day, zeros included, and the client
-- concatenates every month that has entries.
--
-- So the invariant is real but SERVER-MAINTAINED, and it is load-bearing in a
-- way worth stating: it is the same constraint that stops the short-term tab
-- showing months from before the cycle start, because any extra month would
-- inflate the day count and move every horizon. A `startedOn` on MlCycle
-- (v2, pending) is what decouples them.

begin;

comment on column public.target_cycles.started_on is
  'Always the 1st of a month. The reopen date is measured from here, not from '
  'locked_at, so a cycle is immobile for its own twelve months rather than for '
  'twelve months from whenever the button was pressed. '
  'INVARIANT: elapsed cycle days == calendar days since this date. The client '
  'does not compute that itself — it counts entries in the flattened daily '
  'series — so get_targets_state must keep emitting one entry per elapsed '
  'calendar day from this month onward, zeros included, for the screen and the '
  'target_cycles_guard trigger to agree on when the cycle reopens.';

commit;
