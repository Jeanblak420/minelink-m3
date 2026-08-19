---
name: minelink-design
description: Use this skill to generate well-branded interfaces and assets for MineLink (a mineral-logistics platform connecting Mines/Suppliers, Buyers and Transporters; formerly MineralGuide), either for production or throwaway prototypes/mocks. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping the portal chrome, dashboards, load-control desks, gate-security mobile views, live truck maps and the Super Global Serial Admin console.
user-invocable: true
---

Read the `readme.md` file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets
out and create static HTML files for the user to view. If working on production code,
copy assets and read the rules here to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to
build or design, ask some questions, and act as an expert designer who outputs HTML
artifacts _or_ production code, depending on the need.

## Quick orientation
- **Tokens:** link `styles.css` (it `@import`s everything in `tokens/`). Use semantic vars (`--accent`, `--surface-app`, `--text-strong`, `--status-*`) over raw scale steps.
- **Components:** `components/core/` and `components/forms/` — `Button`, `StatusBadge`, `PlatePill`, `StatCard`, `FeatureCard`, `Card`, `Avatar`, `Icon`, `Input`, `Select`. They read CSS custom properties and need the Material Symbols Rounded font `<link>`.
- **Chrome + screens:** `ui_kits/shared/shell.jsx` gives `PortalShell`/`Sidebar`/`AppBar`/`DataTable`/`MapCanvas`/`SlideOver`/`Modal`; each `ui_kits/<role>/` is a full interactive portal you can copy and adapt.

## The look in one breath
Deep-navy sidebar, cyan (`#00B5D8`) accent, off-white slate surfaces, white 16–20px
cards with hairline borders and soft shadows, UPPERCASE status pills, monospace
plates/tickets, Material Symbols Rounded icons in tinted wells, animated KPI numerals,
green "confirm" / orange "depart" action buttons, calm 180–280ms motion. No emoji, no
hand-drawn SVG, no saturated gradients except the navy shell.

## Respect the role rules
What a user sees depends on org type (Mine/Supplier · Buyer · Transporter) and role
(Owner/Admin/Management, plus locked single-screen Security & Controller, and mobile
Driver). The Super Global Serial Admin manages tokens and role-bound seat serials.
Don't show a role a screen it can't access — see `readme.md` and the kit READMEs.
