-- P10-D7 — proof of delivery must require proof (client ruling, 2026-08-12).
--
-- A driver cannot complete a delivery without a POD photo. Ruled after the
-- seed-data inventory (docs/seed-data-inventory.md §5, P10-D2) established WHY
-- the pod_photos bucket has never held a single file: not because the upload is
-- broken, but because the photo is optional. driver_routes_screen.dart:273 read
-- `if (photo != null)`, and both real PODs on the platform were recorded without
-- one. "Proof of delivery" that carries no proof is the evidence a weight
-- dispute under P8-30 gets argued over — and there is none.
--
-- Enforced in BOTH places, per the ruling: the dialog no longer lets a driver
-- submit without a photo, and this function refuses one. The Dart check is UX;
-- this is the boundary (CLAUDE.md Appendix A — "security lives in RLS and RPCs,
-- Dart checks are UX, implement both").
--
-- ---------------------------------------------------------------------------
-- Why this checks storage.objects and not just `p_photo_url is not null`
-- ---------------------------------------------------------------------------
--
-- A non-blank-string check is satisfied by passing 'x'. That is a disabled
-- button wearing a server costume — exactly what the ruling says not to build
-- ("so the requirement is real rather than a disabled button"). The live data
-- makes the point for us: 33 rows already carry a perfectly non-blank
-- photo_url — 'insights-demo/pod-placeholder.jpg' — and the bucket holds zero
-- objects, so not one of them resolves to a file. A string check would have
-- accepted every one of them.
--
-- So the object must actually exist in the pod_photos bucket. The Dart flow
-- already uploads before it calls this function, so the object is there by the
-- time we look (LifecycleService.uploadPodPhoto -> recordPod, in that order),
-- and a failure here leaves the client's existing rollback to delete the orphan.
--
-- The path must also sit under the transporter company's folder — the same
-- `<companyId>/<uuid>_<name>` convention uploadPodPhoto writes and the storage
-- policies already enforce — so a driver cannot cite another company's photo as
-- their own evidence. Waived for the platform admin, who has no portal company
-- to file under and is the backstop for a correction.
--
-- record_pod is SECURITY DEFINER and owned by postgres, so it can read
-- storage.objects; search_path is 'public', hence the explicit schema qualifier.
--
-- NOT retroactive, by design: the 35 existing pod_uploads rows are untouched.
-- 33 of them are seeded and go with P10-D5; the other 2 are real captures made
-- under the old rule, and rewriting history to pretend otherwise would be its
-- own fiction.

create or replace function public.record_pod(
  p_trip_id uuid,
  p_delivered_tons numeric,
  p_photo_url text default null
)
returns public.trips
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_trip public.trips;
  v_txn  public.transactions;
  v_driver_name text;
  v_driver_sig  text;
  v_tolerance   numeric;
  v_hold        boolean := false;
  v_is_admin    boolean;
  v_photo       text;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip % not found', p_trip_id using errcode = 'P0002';
  end if;

  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  -- P3-16: this used to permit supplier staff while the message below said it
  -- did not. The mine must not be able to declare what arrived at the buyer --
  -- its own figure is the other half of the comparison.
  v_is_admin := public.is_platform_admin();
  if not (
    public.is_company_staff(v_txn.transporter_company_id)
    or v_is_admin
  ) then
    raise exception 'Only the transporter/driver may upload proof of delivery'
      using errcode = '42501';
  end if;

  -- ------------------------------------------------------------ P10-D7
  v_photo := nullif(btrim(coalesce(p_photo_url, '')), '');

  if v_photo is null then
    raise exception
      'A proof-of-delivery photo is required. Capture the offload photo before '
      'recording the delivery.'
      using errcode = '22023';
  end if;

  if not exists (
    select 1 from storage.objects o
     where o.bucket_id = 'pod_photos'
       and o.name = v_photo
  ) then
    raise exception
      'The proof-of-delivery photo % was not found in storage. The upload did '
      'not complete — retry the photo before recording the delivery.', v_photo
      using errcode = '22023';
  end if;

  if not v_is_admin
     and v_photo not like v_txn.transporter_company_id::text || '/%' then
    raise exception
      'The proof-of-delivery photo does not belong to the hauling company for '
      'this trip.'
      using errcode = '42501';
  end if;
  -- ------------------------------------------------------------ end P10-D7

  insert into public.pod_uploads
    (trip_id, transaction_id, photo_url, delivered_tons, uploaded_by)
  values
    (p_trip_id, v_trip.transaction_id, v_photo, p_delivered_tons, auth.uid());

  v_driver_name := coalesce(
    (select display_name from public.profiles where id = auth.uid()), 'Driver');
  v_driver_sig := (select signature_url from public.profiles where id = auth.uid());

  -- The delivery figure lands on the trip beside the mine's net mass; the
  -- generated variance_tons follows from the two.
  update public.trips
     set status = 'offloaded',
         delivered_tons = p_delivered_tons,
         offloaded_at = coalesce(offloaded_at, timezone('utc', now())),
         metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
           'waybill',
           coalesce(metadata->'waybill', '{}'::jsonb) || jsonb_build_object(
             'received_by', v_driver_name,
             'received_signature_path', v_driver_sig,
             'pod_photo_path', v_photo))
   where id = p_trip_id
  returning * into v_trip;

  -- Hold only when the route asked for one AND the shortfall exceeds it.
  -- NULL tolerance (every route today) never holds, so the end-to-end
  -- behaviour is exactly what it was before this migration.
  select r.variance_tolerance_pct into v_tolerance
    from public.routes r where r.id = v_trip.route_id;

  if v_tolerance is not null
     and v_trip.net_tons is not null and v_trip.net_tons > 0
     and v_trip.variance_tons is not null
     and (v_trip.variance_tons / v_trip.net_tons) * 100 > v_tolerance then
    v_hold := true;
  end if;

  if not v_hold then
    v_trip := public.complete_trip(p_trip_id);
  end if;

  return v_trip;
end;
$function$;

comment on function public.record_pod(uuid, numeric, text) is
  'Records proof of delivery for a trip. P10-D7 (client ruling 2026-08-12): the '
  'photo is MANDATORY and must already exist as an object in the pod_photos '
  'bucket under the hauling company''s folder -- a non-blank string is not '
  'sufficient, because 33 seeded rows carry a non-blank path to a file that has '
  'never existed. Caller must be transporter staff or the platform admin '
  '(P3-16): the mine may not declare what arrived at the buyer.';
