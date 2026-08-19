One-liner: Cyan toggle switch, with an optional label+hint row — used for "24 hours", "Ongoing" and other on/off settings.

```jsx
<Switch checked={on} onChange={setOn} label="24 hours" hint="Mine operates continuously" />
<Switch checked={v} onChange={setV} />
```

Knob slides 280ms; slate-300 off, cyan on. Bare form (no label) returns just the toggle for inline use.
