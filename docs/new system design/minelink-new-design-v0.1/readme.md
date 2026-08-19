# MineLink Design System

A design system for **MineLink** — a mineral-logistics platform that connects
**Mines/Suppliers**, **Buyers** and **Transporters** around the movement of bulk
minerals: loading at the mine, gate security, trucking, waybills, live truck
tracking, and tonnage reconciliation. (The product was previously branded
*MineralGuide*; "LoadTrack" is the working name on the redesign mockups for the
premium portal chrome.)

The system captures the **premium "LoadTrack" redesign**: a deep-navy portal
shell, a cyan brand accent, soft slate surfaces, lifecycle status pills, animated
KPI tiles, slide-over record panels, and live maps — across every user role and
org type plus the Super Global Serial Admin console.

## Sources (store for reference — reader may not have access)

- **Flutter codebase** (source of truth): a Flutter/Dart app, mounted as `frontend files/`. Theme: `lib/core/theme/app_theme.dart`; portal chrome & colors: `lib/features/portal/portal_colors.dart`, `portal_scaffold.dart`, `portal_navigation.dart`; premium widgets: `lib/features/portal/widgets/premium_overview_widgets.dart`.
- **GitHub:** `Blak-42069/MineralGuide-05-05-206` (private — was not reachable during this build; reconnect the GitHub App to import directly. The mounted Flutter folder covered the same code.)
- **Redesign mockups:** PNGs under `assets/reference/` (buyer / transporter / mine / security screens) and the `MineLink planning.pptx` deck — both supplied as uploads.
- **Implementation guides:** `new-look-styling-&-extra-features.md`, `new-changes-implementations…todo'slist.md`, `Task-list-for=Super_Global_Serial-Admin…md`, `work_flow_test_accounts.md`.

> Explore the GitHub repo for deeper fidelity when building new MineLink work — it
> holds the full screen and provider code beyond what the mockups show.

## Org types & roles (drive what each portal shows)

- **Mine / Supplier** — Owner, Admin, Management, **Security** (gate, mobile), **Controller** (load desk). Security & Controller are single-screen, locked roles.
- **Buyer** — Owner, Admin, Management.
- **Transporter** — Owner, Admin, Management, **Driver** (mobile routes).
- **Super Global Serial Admin** (`superGlobalSerialAdminMain`) — every company links here; manages tokens, seat serials, seat limits and anti-abuse rules.

---

## CONTENT FUNDAMENTALS

**Voice.** Plain, operational, logistics-floor English — not marketing. Labels are
short noun phrases: "Tons Allocated", "Pending Recons", "Trucks at Mine — Ready for
Loading", "Mark Arrived", "Mark Left", "Record Load". The product addresses the
user's assets directly ("your routes", "your entire fleet") and otherwise stays
impersonal and instructional.

**Casing.**
- Page & section titles: Title-ish but mostly **sentence case** with a leading cap — "Buyer Portal", "Loading activity", "Trucks at Mine — Ready for Loading".
- KPI / field labels: Title Case or sentence case — "Active Waybills", "Avg Tons / Load".
- Status pills: **UPPERCASE** — `OTW TO LOADING`, `AT MINE`, `LOADED`, `MAINTENANCE`.
- Table column headers: **UPPERCASE**, letter-spaced — `TRUCK / DRIVER`, `ROUTE`, `STATUS`, `UPDATED`.

**Numbers & units.** Tonnage uses a space + lowercase "t" — `33.2 t`, `1,240 t`;
thousands grouped with commas; animated count-up on headline values. Plates and
ticket/serial numbers are **monospace** — `CDF 789 LP`, `WB-0045`. Times are 24h
mono — `09:19`. Deltas read "▲ 12.5t vs yesterday".

**Tone of helper copy.** One calm sentence describing what a screen does: "Live map
showing all trucks assigned to your routes — see position and current status." Em
dashes separate a label from its qualifier ("Mine Control — Record loads and
tonnage"). Empty states are honest and instructive: "No trucks have GPS coordinates
recorded. GPS is updated when drivers report via the Driver App."

**Emoji:** none. The interface uses Material Symbols icons, never emoji.

---

## VISUAL FOUNDATIONS

**Color.** A slate-neutral base with one confident **cyan accent (`#00B5D8`)** and a
**deep-navy chrome (`#0B192E → #020617`)** for the sidebar. Backgrounds are off-white
slate-50 (`#F8FAFC`); cards are pure white. Status is carried by a fixed hue set:
blue = in transit/OTW, amber = at mine, green = loaded/available/confirmed, orange =
maintenance & "mark departed", red = declined/error. The Material seed is teal
`#0F6E8C`; cyan is the brand-forward derivative used everywhere interactive.

**Type.** App ships Material default (Roboto); the redesign reads as a cleaner
geometric sans, so the system standardises on **Plus Jakarta Sans** (UI/display) with
**extrabold (800)** headline numerals and feature-card titles, and **JetBrains Mono**
for plates, tickets, serials, times and tonnage codes. *(Substitution — no brand
font files were supplied; see Caveats.)*

**Backgrounds.** Flat slate fills — no photographic or illustrated backgrounds. Maps
use a faint grid "paper" texture with floating truck pins/cards. The one decorative
gradient is the navy sidebar (and a cyan→navy "Request buyers" promo panel). Overview
hero tiles use a subtle cyan-tinted gradient wash, never a saturated one.

**Cards.** White, **20px** radius (hero/overview) / 16px (standard), 1px slate border
(`~#E7EDF3`), soft low shadow (`0 1px 3px rgba(15,23,42,.06)`). Hero overview tiles add
a cyan-tinted gradient, an accent border and a cyan-tinted shadow, plus a short 44px
accent rule under the title. Feature cards carry a tinted **icon chip** (cyan / amber /
green / blue) and an outlined "Open →" button.

**Icon wells.** KPI and feature icons sit in rounded-square tinted wells (11–16px
radius) — cyan by default, amber/green/blue to vary rhythm across a row.

**Status pills.** Fully-rounded (pill radius), fg/bg tonal pair, 12px **700-weight**,
slight letter-spacing, optional leading dot. This is the single most repeated motif.

**Borders & dividers.** Hairline 1px slate (`#E2E8F0` / `#E9EEF4`). Inputs are
**filled** (slate-100) with a transparent border that turns **cyan** on focus (red on
error); 12px radius, ≥48px tall.

**Buttons.** 12px radius, 700 weight, ≥48px tall (touch). Primary = solid cyan with a
soft cyan shadow; **go** = green gradient (confirm load / mark arrived); **leave** =
orange gradient (mark departed); plus tonal (white pill on tinted cards), outline,
ghost, danger. Hover lifts the button 1px; press settles it.

**Elevation.** A soft, low-contrast slate shadow ladder (xs → lg) plus a cyan-tinted
"hero" shadow and a strong left-cast "drawer" shadow for slide-overs. Nothing harsh.

**Radii.** chips/badges 8 · buttons/inputs/nav-tiles 12 · cards/dialogs 16 ·
hero tiles 20 · bottom sheets 24 · pills/avatars 999.

**Motion.** Calm and functional. Sidebar collapse 260ms ease-out-cubic; nav-tile
hover 180ms; KPI count-up 850ms ease-out; modals fade+pop (180–220ms); slide-overs
translate in 280ms ease-out-cubic. No bouncy or infinite decorative animation.

**Hover / press.** Hover = a faint accent wash (nav tiles) or a 1px lift (buttons/
cards); active nav tile = cyan text+icon, a 16%-cyan fill and a 3px cyan left-border.
Press settles transforms back to rest.

**Layout.** Persistent navy sidebar (268px expanded / 76px collapsed rail with
tooltips) + a white app bar (home icon, title + "workspace · operator · role"
subtitle, notification bell with cyan dot) + a slate content area, max-width 1280,
28px padding. KPI cards run four-up; feature cards three- or four-up.

**Transparency / blur.** Used sparingly — modal/slide-over scrims are ~32–45% navy;
the notification dot has a 2px surface ring. No glassmorphism.

---

## ICONOGRAPHY

The portal has **two icon languages**, each with its own job:

**1. Material Symbols Rounded — `Icon`** (functional UI). The Flutter app uses
Material `Icons.*_rounded` / `*_outlined`; the design system loads the font from
Google Fonts and exposes it via the `Icon` component. Use for nav, buttons and
dense/inline UI. **No emoji, no hand-drawn SVGs.**

- **Style:** outlined by default (`fill=0`); filled (`fill=1`) for active/emphasis (active nav item, status truck pins, brand mark).
- **Common glyphs:** `dashboard`, `local_shipping`, `alt_route`, `route`, `balance`, `map`, `place`, `handshake`, `security`, `shield`, `tune`, `inventory_2`, `conveyor_belt`, `description`, `groups`, `admin_panel_settings`, `key`, `notifications`, `login`/`logout`, `check_circle`, `warning`.
- **Dimensional flag:** `Icon` also takes `dimensional` + `tone` for a quick extruded look on a single glyph — but for expressive surfaces prefer `Icon3D` below.

**2. Icon3D — `Icon3D`** (expressive / marketing). A soft-shaded faux-3D vector
set: smooth gradients, a real thickness/side face and a soft contact shadow give
the illusion of a rendered 3D object, but every icon is **pure inline SVG — no
image assets, no WebGL** — so they stay crisp at any size and cost nothing at
runtime. Use for hero tiles, dashboard headers, empty states, onboarding and
feature wells. See `guidelines/brand-iconography.card.html`.

- **Names:** `dashboard`, `shipment`, `route`, `weighbridge`, `map`, `contract`, `security`, `inventory`, `alerts`, `payment`, `team`, `settings` (`ICON3D_NAMES` for the list).
- **Usage:** `<Icon3D name="shipment" size={72} />`.

**Icon wells — always use `IconWell` (from `window.MLShell`).** Any "icon in a
chip" surface (stat tiles, feature tiles, list-row identity icons, hero headers,
section titles) must go through `IconWell`, never a hand-rolled `<div class=well><Icon/></div>`.
It auto-resolves the rule in ONE place: if the icon maps to a 3D concept
(`ICON3D_ALIASES`) it renders the expressive **Icon3D** with no background chip;
otherwise it falls back to the flat tinted well. So every new display well across
the portals is consistent automatically.

- **Usage:** `<IconWell icon="local_shipping" tone="blue" size={48} />`. Pass `force="flat"` to opt out (rare — when the chip's color itself carries meaning).
- **`FeatureCard` / `StatCard` / `SectionTitle`** already route through this logic internally — just pass an `icon` and mapped ones upgrade to 3D.
- **Flat-for-functional / 3D-for-identity:** functional glyphs (add, search, chevrons, more_vert, download, person, mail, arrow_*, check_circle, nav tabs, radio selectors) have no 3D alias and intentionally stay flat Material Symbols. Identity/concept glyphs (shipment, route, mine, companies, token, warning, energy…) upgrade to Icon3D.
- **Adding a new 3D icon:** add the glyph to `ICONS` in `Icon3D.jsx`, then map its Material Symbols name(s) in `ICON3D_ALIASES`. Every well using that name upgrades automatically — no per-screen edits.

- **Brand mark:** a cyan rounded-square (gradient `#22C2DE→#0496B6`) containing a filled `local_shipping`, paired with the "MineLink" wordmark (extrabold). See `guidelines/brand-logo.card.html`.
- **Legacy logo:** the old crystal "The Mineral Guide" mark is kept at `assets/legacy-mineralguide-logo.png` for reference only — not part of the current system.

---

## INDEX

**Root**
- `styles.css` — global entry (import manifest). Consumers link this.
- `tokens/` — `colors.css`, `semantic.css`, `typography.css`, `spacing.css`, `radius.css`, `fonts.css`.
- `assets/` — `legacy-mineralguide-logo.png`, `reference/` (redesign mockups).
- `SKILL.md` — portable skill wrapper for Claude Code.

**Components** (`window.MineLinkDesignSystem_…`)
- `components/core/` — `Icon`, `Button`, `StatusBadge`, `PlatePill`, `Avatar`, `Card`, `StatCard`, `FeatureCard`.
- `components/forms/` — `Input`, `Select`, `Switch`, `Checkbox`, `RadioGroup`, `Segmented`, `FileUpload`.
- `components/navigation/` — `Tabs` (underline + pill variants).
- `components/feedback/` — `Toast` / `ToastStack`, `Tooltip`, `EmptyState`, `NotificationCard`, `NotificationBell`.

**Foundation cards** (`guidelines/`) — Colors (brand, navy, slate, status), Type
(display, body, mono), Spacing (scale, radius/elevation), Brand (logo, iconography).

**UI kits** (`ui_kits/`) — each composes the shared chrome `ui_kits/shared/shell.jsx`
(`PortalShell`, `Sidebar`, `AppBar`, `DataTable`, `SectionTitle`, `MapCanvas`,
`SlideOver`, `Modal`):
- `buyer/` — Buyer portal (dashboard, routes, waybills, recons, live map).
- `transporter/` — Transporter portal (fleet, positions map, recons).
- `mine-supplier/` — Mine/Supplier (overview, load control, mobile gate security, buyers).
- `super-admin/` — Super Global Serial Admin (orgs, tokens & seat serials, live countdown, transportation-requests inbox).
- `auth/` — sign-in, WhatsApp OTP, reset, org registration.
- `driver/` — Driver mobile app (current trip, POD upload).
- `chat/` — **Messages / Chat** (replaces the old Comms hub): company-scoped contacts, Mine-Link admins auto-added, super-admin org-to-org grant/revoke with blocked-history banner.

---

## CAVEATS / ASK

- **Fonts substituted.** No brand font files were provided. The app ships Roboto (Material default) but the mockups read as a geometric sans, so I used **Plus Jakarta Sans + JetBrains Mono**. → *Please confirm, or send the intended font files.*
- **GitHub repo not reachable** this build (`Blak-42069/MineralGuide-05-05-206`, private). I built from the mounted Flutter code + mockups. → *Reconnect the GitHub App if you want me to import the exact repo.*
- **Brand name.** Mockups say "LoadTrack"; the codebase app name is **MineLink**. I used **MineLink** as the brand. → *Confirm the final product name.*
- Maps are stylised placeholders (no live tiles); the app shows real GPS only when drivers report. PPTX deck details beyond the visual redesign were treated as out of scope per the styling notes.
