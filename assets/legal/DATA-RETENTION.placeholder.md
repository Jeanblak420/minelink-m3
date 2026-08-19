# ⚠️ PLACEHOLDER — NOT A LEGAL DOCUMENT. DO NOT PUBLISH.

> **Drafted by an engineer to unblock implementation. Not legal advice, not
> reviewed by an attorney.** Replace before release — tracked as S9-9; the
> `unreplaced-legal-placeholder` guard must read 0 before the S10 gate passes.
>
> This one is different from the other two in an important way: **it is the
> only one of the three that also describes work the software does not yet do.**
> Every row in §2 marked *not implemented* is a schedule with nothing enforcing
> it. Writing the policy does not create the deletion job.

---

# Data Retention Policy — MineLink

**Operator:** [REGISTERED ENTITY NAME] · **Version:** [X.Y] · **Effective:** [DATE]

POPIA s14 requires that records not be retained for longer than necessary,
unless retention is required by law or by a contract. This policy sets the
period for each category and names what enforces it.

## 1. Principles

1. Operational records that evidence a commercial transaction are retained for
   the statutory period, and are **not** deletable on request during it.
2. Personal information not needed for that evidentiary purpose is retained for
   the shortest period that keeps the product usable.
3. Every period below must have something that actually applies it. A period
   with no mechanism is an intention, not a control.

## 2. Retention schedule

| Category | Proposed period | Basis | Enforced by |
|---|---|---|---|
| Trips, transactions, waybills, weighbridge weights, seal records | [5 YEARS?] | commercial record; [CONFIRM statutory basis — tax, mining, or transport regulation] | **not implemented** — no deletion job exists |
| Proof-of-delivery photos | [5 YEARS?] | evidence of delivery | **not implemented** |
| Load and scale photos | [N] | evidence of weight | **not implemented** |
| Quality certificates and lab reports | [N] | contractual quality dispute window | **not implemented** |
| Vehicle GPS position traces | **[SHORT — 90 DAYS?]** | live tracking and ETA only; no evidentiary purpose after the trip closes | **not implemented** |
| In-app messages and attachments | [N] | operational coordination | **not implemented** |
| Support tickets | [N] | service history | **not implemented** |
| Identity, passport, visa and licence documents | duration of employment + [N] | statutory compliance | **not implemented** |
| Signature images | while the account is active, plus the life of any document bearing it | the signature is part of the signed record | **not implemented** |
| Audit logs | [7 YEARS?] | accountability | **not implemented** |
| Account and profile records | account life + [N] | contract | **not implemented** |
| Error and diagnostic logs | [30–90 DAYS] | diagnosis | [CONFIRM what the hosting provider retains and for how long] |

## 3. The gap, stated plainly

**Nothing in the platform currently deletes anything on a schedule.** There are
seven scheduled jobs in the database; six send notifications and one closes
target cycles. None of them enforce retention.

The two that matter most:

- **GPS traces.** Position is recorded roughly every 30 seconds per active
  vehicle. That table grows without bound and has the shortest legitimate
  retention of anything in the system — it is the clearest case where holding
  data longer than needed is both a POPIA exposure and a scaling problem.
- **Signatures and identity documents.** These are the most sensitive items
  held, and there is no process that removes them when an employee leaves.

Implementing the schedule is engineering work that must follow the client's
decisions above, not precede them. It should be raised as its own item once
the periods are fixed.

## 4. Deletion on request

Where a person exercises their POPIA right to deletion, records held under a
legal obligation or as evidence of a transaction between companies are retained
for the period in §2; everything else is deleted. **The response to a request
must say which of the two applied to each category** rather than answering with
a single yes or no.

## 5. Backups

[CONFIRM: backup retention, and how deletion propagates into backups. Note for
the drafter — as of 2026-08-15 there is a single production project with no
staging environment and no tested restore procedure (S9-7), so this section
cannot honestly be completed yet.]

## 6. Review

Reviewed at least annually by the Information Officer. Next review: [DATE].

---

*Placeholder ends. Nothing above has been reviewed by an attorney.*
