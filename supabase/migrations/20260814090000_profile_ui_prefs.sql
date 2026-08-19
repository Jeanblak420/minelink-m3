-- Checklist S5-4 (P5-07) — UI preferences follow the USER, not the device.
--
-- `ConsolePrefs` persisted to SharedPreferences under
-- `ml.console.prefs.v1.<userId>`, which means a super admin who sets their
-- text scale to 1.3 on Windows opens the web build and gets 1.0 back. On a
-- product whose users move between a desktop in the office, a browser at the
-- weighbridge and a phone on site, a device-local accessibility setting is one
-- the user has to re-set at every surface — which in practice means they stop
-- setting it.
--
-- The column is jsonb rather than seven columns because these are presentation
-- preferences with no relational meaning: nothing joins on them, nothing
-- aggregates them, and the set will grow (S5-3 adds accent and sidebar skin to
-- the org portals, which previously had none of this).
--
-- The client keeps writing SharedPreferences as a cache, so a cold start still
-- paints the right accent before the profile row arrives and an offline device
-- keeps the user's settings. The profile row is the source of truth.

alter table public.profiles
  add column if not exists ui_prefs jsonb not null default '{}'::jsonb;

comment on column public.profiles.ui_prefs is
  'Presentation preferences that follow the user across devices (S5-4/P5-07): '
  'accent, sidebar skin, text scale, bold text, high contrast. Written only '
  'through set_my_ui_prefs(); SharedPreferences is a client-side cache, not '
  'the source of truth.';

-- Writes go through this, not a direct UPDATE, so the shape is validated in
-- one place and a client cannot store an unbounded text scale that then breaks
-- every layout it touches.
create or replace function public.set_my_ui_prefs(p_prefs jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_clean jsonb;
  v_scale numeric;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_prefs is null or jsonb_typeof(p_prefs) <> 'object' then
    raise exception 'ui_prefs must be a json object';
  end if;

  -- Clamp the text scale to the range the UI offers. The console slider is
  -- 0.85–1.3 and every layout sweep is run over exactly that band; a value
  -- outside it has never been rendered by anything.
  v_scale := coalesce((p_prefs->>'scale')::numeric, 1.0);
  if v_scale < 0.85 then v_scale := 0.85; end if;
  if v_scale > 1.3  then v_scale := 1.3;  end if;

  -- Whitelist. An unknown key is dropped rather than stored, so a stale client
  -- cannot silently accumulate junk on a row every newer client then reads.
  v_clean := jsonb_strip_nulls(jsonb_build_object(
    'accent',   p_prefs->>'accent',
    'sidebar',  p_prefs->>'sidebar',
    'scale',    to_jsonb(v_scale),
    'bold',     coalesce((p_prefs->>'bold')::boolean, false),
    'contrast', coalesce((p_prefs->>'contrast')::boolean, false)
  ));

  update public.profiles
     set ui_prefs = v_clean,
         updated_at = now()
   where id = auth.uid();

  return v_clean;
end;
$$;

revoke execute on function public.set_my_ui_prefs(jsonb) from public;
grant  execute on function public.set_my_ui_prefs(jsonb) to authenticated;

comment on function public.set_my_ui_prefs(jsonb) is
  'S5-4: writes the calling user''s presentation preferences. Clamps scale to '
  'the 0.85-1.3 band the UI offers and drops unknown keys, so a stale client '
  'cannot store a value no layout has ever been rendered at.';
