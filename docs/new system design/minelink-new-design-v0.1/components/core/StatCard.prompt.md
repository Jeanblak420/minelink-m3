One-liner: Dashboard KPI tile — tinted icon well, label, big extrabold value, optional "vs yesterday" delta.

```jsx
<StatCard icon="local_shipping" label="Total Fleet" value="6" />
<StatCard icon="inventory_2" label="Tons Delivered" value="33.2" unit="t" delta="12.5t" deltaDir="up" />
```

Four per row on wide dashboards. Tone tints the icon well (cyan default). The value is the focal point — keep labels short. Delta shows a green up-arrow / red down-arrow with "vs yesterday".
