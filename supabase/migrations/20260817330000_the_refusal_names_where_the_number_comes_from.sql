-- The seal refusal stopped being true when the rule stopped being a rule.
--
-- 20260817310000 made `record_truck_load` refuse a sealed load whose seal count
-- is wrong, and signed the message off with:
--
--     This load needs 4 seal(s) for S6W001GP; you captured 2. Two seals per
--     trailer.
--
-- That last sentence was accurate while the count was inferred from the trailer
-- registrations. 20260817320000 replaced the inference with
-- `fleet_vehicles.seal_points` — a stated fact the transporter owns and can
-- change — so "two seals per trailer" now describes only how the initial value
-- happened to be derived, not why this load is being refused.
--
-- A load controller reading it would go and count trailers, find two, count
-- seals, find the number the message just told them, and have no idea what to
-- do next. The sentence has to point at the thing that decides: the vehicle
-- record, and the transporter who owns it.
--
-- Patched from the catalog for the same reason 310000 was — no file holds this
-- body — and the anchor is asserted before anything is written.

begin;

do $outer$
declare
  src text;
  patched text;
  old_line constant text :=
'        ''This load needs % seal(s) for %; you captured %. Two seals per trailer.'',';
  -- Adjacent string literals separated by a newline, which is how the rest of
  -- this function writes a long message. `raise` takes a literal format string,
  -- not an expression, so a `||` concatenation here is a syntax error — the
  -- first attempt at this migration was rejected for exactly that.
  new_line constant text :=
'        ''This load needs % seal(s) for %; you captured %. That is how many ''
        ''seal points this rig is recorded as carrying — the transporter can ''
        ''correct it on the vehicle in Fleet.'',';
begin
  select p.prosrc into src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'record_truck_load';
  if src is null then raise exception 'record_truck_load not found'; end if;
  if position(old_line in src) = 0 then
    raise exception 'the seal refusal is not the expected shape; refusing to patch blind';
  end if;

  patched := replace(src, old_line, new_line);

  execute format(
    'create or replace function public.record_truck_load(
       p_trip_id uuid, p_gross_tons numeric, p_truck_reg text default null::text,
       p_seals jsonb default ''[]''::jsonb, p_waybill jsonb default ''{}''::jsonb)
     returns trips language plpgsql security definer set search_path to ''public'' as %L',
    patched);
end
$outer$;

revoke all on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) from public, anon;
grant execute on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) to authenticated;

commit;
