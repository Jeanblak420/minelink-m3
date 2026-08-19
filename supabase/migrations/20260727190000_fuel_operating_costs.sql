-- Fuel & operating cost capture (2026-07-27). Applied live to yftazblpmicqtamyiwyb.
--
-- Fuel is logged per fill (litres + rand + odometer), which unlocks full-to-full
-- l/100km and cost/km; a generic operating-cost table covers tyres / tolls /
-- other. Both feed the transporter earnings net calculation. Reads = company
-- staff; drivers may log fuel for their own truck; tyres/tolls are manager-only.

CREATE TABLE IF NOT EXISTS public.fuel_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES public.fleet_vehicles(id) ON DELETE CASCADE,
  trip_id uuid REFERENCES public.trips(id) ON DELETE SET NULL,
  litres numeric NOT NULL CHECK (litres > 0),
  cost_zar numeric NOT NULL CHECK (cost_zar >= 0),
  odometer_km numeric,
  station text,
  filled_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  notes text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);
COMMENT ON TABLE public.fuel_entries IS 'Fuel fills per vehicle (litres + cost + odometer) — enables l/100km, cost/km and true net earnings.';
CREATE INDEX IF NOT EXISTS fuel_entries_company_idx ON public.fuel_entries (company_id);
CREATE INDEX IF NOT EXISTS fuel_entries_vehicle_idx ON public.fuel_entries (vehicle_id);

CREATE TABLE IF NOT EXISTS public.vehicle_operating_costs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  vehicle_id uuid NOT NULL REFERENCES public.fleet_vehicles(id) ON DELETE CASCADE,
  trip_id uuid REFERENCES public.trips(id) ON DELETE SET NULL,
  kind text NOT NULL CHECK (kind IN ('tyre','toll','fine','cleaning','other')),
  cost_zar numeric NOT NULL CHECK (cost_zar >= 0),
  incurred_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  description text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);
COMMENT ON TABLE public.vehicle_operating_costs IS 'One-off vehicle operating costs (tyres, tolls, fines, other) that feed earnings net.';
CREATE INDEX IF NOT EXISTS vehicle_operating_costs_company_idx ON public.vehicle_operating_costs (company_id);
CREATE INDEX IF NOT EXISTS vehicle_operating_costs_vehicle_idx ON public.vehicle_operating_costs (vehicle_id);

ALTER TABLE public.fuel_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fuel_entries_select ON public.fuel_entries;
CREATE POLICY fuel_entries_select ON public.fuel_entries FOR SELECT TO authenticated
  USING (public.is_platform_admin() OR public.is_company_staff(company_id));
GRANT SELECT ON public.fuel_entries TO authenticated;

ALTER TABLE public.vehicle_operating_costs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vehicle_operating_costs_select ON public.vehicle_operating_costs;
CREATE POLICY vehicle_operating_costs_select ON public.vehicle_operating_costs FOR SELECT TO authenticated
  USING (public.is_platform_admin() OR public.is_company_staff(company_id));
GRANT SELECT ON public.vehicle_operating_costs TO authenticated;

-- log_fuel_entry: any company staff (incl. drivers at the pump) or admin.
CREATE OR REPLACE FUNCTION public.log_fuel_entry(
  p_company_id uuid, p_vehicle_id uuid, p_litres numeric, p_cost_zar numeric,
  p_odometer_km numeric DEFAULT NULL, p_station text DEFAULT NULL,
  p_trip_id uuid DEFAULT NULL, p_filled_at timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL, p_id uuid DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_id uuid; v_last_odo numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT (public.is_platform_admin() OR public.is_company_staff(p_company_id)) THEN
    RAISE EXCEPTION 'Not authorized to log fuel for this company';
  END IF;
  IF coalesce(p_litres, 0) <= 0 THEN RAISE EXCEPTION 'Litres must be greater than 0'; END IF;
  IF coalesce(p_cost_zar, -1) < 0 THEN RAISE EXCEPTION 'Cost cannot be negative'; END IF;

  IF p_odometer_km IS NOT NULL THEN
    SELECT max(odometer_km) INTO v_last_odo FROM public.fuel_entries
    WHERE vehicle_id = p_vehicle_id AND (p_id IS NULL OR id <> p_id);
    IF v_last_odo IS NOT NULL AND p_odometer_km < v_last_odo THEN
      RAISE EXCEPTION 'Odometer % is lower than the last recorded reading (%). Please check.', p_odometer_km, v_last_odo;
    END IF;
  END IF;

  IF p_id IS NULL THEN
    v_id := gen_random_uuid();
    INSERT INTO public.fuel_entries(id, company_id, vehicle_id, trip_id, litres, cost_zar,
      odometer_km, station, filled_at, notes, created_by)
    VALUES (v_id, p_company_id, p_vehicle_id, p_trip_id, p_litres, p_cost_zar,
      p_odometer_km, p_station, coalesce(p_filled_at, timezone('utc', now())), p_notes, auth.uid());
  ELSE
    UPDATE public.fuel_entries SET
      vehicle_id = p_vehicle_id, trip_id = p_trip_id, litres = p_litres, cost_zar = p_cost_zar,
      odometer_km = p_odometer_km, station = p_station,
      filled_at = coalesce(p_filled_at, filled_at), notes = p_notes
    WHERE id = p_id AND company_id = p_company_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Fuel entry not found'; END IF;
    v_id := p_id;
  END IF;
  RETURN jsonb_build_object('id', v_id);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.delete_fuel_entry(p_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_company uuid; v_creator uuid;
BEGIN
  SELECT company_id, created_by INTO v_company, v_creator FROM public.fuel_entries WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Fuel entry not found'; END IF;
  IF NOT (public.is_platform_admin() OR public.is_company_manager(v_company) OR v_creator = auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  DELETE FROM public.fuel_entries WHERE id = p_id;
  RETURN jsonb_build_object('deleted', true);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.list_fuel_entries(p_company_id uuid)
 RETURNS TABLE(id uuid, vehicle_id uuid, reg text, trip_id uuid, litres numeric,
   cost_zar numeric, odometer_km numeric, station text, filled_at timestamptz,
   notes text, created_by uuid)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  SELECT f.id, f.vehicle_id, fv.vehicle_registration_number, f.trip_id, f.litres,
    f.cost_zar, f.odometer_km, f.station, f.filled_at, f.notes, f.created_by
  FROM public.fuel_entries f
  LEFT JOIN public.fleet_vehicles fv ON fv.id = f.vehicle_id
  WHERE public.is_platform_admin() OR public.is_company_staff(f.company_id)
  ORDER BY f.filled_at DESC;
$fn$;

CREATE OR REPLACE FUNCTION public.log_operating_cost(
  p_company_id uuid, p_vehicle_id uuid, p_kind text, p_cost_zar numeric,
  p_incurred_at timestamptz DEFAULT NULL, p_description text DEFAULT NULL,
  p_trip_id uuid DEFAULT NULL, p_id uuid DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT (public.is_platform_admin() OR public.is_company_manager(p_company_id)) THEN
    RAISE EXCEPTION 'Only a company manager or platform admin can log operating costs';
  END IF;
  IF p_kind NOT IN ('tyre','toll','fine','cleaning','other') THEN RAISE EXCEPTION 'Invalid cost kind'; END IF;
  IF coalesce(p_cost_zar, -1) < 0 THEN RAISE EXCEPTION 'Cost cannot be negative'; END IF;

  IF p_id IS NULL THEN
    v_id := gen_random_uuid();
    INSERT INTO public.vehicle_operating_costs(id, company_id, vehicle_id, trip_id, kind,
      cost_zar, incurred_at, description, created_by)
    VALUES (v_id, p_company_id, p_vehicle_id, p_trip_id, p_kind, p_cost_zar,
      coalesce(p_incurred_at, timezone('utc', now())), p_description, auth.uid());
  ELSE
    UPDATE public.vehicle_operating_costs SET
      vehicle_id = p_vehicle_id, trip_id = p_trip_id, kind = p_kind, cost_zar = p_cost_zar,
      incurred_at = coalesce(p_incurred_at, incurred_at), description = p_description
    WHERE id = p_id AND company_id = p_company_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Cost not found'; END IF;
    v_id := p_id;
  END IF;
  RETURN jsonb_build_object('id', v_id);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.delete_operating_cost(p_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_company uuid;
BEGIN
  SELECT company_id INTO v_company FROM public.vehicle_operating_costs WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Cost not found'; END IF;
  IF NOT (public.is_platform_admin() OR public.is_company_manager(v_company)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  DELETE FROM public.vehicle_operating_costs WHERE id = p_id;
  RETURN jsonb_build_object('deleted', true);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.list_operating_costs(p_company_id uuid)
 RETURNS TABLE(id uuid, vehicle_id uuid, reg text, trip_id uuid, kind text,
   cost_zar numeric, incurred_at timestamptz, description text)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  SELECT o.id, o.vehicle_id, fv.vehicle_registration_number, o.trip_id, o.kind,
    o.cost_zar, o.incurred_at, o.description
  FROM public.vehicle_operating_costs o
  LEFT JOIN public.fleet_vehicles fv ON fv.id = o.vehicle_id
  WHERE public.is_platform_admin() OR public.is_company_staff(o.company_id)
  ORDER BY o.incurred_at DESC;
$fn$;

-- Per-vehicle cost rollup with full-to-full fuel economy for the earnings net.
CREATE OR REPLACE FUNCTION public.list_transporter_vehicle_cost_breakdown(p_company_id uuid)
 RETURNS TABLE(
   vehicle_id uuid, reg text, maintenance_cost numeric, fuel_cost numeric,
   fuel_litres numeric, tyre_cost numeric, toll_cost numeric, other_cost numeric,
   distance_km numeric, l_per_100km numeric, cost_per_km numeric)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  SELECT fv.id, fv.vehicle_registration_number,
    coalesce(m.maint, 0), coalesce(f.fuel, 0), coalesce(f.litres, 0),
    coalesce(o.tyre, 0), coalesce(o.toll, 0), coalesce(o.other, 0),
    e.distance,
    CASE WHEN coalesce(e.distance, 0) > 0 AND coalesce(e.litres_used, 0) > 0
      THEN round(e.litres_used / (e.distance / 100.0), 2) ELSE NULL END AS l_per_100km,
    CASE WHEN coalesce(e.distance, 0) > 0 AND coalesce(e.cost_used, 0) > 0
      THEN round(e.cost_used / e.distance, 2) ELSE NULL END AS cost_per_km
  FROM public.fleet_vehicles fv
  LEFT JOIN (SELECT vehicle_id, sum(cost_zar) maint FROM public.fleet_maintenance_records
    WHERE company_id = p_company_id GROUP BY vehicle_id) m ON m.vehicle_id = fv.id
  LEFT JOIN (SELECT vehicle_id, sum(cost_zar) fuel, sum(litres) litres
    FROM public.fuel_entries WHERE company_id = p_company_id GROUP BY vehicle_id) f ON f.vehicle_id = fv.id
  LEFT JOIN (
    SELECT vehicle_id,
      max(odometer_km) - min(odometer_km) AS distance,
      sum(litres) - (array_agg(litres ORDER BY odometer_km ASC))[1] AS litres_used,
      sum(cost_zar) - (array_agg(cost_zar ORDER BY odometer_km ASC))[1] AS cost_used
    FROM public.fuel_entries
    WHERE company_id = p_company_id AND odometer_km IS NOT NULL
    GROUP BY vehicle_id HAVING count(*) >= 2) e ON e.vehicle_id = fv.id
  LEFT JOIN (SELECT vehicle_id,
      sum(cost_zar) FILTER (WHERE kind = 'tyre') tyre,
      sum(cost_zar) FILTER (WHERE kind = 'toll') toll,
      sum(cost_zar) FILTER (WHERE kind NOT IN ('tyre','toll')) other
    FROM public.vehicle_operating_costs WHERE company_id = p_company_id GROUP BY vehicle_id) o ON o.vehicle_id = fv.id
  WHERE (public.is_platform_admin() OR public.is_company_manager(p_company_id))
    AND fv.company_id = p_company_id
    AND (m.maint IS NOT NULL OR f.fuel IS NOT NULL OR o.tyre IS NOT NULL
      OR o.toll IS NOT NULL OR o.other IS NOT NULL);
$fn$;
