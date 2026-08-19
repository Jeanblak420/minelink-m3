-- EXTRAS PROJECT ONLY (qbydiuplqhmkaxarnuza). Do not apply to the main project.
--
-- `search_place_index` must be callable by `anon` HERE, and only here.
--
-- WHY
-- ---
-- 20260816100000 ends with:
--
--     revoke execute on function public.search_place_index(text, int) from public;
--     grant  execute on function public.search_place_index(text, int) to authenticated;
--
-- which is exactly right on the main project and **silently wrong on this one**.
-- A JWT minted by the main project's GoTrue is not valid here — different
-- project, different JWT secret — so a signed-in MineLink user arrives at this
-- database as `anon`, not `authenticated`. Without this grant every picker
-- search returns `permission denied for function search_place_index`, the
-- place-index stage degrades to nothing by design, and the search falls through
-- to Nominatim. The user sees worse results and no error at all.
--
-- HOW IT WAS FOUND
-- ----------------
-- Not by inspection. The grant was applied once by
-- tools/place_index_move_project.py, so the live project worked and looked
-- correct. It only surfaced when the 42P13 fix in 20260816100000 was verified
-- by actually replaying that migration over the live function: the replay ran
-- `grant ... to authenticated` again and the `anon` grant survived merely
-- because nothing had revoked it. On a genuinely fresh project — the case this
-- whole directory exists for — the grant would never have been created, and the
-- failure would have been invisible: fewer search results, no error, no log.
--
-- IS IT SAFE?
-- -----------
-- Yes, and only because of what this database contains. It holds one table of
-- open Overture Maps data (CDLA-Permissive-2.0) with no owner and no personal
-- information. The table itself keeps RLS on with no policy AND no grant
-- (20260816190000), so this SECURITY DEFINER wrapper remains the only way in,
-- capped at 20 rows per call. There is no user, company or trip data here to
-- protect — and per this directory's README, there never may be.
--
-- The internal helpers stay unreachable: _place_index_rank and
-- _place_index_interpolate are granted to postgres and service_role only.

grant execute on function public.search_place_index(text, int) to anon;

comment on function public.search_place_index(text, int) is
  'Address search over the Overture place index (South Africa only). Granted '
  'to BOTH anon and authenticated on this project, because a main-project JWT '
  'is not valid here and every MineLink user arrives as anon. SECURITY '
  'DEFINER: the table underneath has RLS on with no policy and no grant, so '
  'this function is the only way to read it.';
