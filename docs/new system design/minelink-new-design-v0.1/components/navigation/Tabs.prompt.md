One-liner: Tab strip in two variants — `underline` for in-page sections, `pill` for filter chips (with optional icon + count badge).

```jsx
<Tabs variant="underline" active={tab} onChange={setTab}
  tabs={[{key:'chats',label:'Chats'},{key:'groups',label:'Groups'},{key:'contacts',label:'Contacts'}]} />
<Tabs variant="pill" active={f} onChange={setF}
  tabs={[{key:'all',label:'All',badge:6},{key:'unread',label:'Unread',badge:3}]} />
```

Underline = the Messages/Operations section tabs; pill = the Notifications / Requests filter rows.
