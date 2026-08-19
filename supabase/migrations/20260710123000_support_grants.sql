-- ============================================================================
-- Grant table privileges on the support_* tables to the `authenticated` role.
-- The tables were created via the Management API and did not inherit the
-- default GRANTs, so every client query failed with "permission denied"
-- (RLS still governs which ROWS are visible; this only opens the tables).
-- ============================================================================
grant select, insert, update, delete on public.support_tickets         to authenticated;
grant select, insert, update, delete on public.support_ticket_messages to authenticated;
grant select, insert, update, delete on public.support_ticket_events   to authenticated;
grant select, insert, update, delete on public.support_notifications   to authenticated;
grant select, insert, update, delete on public.support_inbox_prefs     to authenticated;

-- Refresh the PostgREST schema cache so the tables/RPCs are exposed.
notify pgrst, 'reload schema';
