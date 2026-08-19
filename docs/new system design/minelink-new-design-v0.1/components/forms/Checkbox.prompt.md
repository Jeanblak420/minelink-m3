One-liner: 6px-radius checkbox with cyan fill + white tick; supports indeterminate.

```jsx
<Checkbox checked={agree} onChange={setAgree} label="I confirm the tonnage is correct" />
<Checkbox indeterminate onChange={toggleAll} label="Select all trucks" />
```

Use for multi-select lists and confirmations. Bare form (no label) for table header/row cells.
