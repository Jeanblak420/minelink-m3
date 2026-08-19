-- record_truck_load enforces the seal count the rig actually has.
--
-- Companion to 20260817300000, which defines `expected_seal_count` and carries
-- it to the Load Controller's queue. This is the half that makes it true.
--
-- The previous rule was "not zero". Measured on the two seal-required loads in
-- production on 2026-08-17:
--
--     seals on load | loads
--     --------------+------
--                 2 |     1
--                13 |     1
--
-- Two seals on a two-trailer interlink, thirteen on another — on routes whose
-- entire purpose is that the load is sealed, under a sheet headed "Seals
-- (2 per trailer · 4 total)". The waybill prints TRUCK SEAL SERIAL NO. 1-4, so
-- the first hands the driver a document naming half the seals on his truck and
-- the second records nine that no document can carry.
--
-- ---------------------------------------------------------------------------
-- WHY THIS IS A CATALOG PATCH AND NOT A FULL-TEXT REDEFINITION
--
-- There is no file in this repo holding the current body. 20260817230000
-- defines it in full, and 20260817290000 then rewrites it from
-- `pg_get_functiondef` to turn a silent `exception when others then null` into
-- a named `raise warning`. So the live function is 230000-plus-290000, and
-- exists as text only in the catalog.
--
-- The first attempt at this migration DID ship full text, rebuilt from the
-- 230000 file. It applied cleanly and looked right. The md5 check CLAUDE.md §6
-- prescribes caught it: live body 10,515 chars, file body 10,307 — the 208
-- characters were 290000's logging, which a cold replay would have silently
-- undone. Patching the catalog is what keeps the two halves from fighting.
--
-- Both anchors are asserted before anything is written, so a body that has
-- drifted underneath this raises instead of being patched blind.
-- ---------------------------------------------------------------------------

begin;

do $outer$
declare
  src text;
  patched text;
  old_guard constant text :=
'  v_seal_count := coalesce(jsonb_array_length(p_seals), 0);
  if v_seal_required and v_seal_count = 0 then
    raise exception ''This route requires seals: capture each seal number and photo before saving'';
  end if;
  if v_seal_required then
    if exists (select 1 from jsonb_array_elements(p_seals) e
      where coalesce(e->>''number'','''') = '''' or coalesce(e->>''photo_url'','''') = '''') then
      raise exception ''Each seal needs both a number and a photo on a seal-required route'';
    end if;
  end if;';
  new_guard constant text :=
'  v_seal_count := coalesce(jsonb_array_length(p_seals), 0);
  v_seals_expected := public.expected_seal_count(v_trip.vehicle_id);
  if v_seal_required and v_seal_count = 0 then
    raise exception ''This route requires seals: capture each seal number and photo before saving'';
  end if;
  if v_seal_required then
    if exists (select 1 from jsonb_array_elements(p_seals) e
      where coalesce(e->>''number'','''') = '''' or coalesce(e->>''photo_url'','''') = '''') then
      raise exception ''Each seal needs both a number and a photo on a seal-required route'';
    end if;
    -- Every seal the rig has, and no more. "Not zero" let a two-trailer
    -- interlink be recorded with TWO seals, and another load with THIRTEEN, on
    -- routes that exist to be sealed. The waybill prints four serial lines, so
    -- a count above four records a seal the document cannot carry.
    if v_seal_count <> v_seals_expected then
      raise exception
        ''This load needs % seal(s) for %; you captured %. Two seals per trailer.'',
        v_seals_expected, coalesce(p_truck_reg, ''this vehicle''), v_seal_count;
    end if;
  end if;';
  old_decl constant text := '  v_seal_required boolean := false; v_seal_count int := 0;';
  new_decl constant text := '  v_seal_required boolean := false; v_seal_count int := 0;
  v_seals_expected int := 0;';
begin
  select p.prosrc into src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'record_truck_load';
  if src is null then raise exception 'record_truck_load not found'; end if;
  if position(old_guard in src) = 0 then
    raise exception 'the seal guard is not the expected shape; refusing to patch blind';
  end if;
  if position(old_decl in src) = 0 then
    raise exception 'the declare block is not the expected shape; refusing to patch blind';
  end if;

  patched := replace(replace(src, old_guard, new_guard), old_decl, new_decl);

  execute format(
    'create or replace function public.record_truck_load(
       p_trip_id uuid, p_gross_tons numeric, p_truck_reg text default null::text,
       p_seals jsonb default ''[]''::jsonb, p_waybill jsonb default ''{}''::jsonb)
     returns trips language plpgsql security definer set search_path to ''public'' as %L',
    patched);
end
$outer$;

comment on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) is
  'Second weigh. Takes the GROSS weight and derives net_tons from the tare '
  'record_truck_tare stored, and on a seal-required route now demands exactly '
  'public.expected_seal_count(vehicle) seals, each with a number AND a photo. '
  'Before 2026-08-17 the only count rule was "not zero": production held a '
  'sealed load recorded with 2 seals on a two-trailer rig and another with 13, '
  'while the waybill has room for 4.';

revoke all on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) from public, anon;
grant execute on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) to authenticated;

commit;
