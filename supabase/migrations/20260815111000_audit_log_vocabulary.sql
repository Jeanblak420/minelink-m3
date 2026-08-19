-- 20260815111000_audit_log_vocabulary.sql
--
-- Second and third defects behind 20260815110000. Fixing the alias collision in
-- `create_company_token_request` let the token_requests INSERT through, and the
-- call then failed twice more on the audit_logs write that follows it. Both are
-- CHECK-constraint vocabularies that disagree with the code that feeds them —
-- the same shape as notifications_type_check (20260815109000), now the fifth and
-- sixth instance on this project.
--
-- 1. actor_platform_role
--
--    CHECK allowed: superGlobalSerialAdminMain, superGlobalSerialAdminMainChild,
--                   companyManagement, companyAdmin, system
--    Actually held by profiles.platform_role, measured: normalUser (114),
--                   superGlobalSerialAdminMain (2). Nothing else exists.
--
--    The column is fed from profiles.platform_role by both emitters
--    (`create_company_token_request`, `insert_audit_log`), each via
--    `coalesce(actor_role, 'normalUser')`. So the two vocabularies overlap on a
--    single value and every company user is rejected: 23514 on any audit write
--    by a non-platform-admin. All 15 existing rows belong to the two super
--    admins, which is why this never surfaced.
--
--    `companyAdmin` / `companyManagement` are not platform_role values — no
--    profile has ever held one. They are the artifact here, not `normalUser`.
--    A column named actor_platform_role, sourced from platform_role, must
--    admit the platform roles that exist. They are kept rather than dropped:
--    7 live rows still carry superGlobalSerialAdminMainChild from the removed
--    child-admin concept, and dropping a value in use rewrites history.
--
-- 2. target_type
--
--    CHECK allowed: organization, user, serialToken, seat, seatRequest,
--                   childAdmin, system
--    `create_company_token_request` writes 'tokenRequest'. The table it targets
--    is public.token_requests; 'seatRequest' is the older name for the same
--    thing, from when the feature was seats-only. Added rather than renamed for
--    the same reason as above — 'seatRequest' and 'childAdmin' may sit on rows.
--
-- Both widened, nothing removed. Additive only.

alter table public.audit_logs
  drop constraint if exists audit_logs_actor_platform_role_check;

alter table public.audit_logs
  add constraint audit_logs_actor_platform_role_check
  check (actor_platform_role = any (array[
    'superGlobalSerialAdminMain'::text,
    'superGlobalSerialAdminMainChild'::text,
    'companyManagement'::text,
    'companyAdmin'::text,
    'normalUser'::text,
    'system'::text
  ]));

alter table public.audit_logs
  drop constraint if exists audit_logs_target_type_check;

alter table public.audit_logs
  add constraint audit_logs_target_type_check
  check (target_type = any (array[
    'organization'::text,
    'user'::text,
    'serialToken'::text,
    'seat'::text,
    'seatRequest'::text,
    'tokenRequest'::text,
    'childAdmin'::text,
    'system'::text
  ]));

comment on constraint audit_logs_actor_platform_role_check on public.audit_logs is
  'Vocabulary must cover every value profiles.platform_role can hold - normalUser '
  'is the role of every company user and was missing, so no company actor could '
  'write an audit row. See 20260815111000.';
