# Canonical Realtime Setup Guide

Database webhooks are no longer part of the supported production setup for this project.

## Current model

- CRUD syncing uses Postgres Changes through the `supabase_realtime` publication.
- Workflow writes use Postgres functions and RPCs defined in [supabase/migrations/20260327000100_canonical_platform_reset.sql](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/supabase/migrations/20260327000100_canonical_platform_reset.sql).
- Chat collaboration can use Presence and Broadcast where needed.

## What to verify instead of webhooks

1. Confirm the canonical migration has been applied.
2. Confirm the `supabase_realtime` publication includes the business tables.
3. Confirm RLS and storage policies are present.
4. Confirm the Flutter client is using `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` defines.

## Legacy note

The older `employee-company-link`, `employee-webhook`, `company-webhook`, and
`notification-webhook` flow is archived and should not be used for the
canonical platform. Notification fallback in the Flutter app now uses the
canonical `create_actioned_notification` RPC instead of any webhook path.
