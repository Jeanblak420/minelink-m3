# Edge Function Guide

Core onboarding, approvals, notifications, and fleet flows no longer require edge functions. The canonical platform uses database-owned RPCs plus realtime subscriptions instead.

## Current rule

- Do not deploy legacy webhook handlers for the core app flow.
- Keep `verify_jwt` enabled by default for any new function unless the function is a verified webhook endpoint or has a deliberate custom auth model.
- Prefer Postgres functions when the logic is transaction-heavy and tied closely to RLS-protected tables.

## When to add an edge function

Use an edge function only when the logic needs one of these:

- third-party API calls
- scheduled or background work that is not naturally row-triggered
- file processing outside what the client and database can safely handle
- webhook endpoints from external systems

## Legacy note

The old `employee-company-link`, `employee-webhook`, `company-webhook`, `notification-webhook`, and `dynamic-responder` implementations are archival only and are not part of the supported deployment path for the canonical platform.
