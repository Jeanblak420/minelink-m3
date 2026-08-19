-- Release v1.0 hardening — P3-01, P3-03, P3-62, P3-63.
--
-- 1. Revoke EXECUTE from `anon` on the 27 SECURITY DEFINER functions the
--    Supabase security advisor reports as callable without signing in.
--    They almost certainly fail today on auth.uid() being null, but that is
--    an implementation accident, not a policy. `authenticated` keeps its
--    grant; nothing in the app calls these while signed out.
-- 2. Pin the one function with a mutable search_path.
-- 3. Add covering indexes for the six unindexed foreign keys.
-- 4. Fix the one auth_rls_initplan warning (auth.uid() re-evaluated per row).
--
-- No behavioural change for any signed-in user.

-- ---------------------------------------------------------------------------
-- 1. Revoke anon EXECUTE (27 functions)
-- ---------------------------------------------------------------------------

revoke execute on function public.add_recon_dispute_comment(p_dispute_id uuid, p_body text) from anon;
revoke execute on function public.check_email_registered(target_email text) from anon;
revoke execute on function public.delete_compliance_document(p_id uuid) from anon;
revoke execute on function public.delete_fuel_entry(p_id uuid) from anon;
revoke execute on function public.delete_my_compliance_document(p_id uuid) from anon;
revoke execute on function public.delete_operating_cost(p_id uuid) from anon;
revoke execute on function public.get_profile_setup(p_employee_id uuid) from anon;
revoke execute on function public.get_runtime_platform_status() from anon;
revoke execute on function public.list_available_routes() from anon;
revoke execute on function public.list_compliance_documents(p_company_id uuid) from anon;
revoke execute on function public.list_fuel_entries(p_company_id uuid) from anon;
revoke execute on function public.list_operating_costs(p_company_id uuid) from anon;
revoke execute on function public.list_recon_dispute_comments(p_dispute_id uuid) from anon;
revoke execute on function public.list_recon_disputes(p_company_id uuid) from anon;
revoke execute on function public.list_transporter_trip_earnings(p_company_id uuid) from anon;
revoke execute on function public.list_transporter_trip_pnl(p_company_id uuid) from anon;
revoke execute on function public.list_transporter_vehicle_cost_breakdown(p_company_id uuid) from anon;
revoke execute on function public.list_transporter_vehicle_costs(p_company_id uuid) from anon;
revoke execute on function public.log_fuel_entry(p_company_id uuid, p_vehicle_id uuid, p_litres numeric, p_cost_zar numeric, p_odometer_km numeric, p_station text, p_trip_id uuid, p_filled_at timestamp with time zone, p_notes text, p_id uuid) from anon;
revoke execute on function public.log_operating_cost(p_company_id uuid, p_vehicle_id uuid, p_kind text, p_cost_zar numeric, p_incurred_at timestamp with time zone, p_description text, p_trip_id uuid, p_id uuid) from anon;
revoke execute on function public.raise_recon_dispute(p_trip_id uuid, p_category text, p_reason text, p_claimed_tons numeric) from anon;
revoke execute on function public.set_recon_dispute_status(p_dispute_id uuid, p_status text, p_resolution text) from anon;
revoke execute on function public.set_route_transit_expectation(p_route_id uuid, p_hours numeric) from anon;
revoke execute on function public.update_my_company_profile(company_name_input text, whatsapp_number_input text, logo_url_input text, ceo_first_name_input text, ceo_last_name_input text, support_contact_email_input text, registration_number_input text, vat_number_input text, physical_address_input text) from anon;
revoke execute on function public.update_my_employee_profile(first_name_input text, last_name_input text, whatsapp_number_input text, profile_photo_url_input text, is_south_african_citizen_input boolean, id_number_input text, passport_or_workers_permit_input text, license_document_input text, id_document_url_input text, passport_document_url_input text, work_visa_document_url_input text, license_document_url_input text, date_of_birth_input date, residential_address_input text, emergency_contact_name_input text, emergency_contact_phone_input text, contact_email_input text, employment_start_date_input date, license_codes_input text, psira_grade_input text) from anon;
revoke execute on function public.upsert_compliance_document(p_company_id uuid, p_owner_type text, p_owner_id uuid, p_doc_type text, p_expires_at date, p_id uuid, p_title text, p_doc_number text, p_issued_at date, p_file_path text, p_notes text) from anon;
revoke execute on function public.upsert_my_compliance_document(p_doc_type text, p_id uuid, p_title text, p_doc_number text, p_issued_at date, p_expires_at date, p_file_path text, p_notes text) from anon;

-- ---------------------------------------------------------------------------
-- 2. Pin the mutable search_path
-- ---------------------------------------------------------------------------

alter function public.trip_is_on_time(
  p_left_at timestamp with time zone,
  p_offloaded_at timestamp with time zone,
  p_expected_transit_hours numeric
) set search_path = public;

-- ---------------------------------------------------------------------------
-- 3. Covering indexes for the six unindexed foreign keys
-- ---------------------------------------------------------------------------

create index if not exists fuel_entries_trip_id_idx
  on public.fuel_entries (trip_id);
create index if not exists monthly_targets_created_by_idx
  on public.monthly_targets (created_by);
create index if not exists monthly_targets_updated_by_idx
  on public.monthly_targets (updated_by);
create index if not exists production_entries_stockpile_id_idx
  on public.production_entries (stockpile_id);
create index if not exists target_cycles_created_by_idx
  on public.target_cycles (created_by);
create index if not exists vehicle_operating_costs_trip_id_idx
  on public.vehicle_operating_costs (trip_id);

-- ---------------------------------------------------------------------------
-- 4. auth_rls_initplan: evaluate auth.uid() once per statement, not per row
-- ---------------------------------------------------------------------------

drop policy if exists mine_hazards_insert_own on public.mine_hazards;
create policy mine_hazards_insert_own
  on public.mine_hazards
  for insert
  to authenticated
  with check (reported_by = (select auth.uid()));
