One-liner: Lifecycle status pill — maps trip/truck states to the brand's color tones.

```jsx
<StatusBadge tone="transit">OTW TO LOADING</StatusBadge>
<StatusBadge tone="atmine">AT MINE</StatusBadge>
<StatusBadge tone="done">LOADED</StatusBadge>
<StatusBadge tone="warn">MAINTENANCE</StatusBadge>
```

Tones: transit (blue), atmine (amber), done (green — loaded/available/departed-ok), warn (orange — maintenance), error (red — declined), neutral. Labels are typically UPPERCASE. Add `dot` for a leading status dot.
