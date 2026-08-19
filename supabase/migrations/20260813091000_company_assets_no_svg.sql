-- Checklist S2-5a — drop `image/svg+xml` from the `company_assets` bucket.
--
-- `company_assets` is the ONE bucket the platform serves publicly (client
-- ruling: a company logo is content a company puts on its own letterhead, so
-- public is correct for it — S2-5). `StorageAssetService._isPublicBucket`
-- returns true for this bucket and nothing else.
--
-- SVG is not an image format in the sense the other three are: it is an XML
-- document that may carry <script>, event handlers and external references.
-- Served from the storage origin with `Content-Type: image/svg+xml`, an
-- uploaded .svg executes in that origin — stored XSS, reachable by anyone with
-- the URL because the bucket is public. PNG, JPEG and WebP cannot do this.
--
-- Cost of removing it: nil, verified rather than assumed. The bucket holds
-- exactly one object — `company_logos/167aba53-…/logo.jpg`, image/jpeg,
-- 257,523 bytes — so no stored object is invalidated, and no upload path in
-- the app offers SVG.
--
-- Reversible in one statement if a vector logo is ever genuinely required, but
-- the right fix then is a separate origin for public assets, not re-admitting
-- a script-capable type to the origin the app is served from.
--
-- Client ruling 2026-08-13.

update storage.buckets
set allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp']
where id = 'company_assets';
