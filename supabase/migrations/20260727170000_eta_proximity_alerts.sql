-- ETA proximity alerts (2026-07-27). Applied live to project yftazblpmicqtamyiwyb.
--
-- When a driver's live navigation ETA shows the truck ~30 minutes from its
-- destination, notify the receiving party's management + the transporter, once
-- per leg (the mine on the loading leg, the buyer on the delivery leg). Hooks
-- into the existing publish_trip_nav_state pipeline; a per-leg marker on
-- trip_nav_state prevents repeat alerts.

ALTER TABLE public.trip_nav_state ADD COLUMN IF NOT EXISTS eta_alert_sent_at timestamptz;
ALTER TABLE public.trip_nav_state ADD COLUMN IF NOT EXISTS eta_alert_status text;

-- Internal helper (not a REST endpoint): decides the target party by leg,
-- notifies once, and stamps the marker.
CREATE OR REPLACE FUNCTION public._fire_eta_proximity_alert(
  p_trip_id uuid, p_vehicle_id uuid, p_time_left_s integer)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_trip record; v_txn record; v_reg text; v_ns_status text;
  v_target uuid; v_dest text; v_mins int; v_meta jsonb;
BEGIN
  IF p_time_left_s IS NULL OR p_time_left_s > 1800 OR p_time_left_s <= 0 THEN RETURN; END IF;

  SELECT * INTO v_trip FROM public.trips WHERE id = p_trip_id;
  IF v_trip.status NOT IN ('en_route_to_load','en_route_to_offload') THEN RETURN; END IF;

  SELECT eta_alert_status INTO v_ns_status FROM public.trip_nav_state WHERE trip_id = p_trip_id;
  IF v_ns_status IS NOT DISTINCT FROM v_trip.status THEN RETURN; END IF; -- already alerted this leg

  SELECT * INTO v_txn FROM public.transactions WHERE id = v_trip.transaction_id;
  SELECT coalesce(v_trip.metadata->>'truck_reg', fv.vehicle_registration_number) INTO v_reg
  FROM public.fleet_vehicles fv WHERE fv.id = p_vehicle_id;

  v_mins := ceil(p_time_left_s / 60.0);
  v_meta := jsonb_build_object('trip_id', p_trip_id, 'nav_tab', 'Live map');

  IF v_trip.status = 'en_route_to_load' THEN
    v_target := v_txn.supplier_company_id; v_dest := 'the mine';
  ELSE
    v_target := v_txn.buyer_company_id; v_dest := 'your site';
  END IF;

  IF v_target IS NOT NULL THEN
    PERFORM public.notify_company_management(v_target, 'Truck approaching',
      format('%s is about %s min away — arriving at %s soon.', coalesce(v_reg,'A truck'), v_mins, v_dest),
      'general', NULL, NULL, 'high', v_meta);
  END IF;
  IF v_txn.transporter_company_id IS NOT NULL THEN
    PERFORM public.notify_company_management(v_txn.transporter_company_id, 'Truck approaching',
      format('%s is about %s min from %s.', coalesce(v_reg,'A truck'), v_mins,
        CASE WHEN v_trip.status='en_route_to_load' THEN 'the mine' ELSE 'the drop-off' END),
      'general', NULL, NULL, 'normal', v_meta);
  END IF;

  UPDATE public.trip_nav_state
  SET eta_alert_sent_at = now(), eta_alert_status = v_trip.status
  WHERE trip_id = p_trip_id;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public._fire_eta_proximity_alert(uuid, uuid, integer) FROM anon, authenticated, public;

-- Re-create publish_trip_nav_state with the alert hook after the upsert.
CREATE OR REPLACE FUNCTION public.publish_trip_nav_state(
  p_current_instruction text DEFAULT NULL::text, p_eta timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_time_left_s integer DEFAULT NULL::integer, p_distance_left_m integer DEFAULT NULL::integer,
  p_speed_kmh double precision DEFAULT NULL::double precision, p_route_polyline text DEFAULT NULL::text,
  p_new_session boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  v_vehicle_id uuid;
  v_trip_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select da.vehicle_id into v_vehicle_id
  from public.driver_assignments da
  join public.employees e on e.id = da.driver_employee_id
  where e.user_id = auth.uid()
  limit 1;
  if v_vehicle_id is null then
    return jsonb_build_object('published', false, 'reason', 'no_vehicle');
  end if;

  select t.id into v_trip_id
  from public.trips t
  where t.vehicle_id = v_vehicle_id
    and t.status not in ('completed', 'cancelled')
  order by t.updated_at desc
  limit 1;
  if v_trip_id is null then
    return jsonb_build_object('published', false, 'reason', 'no_active_trip');
  end if;

  insert into public.trip_nav_state (
    trip_id, vehicle_id, route_polyline, current_instruction, eta,
    time_left_s, distance_left_m, speed_kmh, original_eta, nav_started_at,
    updated_at
  ) values (
    v_trip_id, v_vehicle_id, p_route_polyline, p_current_instruction, p_eta,
    p_time_left_s, p_distance_left_m, p_speed_kmh, p_eta, now(), now()
  )
  on conflict (trip_id) do update set
    vehicle_id = excluded.vehicle_id,
    route_polyline = coalesce(excluded.route_polyline, trip_nav_state.route_polyline),
    current_instruction = coalesce(excluded.current_instruction, trip_nav_state.current_instruction),
    eta = coalesce(excluded.eta, trip_nav_state.eta),
    time_left_s = coalesce(excluded.time_left_s, trip_nav_state.time_left_s),
    distance_left_m = coalesce(excluded.distance_left_m, trip_nav_state.distance_left_m),
    speed_kmh = coalesce(excluded.speed_kmh, trip_nav_state.speed_kmh),
    original_eta = case
      when p_new_session then excluded.eta
      else coalesce(trip_nav_state.original_eta, excluded.eta)
    end,
    nav_started_at = case
      when p_new_session then now()
      else coalesce(trip_nav_state.nav_started_at, now())
    end,
    updated_at = now();

  -- ETA proximity alert: fire once per leg when the truck is ~30 min out.
  perform public._fire_eta_proximity_alert(v_trip_id, v_vehicle_id, p_time_left_s);

  return jsonb_build_object('published', true, 'trip_id', v_trip_id);
end;
$function$;
