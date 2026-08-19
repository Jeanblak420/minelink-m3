One-liner: Renders a Material Symbols Rounded glyph — the icon system used across every MineLink portal surface.

```jsx
<Icon name="local_shipping" size={24} color="var(--accent)" />
<Icon name="check_circle" fill={1} color="var(--action-go)" />
```

Requires the Material Symbols Rounded font `<link>` in the page head. Use outlined (`fill={0}`) for nav and inline icons; filled (`fill={1}`) for active/emphasis states. Common names: dashboard, local_shipping, alt_route, balance, map, handshake, security, tune, admin_panel_settings, notifications.
