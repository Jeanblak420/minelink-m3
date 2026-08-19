One-liner: Vertical radio group with cyan ring + dot; options can carry a hint line.

```jsx
<RadioGroup value={diesel} onChange={setDiesel}
  options={[{value:'account',label:'On account',hint:'Diesel billed to buyer'},{value:'transporter',label:'On transporter'}]} />
```

For mutually-exclusive choices with descriptions. For compact 2–3 choice toggles prefer `Segmented`.
