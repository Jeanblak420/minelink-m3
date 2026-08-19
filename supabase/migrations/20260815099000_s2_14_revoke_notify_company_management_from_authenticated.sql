-- Follow-up to 20260815098000, whose revoke was incomplete — and the
-- incompleteness is the point of keeping this as its own file.
--
-- That migration ran `revoke execute … from public`, which DID work (anon lost
-- it). But `authenticated` still returned true from has_function_privilege,
-- and a re-walk confirmed a driver could still spoof a notification into
-- another company's management inbox: "SENT — still open".
--
-- The reason is an EXPLICIT grant to `authenticated`, held independently of
-- the PUBLIC grant. Both have to be revoked.
--
-- This is the exact mirror of the mistake at 20260815092000, where revoking
-- from the named roles did nothing because the privilege was held via PUBLIC.
-- Together they make the rule: a Postgres EXECUTE privilege can be held via
-- PUBLIC *and* via a direct role grant, and removing one tells you nothing
-- about the other. Re-read has_function_privilege() after every revoke.
revoke execute on function public.notify_company_management(
  uuid, text, text, text, text, uuid, text, jsonb) from authenticated;

-- Verified after applying, in rolled-back transactions:
--   driver calls it directly        REFUSED — "permission denied for function
--                                   notify_company_management"
--   definer context (the 16 callers) 2 notification rows written — unaffected,
--                                   because they execute as postgres, not as
--                                   the calling role
