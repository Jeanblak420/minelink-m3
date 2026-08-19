One-liner: Centered zero-data state — tinted icon well, title, message, optional action button.

```jsx
<EmptyState icon="local_shipping" title="No trucks have GPS recorded"
  message="GPS updates when drivers report via the Driver App." />
<EmptyState icon="forum" tone="cyan" title="No conversations yet"
  message="Open Contacts to start one." action={<Button size="sm">New chat</Button>} />
```

Use for empty tables, maps with no data, and cleared notification lists.
