# ⚠️ PLACEHOLDER — NOT A LEGAL DOCUMENT. DO NOT PUBLISH.

> **Drafted by an engineer to unblock implementation. Not legal advice, not
> reviewed by an attorney, must not be shown to a customer or relied on in a
> contract.** Its purpose is to give the app a document of roughly the right
> shape to build against so that swapping in the real terms is a content change.
>
> **Replace before release.** Tracked as S9-9; the `unreplaced-legal-placeholder`
> guard must read 0 before the S10 gate passes.
>
> `[SQUARE-BRACKETS]` mark decisions only the client or their attorney can make.

---

# Terms of Use — MineLink

**Operator:** [REGISTERED ENTITY NAME] ("we", "us")
**Effective date:** [DATE] · **Version:** [X.Y]

## 1. Who these terms bind

MineLink is licensed to **companies**, not to individuals. A company accepts
these terms when it registers and activates a serial token. Each user account
is created under a company and is bound by these terms through that company.

Where a user is an employee of a licensed company, the company is responsible
for that user's use of the platform.

## 2. Accounts, seats and tokens

- Access is controlled by a **serial token** issued to a company for a fixed
  period, and by a **seat count** limiting concurrent user accounts.
- When a token expires, the company's users are restricted to profile, account,
  support and the expiry notice. Operational functions are blocked.
- [CONFIRM: notice period before expiry, grace period if any, and whether data
  remains accessible in read-only form after expiry — this is a commercial
  decision with a data-protection consequence.]
- Seat reassignment is governed by [STATE THE RULE AND ANY COOLING-OFF PERIOD].

## 3. What the platform is, and is not

MineLink records and coordinates haulage operations. It is a **system of
record and coordination**. It is not:

- a party to any contract of carriage, sale or purchase between users;
- a weighbridge, a laboratory, or a certifying authority;
- a navigation authority, and its routing is advisory only.

**This section carries real weight and needs an attorney's attention.** The
platform computes figures that parties settle money against — Net Weight
(Gross − Tare), quality-adjusted payable tonnage, delivered-versus-loaded
variance, and Rand values derived from an agreed rate per ton. The terms must
state plainly whose figure governs in a dispute, and the answer must match what
the product actually does: **the mine's loaded Net Weight is the authoritative
figure for reconciliation and billing**, with the delivered figure stored
separately and the variance surfaced rather than resolved. Terms that say
otherwise would contradict the software.

## 4. Acceptable use

Users must not: share credentials; access data belonging to a company they are
not party to or employed by; upload unlawful content; interfere with the
service; or use it to breach a safety or transport regulation.

## 5. Accuracy of data entered

Weights, seal numbers, tonnages, quality certificates and proof-of-delivery
records are entered or captured by users. We do not verify them.
[STATE the allocation of liability for an incorrect entry — this is the single
most commercially consequential clause in the document.]

## 6. Availability

We aim for [X%] availability. [STATE: maintenance windows, whether any service
credit exists, and that drivers may lose signal on haul roads — which the
product is expected to tolerate rather than treat as a service failure.]

## 7. Fees

[COMMERCIAL TERMS: fee basis, invoicing cycle, payment terms, interest on
overdue amounts, suspension for non-payment, and how that interacts with token
expiry in §2. All amounts in South African Rand (ZAR).]

## 8. Intellectual property

The platform, its design and its documentation remain ours. Data a company
enters remains that company's. [CONFIRM: what licence we take over customer
data — in particular whether aggregated, de-identified operational statistics
may be used, since the platform's insights screens compute across companies.]

## 9. Termination

[STATE: notice, effect on data, export rights on exit, and the retention
period that then applies under the Data Retention Policy.]

## 10. Liability

[ATTORNEY TO DRAFT. Note for them: any cap should be considered against the
value of a single load — a truckload of chrome ore is a material sum, and a
haulage operation moves many per day. Consider also s48–49 of the Consumer
Protection Act where a user might be a juristic person below the threshold.]

## 11. Governing law and disputes

These terms are governed by the laws of the Republic of South Africa.
[STATE: forum, and whether arbitration is required before litigation.]

## 12. Changes

Material changes notified in-app [N] days before taking effect. Continued use
after that date constitutes acceptance. [CONFIRM this is enforceable for the
change types contemplated.]

---

*Placeholder ends. Nothing above has been reviewed by an attorney.*
