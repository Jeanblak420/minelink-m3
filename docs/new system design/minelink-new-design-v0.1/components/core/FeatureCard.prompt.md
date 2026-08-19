One-liner: The large navigational tile on portal dashboards — icon chip, bold title, description, outlined "Open →".

```jsx
<FeatureCard icon="alt_route" title="Routes & Mines"
  description="View all your active routes across mines and offload points. Assign trucks per route."
  onOpen={() => go('routes')} />
```

Usually shown three-up under the KPI row. Tone tints the icon chip — vary across a row (cyan / amber / green) for rhythm, matching the screen's section colors.
