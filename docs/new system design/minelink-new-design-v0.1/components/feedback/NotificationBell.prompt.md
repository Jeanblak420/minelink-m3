One-liner: App-bar bell with a red unread count and a dropdown of `NotificationCard`s — operational alerts only.

```jsx
<NotificationBell notifications={notifs} onRead={read} onReadAll={readAll} onDismiss={remove} onViewAll={goAll} />
```

Chat is deliberately excluded — messages get their own floating chat launcher (`ChatFab`) with a separate badge. Bell dropdown shows compact cards, mark-all-read, and a "View all" footer.
