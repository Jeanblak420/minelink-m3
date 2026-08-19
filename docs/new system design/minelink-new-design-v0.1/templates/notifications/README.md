# Notifications — UI kit

Recreates MineLink's notification system (`lib/features/notifications/`).

- `index.html` — the full **Notifications centre** inside the portal shell (filter tabs: All / Unread / Priority; mark-all-read; clear-all; per-item dismiss).
- `screens.jsx` — `NotificationsScreen`, `NotifBell` (bell dropdown panel with unread count), `NotifItem`.

Typed alerts mirror `NotificationType` (employeeRequest, roleAssigned, requestDeclined, securityAlert, controllerAction, dismissal*, fleet*, general) each with an icon + tint, and `NotificationImportance` (normal = blue, high = orange, extreme = red). Unread rows carry a cyan wash + dot. Tapping routes by type in the real app (employee requests → company employees, dismissals → dismissal management, etc.).

**Chat is deliberately excluded here.** Chat/message alerts are NOT shown in this notification centre or the app-bar bell — they have their own unread badge on the **floating chat launcher** (`ChatFab` in `ui_kits/shared/shell.jsx`, bottom-right of every portal). The bell is for operational/system notifications only.
