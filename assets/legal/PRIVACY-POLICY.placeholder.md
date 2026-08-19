# ⚠️ PLACEHOLDER — NOT A LEGAL DOCUMENT. DO NOT PUBLISH.

> **This text was drafted by an engineer to unblock implementation. It is not
> legal advice, it has not been reviewed by an attorney, and it must not be
> shown to a customer, relied on in a contract, or shipped in a release.**
>
> Its only purpose is to give the app a document of roughly the right *shape*
> and length to build against — routes, screens, scroll behaviour, versioning —
> so that swapping in the real policy is a content change and nothing else.
>
> **Replace before release.** Tracked as S9-9. The release guard
> `unreplaced-legal-placeholder` counts the files still carrying this banner and
> must read **0** before the S10 release gate can pass.
>
> Every `[SQUARE-BRACKET]` below is a decision only the client or their attorney
> can make. They are deliberately left unfilled rather than guessed — a plausible
> invented answer is more dangerous here than an obvious gap.

---

# Privacy Policy — MineLink

**Operator:** [REGISTERED ENTITY NAME], registration number [CIPC REG NO],
of [REGISTERED ADDRESS], South Africa.
**Effective date:** [DATE] · **Version:** [X.Y] · **Last reviewed:** [DATE]

MineLink is a mineral logistics and bulk-commodity haulage platform. This
policy explains what personal information we process, why, and what rights you
have under the Protection of Personal Information Act, 2013 (POPIA).

## 1. Information Officer

POPIA requires a registered Information Officer.

- **Information Officer:** [FULL NAME], [POSITION]
- **Email:** [EMAIL] · **Telephone:** [PHONE]
- **Registered with the Information Regulator:** [YES / NO — REGISTRATION REF]

Complaints may also be made to the Information Regulator (South Africa),
[REGULATOR CONTACT DETAILS AS PUBLISHED AT THE TIME OF PUBLICATION].

## 2. Personal information we process

Listed by what the product actually collects. This section should be checked
against the schema before publication, not copied forward.

| Category | Examples | Why we hold it |
|---|---|---|
| Account identity | name, email address, mobile number, password hash | authentication, account recovery |
| Employment record | employer company, role, employee number, dismissal status | access control — role determines what a user may do |
| Identity documents | ID / passport / work-visa / licence documents and expiry dates | statutory driver and site-access compliance |
| Signature | a drawn signature image | placed on waybills and proof-of-delivery records |
| Location | vehicle GPS position while a trip is active, at approximately 30-second intervals | live trip tracking, ETA, route navigation |
| Operational records | trips, weighbridge weights, seal numbers, load photos, POD photos | the commercial record of a haulage transaction |
| Communications | in-app messages, attachments, support tickets | operational coordination and support |
| Device and usage | log entries, error reports, IP address | security, diagnosing faults |

**Special personal information.** [CONFIRM: does the product process any
special personal information as defined in s26 of POPIA — e.g. biometric data?
A drawn signature may be argued either way and needs an attorney's view.]

**Children.** MineLink is not offered to persons under 18. [CONFIRM.]

## 3. Location data — stated separately because it is the most intrusive

While a driver is on an active trip and has enabled location sharing, the app
records the vehicle's position at approximately 30-second intervals. That
position is visible to the transporter, the mine and the buyer party to that
trip, and to the platform administrator.

- Collection is tied to an **active trip**, not to the person.
- The driver can turn sharing off in the app. [CONFIRM the operational and
  contractual consequence of doing so — this is an employment matter, not only
  a privacy one.]
- Retention: see §7.

## 4. Lawful basis for processing

For each purpose, one of the s11 justifications must apply.

| Purpose | Justification relied on |
|---|---|
| Providing the platform to a contracting company | performance of a contract |
| Access control and role enforcement | legitimate interest |
| Statutory compliance records (licences, permits) | compliance with a legal obligation |
| Live trip location | [LEGITIMATE INTEREST / CONSENT — ATTORNEY TO DECIDE; this is the one most likely to be challenged] |
| Marketing | consent, freely given and withdrawable |

## 5. Who we share information with

- **Other parties to a transaction.** A haulage transaction has a mine, a
  buyer and a transporter. Each sees the parts of the record they are party to.
  This is the core function of the product and is not optional.
- **Operators.** [LIST EACH: hosting and database provider, mapping and routing
  provider, messaging provider, error-reporting provider — with the country in
  which each stores data.]
- **Cross-border transfer.** [CONFIRM under s72 which operators store data
  outside South Africa and on what basis the transfer is permitted.]
- We do not sell personal information.

## 6. Security safeguards

- Access is enforced in the database by row-level security, not only in the app.
- Documents, photos, signatures and attachments are held in private storage,
  reachable only through short-lived signed URLs scoped to a permitted party.
- Passwords are hashed by the authentication provider; staff cannot read them.
- [DESCRIBE: encryption at rest and in transit, breach-notification procedure
  and timeline under s22, and who is accountable for it.]

## 7. Retention

See `DATA-RETENTION.placeholder.md`. Summary: operational records are retained
for [N] years to satisfy [STATUTORY BASIS]; location traces for [N]; account
records for [N] after the account closes.

## 8. Your rights under POPIA

You may request access to your personal information, correction or deletion of
it, object to processing, and lodge a complaint with the Information Regulator.

Requests go to the Information Officer above. We will respond within
[N] days. Access requests must be made on **Form 2** under the Promotion of
Access to Information Act; a prescribed fee may apply.

**Note for the drafter:** some of this data cannot simply be deleted on
request — a waybill is a commercial record of a transaction between three
companies, and a signature on it is part of that record. The policy must say
plainly which categories are subject to deletion and which are retained under
a legal obligation, rather than promising an unqualified right to erasure.

## 9. Changes

Material changes will be notified in-app before they take effect. Prior
versions are archived at [LOCATION].

---

*Placeholder ends. Nothing above has been reviewed by an attorney.*
