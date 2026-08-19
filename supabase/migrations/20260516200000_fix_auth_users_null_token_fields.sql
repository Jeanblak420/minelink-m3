-- Fix NULL token fields in auth.users that break GoTrue logins.
--
-- Background:
--   Supabase's GoTrue auth service scans columns like confirmation_token,
--   recovery_token, email_change_token_new, email_change_token_current,
--   phone_change_token, reauthentication_token, email_change, and phone_change
--   into Go strings (not sql.NullString). When any of these columns are NULL
--   (typically from users inserted via custom SQL/seeds that bypassed GoTrue
--   defaults), every auth request that touches that user row fails with:
--     500: Database error querying schema
--     "error finding user: sql: Scan error on column index N, name \"<col>\":
--      converting NULL to string is unsupported"
--
--   This produces 500s on /token (login) and /recover (password reset) for the
--   affected user, even though the password and email are correct.
--
-- Fix:
--   Coalesce NULL -> '' on all of GoTrue's expected non-nullable string token
--   columns. This is the standard remediation recommended by Supabase support.
--   The UPDATE is idempotent and safe to re-run.

UPDATE auth.users
SET
  confirmation_token         = COALESCE(confirmation_token, ''),
  recovery_token             = COALESCE(recovery_token, ''),
  email_change_token_new     = COALESCE(email_change_token_new, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  phone_change_token         = COALESCE(phone_change_token, ''),
  reauthentication_token     = COALESCE(reauthentication_token, ''),
  email_change               = COALESCE(email_change, ''),
  phone_change               = COALESCE(phone_change, '')
WHERE
     confirmation_token         IS NULL
  OR recovery_token             IS NULL
  OR email_change_token_new     IS NULL
  OR email_change_token_current IS NULL
  OR phone_change_token         IS NULL
  OR reauthentication_token     IS NULL
  OR email_change               IS NULL
  OR phone_change               IS NULL;
