# User Settings — UI kit

Per-user settings inside the portal shell, with a **Themes & Appearance** category.

- `index.html` — nav: Account, Themes & Appearance, Notifications, Security.
- **Themes** renders `MLTheme.renderSettings()` from `../shared/theme.js`: Mode (Light/Dark), Accent (6 colors), and Background presets — Solid (dark→light ramp), 2/3/4-colour gradients, slow-moving Animated gradients, and a fully **Customizable gradient** builder (2–4 colours, angle, animation toggle, base text mode).

All choices persist per-user to `localStorage` and only change that user's view. Card surfaces stay opaque under gradient backgrounds so text stays readable; a note tells users to pick a Solid or switch Mode if readability suffers.
