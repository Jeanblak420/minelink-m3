-- Fire the Supervisor/Foreman "start building the stockpile" notification on
-- linking (CLAUDE.md §4 "On approval + mine selection — fire the Supervisor
-- notification FIRST"). Re-creates link_and_dispatch_request with a best-effort
-- notification block appended — a notify failure never rolls back the link.

begin;

create or replace function public.link_and_dispatch_request(
  p_id uuid,
  p_supplier_company_id uuid,
  p_agreed_price numeric,
  p_admin_margin numeric,
  p_transporter_ids uuid[]
) returns transportation_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.transportation_requests;
  v_tid uuid;
  v_transporter_price numeric;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the MineLink representative may link and dispatch requests';
  end if;
  if not exists (select 1 from public.transportation_requests where id = p_id) then
    raise exception 'Request % not found', p_id;
  end if;
  if p_supplier_company_id is null then
    raise exception 'Select the supplying mine first';
  end if;
  if p_transporter_ids is null or array_length(p_transporter_ids, 1) is null then
    raise exception 'Select at least one transporter to dispatch to';
  end if;
  if p_agreed_price is null or p_admin_margin is null then
    raise exception 'Enter the agreed price per ton and your margin';
  end if;
  if p_agreed_price < 0 or p_admin_margin < 0 then
    raise exception 'Price and margin must be zero or positive';
  end if;
  if p_admin_margin > p_agreed_price then
    raise exception 'Margin cannot exceed the agreed price';
  end if;

  v_transporter_price := p_agreed_price - p_admin_margin;

  insert into public.margin_ledger (
    request_id, supplier_company_id, agreed_price_per_ton,
    admin_margin_per_ton, transporter_price_per_ton, currency, created_by
  ) values (
    p_id, p_supplier_company_id, p_agreed_price,
    p_admin_margin, v_transporter_price, 'ZAR', auth.uid()
  );

  foreach v_tid in array p_transporter_ids loop
    insert into public.request_dispatches (
      request_id, transporter_company_id, dispatched_by, transporter_price_per_ton
    ) values (p_id, v_tid, auth.uid(), v_transporter_price)
    on conflict (request_id, transporter_company_id) do update
      set transporter_price_per_ton = excluded.transporter_price_per_ton;
  end loop;

  update public.transportation_requests set
    supplier_company_id = p_supplier_company_id,
    status = 'linked',
    reviewed_by = auth.uid(),
    reviewed_at = timezone('utc', now())
  where id = p_id
  returning * into v_row;

  -- Best-effort supervisor/foreman notification (never fail the link on error).
  declare
    v_buyer_name text;
    v_supplier_name text;
    v_transporter_names text;
    v_msg text;
    v_title text := 'New stockpile to prepare';
    v_rec record;
  begin
    select company_name into v_supplier_name
      from public.companies where id = p_supplier_company_id;
    select company_name into v_buyer_name
      from public.companies where id = v_row.buyer_company_id;
    select string_agg(company_name, ', ') into v_transporter_names
      from public.companies where id = any(p_transporter_ids);

    v_msg := coalesce(nullif(v_row.tons_available, ''), 'The agreed tonnage')
      || ' of ' || coalesce(v_row.commodity, 'product')
      || ' for ' || coalesce(v_buyer_name, 'the buyer')
      || ' has been approved by ' || coalesce(v_supplier_name, 'the mine')
      || '. Please start adding it to a stockpile, add it to your stockpile list, '
      || 'and update it every time you add product to the physical stockpile for '
      || coalesce(v_transporter_names, 'the transporter')
      || ' so they know when their trucks can collect.';

    -- Mine company owner.
    perform public.create_notification_internal(
      (select user_id from public.companies where id = p_supplier_company_id),
      p_supplier_company_id, null, v_title, v_msg, 'stockpile_prepare',
      null, auth.uid(), 'supervisorForeman', 'mineSupplier', 'high',
      jsonb_build_object('request_id', p_id)
    );
    -- Supervisors/foremen (and admins/management) of the mine.
    for v_rec in
      select e.user_id, e.role
      from public.employees e
      where e.company_id = p_supplier_company_id
        and e.role in ('supervisorForeman', 'admin', 'management')
        and e.status = 'active'
        and coalesce(e.is_dismissed, false) = false
    loop
      perform public.create_notification_internal(
        v_rec.user_id, p_supplier_company_id, null, v_title, v_msg, 'stockpile_prepare',
        null, auth.uid(), v_rec.role, 'mineSupplier', 'high',
        jsonb_build_object('request_id', p_id)
      );
    end loop;
  exception when others then
    null; -- notification is best-effort; the link already succeeded
  end;

  return v_row;
end;
$function$;

commit;
