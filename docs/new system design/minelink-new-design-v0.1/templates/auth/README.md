# Auth / Onboarding — UI kit

Recreates the MineLink **sign-in & onboarding** flow.

- `index.html` — interactive: Login → WhatsApp OTP / Forgot password / Register organization, with a success state.
- `screens.jsx` — `LoginScreen`, `OtpScreen`, `ForgotScreen`, `RegisterScreen` + shared `AuthRail` brand panel.

Faithful to the codebase (`lib/features/auth/`): the identifier field accepts
**email or WhatsApp number**, password has show/hide, "Forgot Password?", and a
**"Sign in with WhatsApp code"** OTP path (`whatsapp_otp_screen.dart`). Registration
picks an **OrgType** — Mine/Supplier, Buyer, Transporter (`user_type.dart`).
