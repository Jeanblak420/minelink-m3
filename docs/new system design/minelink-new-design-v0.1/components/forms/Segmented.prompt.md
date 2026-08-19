One-liner: Inset segmented control for 2–5 short, mutually-exclusive options — the raised selected chip sits in a slate well.

```jsx
<Segmented value={pay} onChange={setPay} options={['50/50','Daily','7 days','30 days']} />
```

Used for payment terms, diesel, direction (Inbound/Outbound). For longer option sets use `Select`; for options needing descriptions use `RadioGroup`.
