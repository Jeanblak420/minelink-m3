# Driver Mobile App — UI kit

Faithful premium recreation of the **Driver App** mockup (`uploads/Transporter -
Driver Mobile view.png`) — the mobile view for the Transporter **Driver** role.

- `index.html` — renders the app in a phone frame.
- `screens.jsx` — `DriverApp` + reusable `PhoneFrame`.

Sections: header ("Driver App — Manage your trip"), **Current Trip** card (plate,
commodity, From→To route timeline, status pill) with actions **Directions /
Arrived at loading / Arrived at offloading / Upload POD**, **Recent Trips** list,
and a Dashboard / Trip / Profile bottom nav. No dedicated driver screen exists in
the Flutter code yet — this kit is the design reference for building it.
