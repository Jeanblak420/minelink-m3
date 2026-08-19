# Supabase Edge Functions

Only one edge function remains in the supported runtime path: `company-user-admin`.

The canonical platform now keeps onboarding, notifications, company/employee
workflow changes, cleanup, and realtime wiring inside Postgres migrations and
RPCs. The older webhook-era function set has been removed from the repo and
retired from the live project.

## Supported Function

### company-user-admin

This function allows a company owner or active company manager to create
employee auth users from the company management screen. It validates the
caller's bearer token inside the function and uses the service role key only
for the auth admin step.

Deploy it with gateway JWT verification disabled:

```bash
supabase functions deploy company-user-admin --no-verify-jwt
```

This is intentional because the function performs its own caller validation and
rejects unauthenticated requests in the handler body.

## Deployment

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase functions deploy company-user-admin --no-verify-jwt
```
