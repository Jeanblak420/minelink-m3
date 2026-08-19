-- Targets follow-up (2026-08-08):
--   1. The scope rule, written where the schema is read rather than only in a
--      migration file nobody opens.
--   2. search_path pinned on the two helpers that were left invoker-mutable
--      (Supabase linter 0011).

begin;

-- ---------------------------------------------------------------------------
-- 1. The scope rule: INDEPENDENT
-- ---------------------------------------------------------------------------
-- The three scopes are three separate commitments. A platform target is not
-- derived from the org-type targets, and an org-type target is not derived
-- from its companies'. They may disagree, and a disagreement is not a fault.
--
-- This is a decision, not an oversight (jean, 2026-08-08). Rolling up would
-- mean the platform figure could not be set directly — you would commit to a
-- network number only by talking every company into its share first, and one
-- company joining or leaving would silently move a target somebody had
-- already locked for twelve months.
--
-- Note also that the org-type actuals genuinely cannot sum to the platform
-- figure: one load has a mine, a buyer and a transporter, so it counts once
-- under each of the three. The same movement seen from three sides.

comment on table public.monthly_targets is
  'One tonnage target per calendar month per scope. SCOPES ARE INDEPENDENT: '
  'platform / org_type / company targets are separate commitments that are '
  'never reconciled against each other and may disagree. Immutable once the '
  'month closes (trigger monthly_targets_guard). Writes only via '
  'set_monthly_target(); the table carries no write grant.';

comment on table public.target_cycles is
  'One 12-month commitment per scope: six horizon targets (d7/d14/m1/m3/m6/m12) '
  'locked together and immutable until started_on + 1 year (trigger '
  'target_cycles_guard). SCOPES ARE INDEPENDENT — see monthly_targets. '
  '`actuals` is null until close, then frozen as recorded: a closed cycle must '
  'not change because a waybill was corrected eighteen months later.';

comment on column public.monthly_targets.scope is
  'platform | org_type | company. Exactly the matching key column is populated '
  '(constraint monthly_targets_scope_key); uniqueness is per scope, via three '
  'partial indexes.';

comment on column public.monthly_targets.target_tons is
  'Zero means NOT SET, not "a target of zero" — the two render differently. A '
  'placeholder nobody chose that looks like a decision is how this system '
  'previously ended up reporting against 28,000 t.';

comment on column public.target_cycles.started_on is
  'Always the 1st of a month. The client counts elapsed cycle days as calendar '
  'days since this date, and the lock window is measured from it (not from '
  'locked_at) so the screen and the trigger cannot disagree about the reopen '
  'date.';

-- ---------------------------------------------------------------------------
-- 2. search_path
-- ---------------------------------------------------------------------------
-- Both are pure — no table access, invoker rights — so in practice they
-- already inherit the pinned path of the definer functions that call them.
-- Pinned anyway: "safe because of who happens to call it" is not a property
-- worth relying on, and it clears the linter warning.

alter function public.target_scope_matches(text, text, uuid, uuid, uuid, uuid)
  set search_path = public;
alter function public.target_cycle_label(date)
  set search_path = public;

commit;
