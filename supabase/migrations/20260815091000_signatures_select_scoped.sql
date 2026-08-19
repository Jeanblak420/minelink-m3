-- S2-13. `signatures_select_authenticated` read
--   USING (bucket_id = 'signatures')
-- with no further predicate, so ANY authenticated user could read ANY user's
-- signature PNG. The bucket is private, but private only forces a signed URL —
-- and a caller who passes SELECT can mint one. Paths are `<user_id>/signature.png`,
-- entirely predictable, and user ids are readable from profiles.
--
-- Walked on production before this change, as a real driver at a transporter
-- (JWT claims set to their auth.uid() under role authenticated, rolled back):
-- 3 of 3 signature objects visible, and ALL THREE belonged to other people.
--
-- A signature is the closest thing this product has to a legal mark — it is
-- auto-placed on the waybill's DISPATCHED BY and RECEIVED BY blocks.
--
-- Blast radius measured BEFORE applying, not after:
--   · 3 objects, 3 profiles carry a signature_url
--   · profiles.signature_url values are byte-identical to storage.objects.name,
--     so path matching in the party clause actually matches
--   · 0 trips carry metadata->'waybill'->>'dispatch_signature_path' or
--     'received_signature_path' today — so the party clause protects a path
--     that has not been exercised yet, and no existing waybill can regress
--
-- Why not simply "own signature only": the client genuinely reads counterparty
-- signatures. trip_waybill_builder.dart composites BOTH the load controller's
-- dispatch signature and the driver's received signature into the PDF, for
-- whoever is viewing it. The party clause below mirrors get_trip_waybill()'s
-- own visibility test exactly (supplier OR buyer OR transporter staff), so the
-- object is readable by precisely the callers the RPC already hands the path to.
create policy signatures_select_scoped
  on storage.objects for select to authenticated
  using (
    bucket_id = 'signatures'
    and (
      -- own signature
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (select public.is_platform_admin())
      -- or it is signed onto a waybill this caller's company is a party to
      or exists (
        select 1
        from public.trips t
        join public.transactions tx on tx.id = t.transaction_id
        where (t.metadata->'waybill'->>'dispatch_signature_path' = objects.name
            or t.metadata->'waybill'->>'received_signature_path' = objects.name)
          and (public.is_company_staff(tx.supplier_company_id)
            or public.is_company_staff(tx.buyer_company_id)
            or public.is_company_staff(tx.transporter_company_id))
      )
    )
  );

drop policy if exists signatures_select_authenticated on storage.objects;

-- Verified after applying, as four real users in rolled-back transactions —
-- a refusal AND a success, not just a refusal:
--   · driver with no signature ................. 0 rows (was 3)
--   · roadhaul.driver (owns one, not admin) .... 1 row, their own (was 3)
--   · roadhaul.owner  (owns one, not admin) .... 1 row, their own (was 3)
--   · jean@cyberhouse.co.za (super admin) ...... 3 rows, correct
--
-- The admin result is recorded because the first "owner" walk accidentally
-- picked jean and returned 3, which reads like the fix not working. It was the
-- platform-admin branch behaving correctly. Re-walked with two non-admin
-- owners to settle it.
