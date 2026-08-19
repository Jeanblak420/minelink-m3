# Coming Soon — placeholders

Premium branded holding screens for features that are planned but **not built**
(either unconfirmed scope or deferred). Use these instead of dead nav items.

- `screens.jsx` — reusable `ComingSoon` component (navy banner, eyebrow badge, blurb, feature bullets, "Notify me / Share feedback" actions, "in design — nothing here is live" note) plus two ready compositions:
  - `MarketplaceComingSoon` — Mineral Marketplace & Invoicing (map listings → buy → proforma → invoice, ZAR/15% VAT; from `Mine_Supplier_&_Buyer_features.txt`).
  - `HrComingSoon` — Employee / HR & Dismissal lifecycle (scope not confirmed).
- `index.html` — both shown inside the portal shell; nav items carry a "Soon" badge.

To gate any future nav item, point it at `<ComingSoon … />` with a title, blurb and bullets.
