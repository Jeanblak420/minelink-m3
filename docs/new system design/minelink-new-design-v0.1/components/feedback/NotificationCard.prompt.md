One-liner: One operational notification row — typed icon+tint, importance chip, unread cyan wash + dot, dismiss.

```jsx
<NotificationCard notification={n} onClick={open} onDismiss={remove} />
```

Types map to icon + color (securityAlert=red, roleAssigned=green, fleet*=blue, …); importance high=orange / extreme=red. **Chat is intentionally not a type here** — chat lives on the floating `NotificationBell`'s sibling chat launcher. Use `compact` inside the bell dropdown.
