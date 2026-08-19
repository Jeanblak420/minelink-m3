-- place_index moves off the main project. This migration removes it from here.
--
-- WHERE IT WENT
-- -------------
-- To the second Supabase project, `Mine-Link_Extra_Data` (qbydiuplqhmkaxarnuza),
-- which holds bulk reference data only. The app reaches it through
-- PlaceIndexConfig (lib/core/config/place_index_config.dart) instead of
-- SupabaseConfig. See docs/place-index-second-project-runbook.md and
-- CLAUDE.md §10.2.
--
-- WHY
-- ---
-- Measured on this database 2026-08-16:
--
--   disk      place_index                        413 MB
--             all 68 OTHER public tables          47 MB
--             database total                     477 MB of a 500 MB free ceiling
--
--   cpu       place_index queries            181,955 ms of 343,331 ms total
--                                            = 53.0% of ALL query execution time
--                                              on the instance, 373 ms per call
--                                              across 486 calls
--
-- One reference table was 87% of the disk and over half the CPU of a shared
-- free-tier instance that the whole product runs on. It is also the only table
-- in `public` with **no RLS policies** — because it is open Overture Maps data
-- with no owner, reachable only through a SECURITY DEFINER wrapper — which is
-- exactly what makes it the one table safe to move somewhere a main-project JWT
-- is not valid. Nothing else here may follow it: every other table is
-- party-scoped by RLS, and on the extras project a signed-in user arrives as
-- `anon` with no session to scope by.
--
-- WHY A FORWARD MIGRATION RATHER THAN DELETING THE OLD FILES
-- ----------------------------------------------------------
-- The six migrations that built this table genuinely ran here, and their rows
-- are in this project's ledger. Deleting the files would leave ledger entries
-- with no files — the precise state that breaks `supabase db push` and that
-- CLAUDE.md §6 forbids. So the history stands and this migration ends it: a
-- replay onto a fresh main creates the table and then drops it again, which is
-- wasteful but honest and reproducible. The files stay because the extras
-- project is still built from them (tools/place_index_move_project.py).
--
-- SAFETY, VERIFIED ON THIS DATABASE BEFORE WRITING THIS
-- -----------------------------------------------------
--   * foreign keys referencing place_index ......... 0
--   * views depending on it ........................ 0
--   * functions touching it ........................ 2 (both dropped below)
--   * realtime publications containing it .......... 0
--   * RLS policies on it ........................... 0
--
-- `cascade` is therefore not doing anything unseen — the only dependents are
-- the two functions named here, and both move with the table.

drop function if exists public.search_place_index(text, int) cascade;
drop function if exists public._place_index_rank(text, text[], text[], int) cascade;
drop function if exists public._place_index_interpolate(int, text, double precision, double precision) cascade;
drop table if exists public.place_index cascade;

-- place_house_number / place_street_key are deliberately KEPT.
--
-- They are pure text functions with no dependency on the table, they are cheap,
-- and dropping them would make 20260816090000 and 20260816160000 unreplayable
-- against this project for no gain. They simply have no caller here any more.
comment on function public.place_house_number(text) is
  'Leading house number from a free-form address line, ASCII digits only. '
  'Retained after place_index moved to the Mine-Link_Extra_Data project '
  '(2026-08-16) — pure text helper, no table dependency, no caller here.';
