One-liner: Renders an expressive soft-shaded "3D" vector icon — the MineLink portal's marketing/feature icon set (companion to the flat Material Symbols `Icon`).

```jsx
import { Icon3D } from './Icon3D';

<Icon3D name="shipment" size={72} />
<Icon3D name="weighbridge" size={96} title="Weighbridge" />
```

Pure inline SVG — smooth gradients, a real thickness/side face and a soft contact shadow give the 3D illusion with zero image assets and no WebGL, so icons stay crisp at any size. No font `<link>` required (unlike flat `Icon`).

Use `Icon3D` for hero tiles, dashboard headers, empty states, onboarding and feature wells. Use the flat `Icon` (Material Symbols) for nav, buttons and dense/inline UI.

Names: dashboard, shipment, route, weighbridge, map, contract, security, inventory, alerts, payment, team, settings, companies, mine, token, warning, energy, driver, supervisor, buyer, console, stockpile, active, expired, suspended, history, register, export. Import `ICON3D_NAMES` for the full list. Unknown names fall back to a neutral cube.

**One 3D icon per identity concept — reuse these, don't invent flat one-offs.** Every org type, company type and user/employee role has a canonical Icon3D concept, so any new screen stays consistent automatically. Prefer wiring surfaces through `IconWell` / `SectionTitle` (they auto-upgrade any Material Symbols name that has an entry in `ICON3D_ALIASES`):

- Org types — Mine/Supplier → `mine`, Buyer → `buyer`, Transporter → `shipment`, Super-admin/platform → `console`.
- Roles — Driver → `driver`, Supervisor/Foreman → `supervisor`, Load Controller → `weighbridge`, Security Guard → `security`, Admin/Management → `settings`, Procurement → `buyer`, Team → `team`.
- Domain objects — Stockpile/ore → `stockpile`, Inventory → `inventory`, Contract → `contract`, Token → `token`.
- Status & utility — Active → `active`, Expired → `expired`, Suspended → `suspended`, Audit/history/timeline → `history`, Register/add company → `register`, Open/manage/external → `export`.

This set is the whole family: every icon on a MineLink surface should come from it (via `resolveIcon3D` / the display primitives), including status counts, quick-action tiles and banners — not just hero wells.

Need a concept the set doesn't cover yet? Add a new glyph to `ICONS` in `Icon3D.jsx` (same recipe: `Shadow` + a darker base shape translated `(0,4–5)` for thickness, a `linearGradient` front face using the palette hues — blue `#7ea6ff→#2f6bef`, cyan `#5fe0f4→#0aa3c4`, green `#5ceb9a→#16a04c`, amber `#ffd95e→#f7b733`, slate `#a7b6ca→#5a6b85` — a side/shaded face, and a soft white highlight stroke), give it a unique gradient id (`i3-<key>`), then add the Material Symbols → concept entries to `ICON3D_ALIASES`. Never draw a bespoke flat SVG for an identity surface.
