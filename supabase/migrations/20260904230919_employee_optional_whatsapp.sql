-- 20260904230919_employee_optional_whatsapp.sql
--
-- Makes whatsapp_number optional when creating an employee. A transporter owner
-- can now add an employee via email alone, WhatsApp alone, or both. The only
-- requirement is that at least one of email/WhatsApp is provided (validated at
-- the edge-function layer).
--
-- WHY: The current function raises 'WhatsApp number is required' if
-- whatsapp_number_input is null. The edge function now accepts requests where
-- only an email is provided (no WhatsApp), so this gate must be relaxed.
--
-- This is a surgical substitution on the existing function body (per CLAUDE.md §6):
-- the validation block is removed, and the INSERT handles a NULL whatsapp_number.
do $$
declare
  v_def text;
  v_new text;
  -- Anchor: the three-line block that validates whatsapp_number_input
  v_anchor text := 'if nullif(trim(coalesce(whatsapp_number_input, '''')), '''') is null then'
              || chr(10)
              || '    raise exception ''WhatsApp number is required'';'
              || chr(10)
              || 'end if;';
  v_repl text := '-- whatsapp_number_input is optional: validated at the edge-function layer';
  v_hits int;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'create_company_managed_employee';

  if v_def is null then
    raise exception 'create_company_managed_employee not found';
  end if;

  v_hits := (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor);
  if v_hits <> 1 then
    raise exception 'expected exactly 1 whatsapp_number_input validation anchor, found %', v_hits;
  end if;

  v_new := replace(v_def, v_anchor, v_repl);
  execute v_new;
end
$$;

comment on function public.create_company_managed_employee(uuid, text, text, text, text) is
  'Creates an admin-managed employee. whatsapp_number_input is optional (validated at the edge-function layer — at least one of email/WhatsApp required). Sets profiles.must_change_password = true on the conflict path (S2-9, 2026-08-15).';