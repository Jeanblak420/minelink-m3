-- Manual-only chat links (Jean, 2026-07-14).
-- Reverses 20260713060000_auto_connect_business_parties.sql: companies must NOT
-- be chat-linked automatically when they do business. The super global admin
-- links every pair by hand. Also wipe existing links so the Connected list
-- starts clean (auto vs manual is not distinguishable, and the product intent
-- is a from-scratch manual build).

-- 1. Remove the auto-connect triggers.
drop trigger if exists connect_transaction_parties on public.transactions;
drop trigger if exists connect_dispatch_parties on public.request_dispatches;

-- 2. Remove the trigger functions and the shared helper (helper is only used by
--    the dropped triggers -- confirmed 2026-07-14).
drop function if exists public.trg_connect_transaction_parties();
drop function if exists public.trg_connect_dispatch_parties();
drop function if exists public.chat_connect_orgs(uuid, uuid, uuid);

-- 3. Start clean: remove every existing connection row.
delete from public.org_connections;
