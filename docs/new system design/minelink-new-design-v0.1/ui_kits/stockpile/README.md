# Stockpile — UI kit

Rebuilds the mine's **stockpile management** screens (`stockpile_audit_screen` +
`stockpile_detail_screen`, ledger/transactions). These lived in an earlier
codebase mount that is not present in the current worktree, so this kit is
reconstructed from that documented structure — treat it as a design reference to
confirm against the real implementation when it is available.

- `index.html` — stockpile management inside the portal shell.
- `screens.jsx` — `StockpileManagement` + `PileDetail`.

Contents:
- KPI row: total on hand, received today, dispatched today, audit adjustments.
- **Stockpile cards** — per mineral: tons on hand (mono), today's trend, and a capacity-used bar (turns orange past 85%).
- **Detail ledger slide-over** — opening → net movement → closing balance, then a movement ledger of **RECEIVED** (loads in), **DISPATCHED** (loads out, tied to waybill refs), and **AUDIT** adjustments, each with ref, party, timestamp and actor.
- **Audit adjustment modal** — pick stockpile, direction (+/−), tons, reason (survey correction / moisture / spillage / reclassification / physical count) and a note; flagged as Management-only and logged to the ledger.
