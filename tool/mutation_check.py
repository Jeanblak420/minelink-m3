#!/usr/bin/env python3
"""Mutation check — prove a test bites, for tests that could never be red first.

    python tool/mutation_check.py            # run every mutation
    python tool/mutation_check.py --list     # show them without running
    python tool/mutation_check.py waypoint   # only mutations whose label or
                                             # file matches the substring

WHY THIS EXISTS
---------------
COMPLETION-PLAN.md §2 class B says a test counts as proof only if it was seen
FAILING against the pre-fix code. That rule is exactly right for a bugfix, and
impossible for a *characterisation* test — one written over behaviour that is
already correct, to stop it drifting. There is no "before" to be red against.

This is the substitute, and it is a stronger one: break the source the test
covers, and require the test to notice. A characterisation test that stays
green while its subject is broken is decoration, and this prints it as SILENT.

It earns its place. On its first run (S9-4, 2026-08-15) it found one:
`ChatRoom.fromJson` was asserted with `isA<List<String>>()` plus a length,
which a lazy `.cast<String>()` satisfies just as well as the eager
`List<String>.from()` the model actually uses. The test distinguished nothing.
Rewritten to assert that a malformed participant list throws at the JSON
boundary, it bites.

RULES FOR ADDING ONE
--------------------
- The mutation must be a plausible edit, not vandalism. "Someone refactors
  `>` to `>=`" or "someone swaps a default" — the mistakes that actually get
  made. Deleting a whole method proves nothing.
- One anchor, matched exactly once. A mutation that matches 0 or 2 places is
  reported SKIP, never silently ignored.
- The original file is restored from an in-memory BYTE copy in a `finally`,
  so a crash mid-run cannot leave the tree mutated, and the restore preserves
  line endings exactly. (An earlier version read/wrote in text mode and
  silently converted a CRLF file to LF — harmless here, but this tree is
  written by more than one agent session at a time and a stray whitespace
  change sweeping into somebody else's commit is a real hazard. Bytes only.)
"""
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LQ = "lib/features/portal/models/load_quality.dart"
BV = "lib/features/portal/models/buyer_load_value.dart"
PE = "lib/features/portal/models/production_entry.dart"
ST = "lib/features/portal/models/stockpile_transaction.dart"
SD = "lib/features/portal/models/stockpile_doc.dart"
SM = "lib/features/chat/models/support_models.dart"
CR = "lib/features/chat/models/chat_room_model.dart"
TW = "lib/features/portal/models/trip_waypoint.dart"
OS = "lib/features/portal/providers/order_stockpile_provider.dart"
RR = "lib/features/portal/widgets/raw_recon_view.dart"

T_LQ = "test/features/portal/load_quality_test.dart"
T_BV = "test/features/portal/buyer_load_value_test.dart"
T_PS = "test/features/portal/production_stockpile_models_test.dart"
T_SU = "test/features/chat/support_and_room_models_test.dart"
T_TW = "test/features/portal/trip_waypoint_test.dart"
T_OS = "test/features/portal/order_stockpile_fill_test.dart"
T_RR = "test/widgets/recon_columns_and_cards_test.dart"
MC = "lib/core/design/components/ml_meta.dart"
RT = "lib/core/routing/ml_route_title.dart"
T_MC = "test/widgets/header_meta_count_test.dart"
T_RT = "test/core/route_title_test.dart"

# (label, source file, exact anchor, replacement, test file that must go red)
MUTATIONS = [
    # ---- header meta lines (S5-22) -----------------------------------------
    # `mlCount` is new code covering new behaviour, so there is no pre-fix
    # state for its test to be red against. These are the two edits that would
    # actually get made to it.
    ("mlCount loses its singular case - every count reads '1 loads'",
     MC, "'$n ${n == 1 ? singular : (plural ?? '${singular}s')}'",
         "'$n ${plural ?? '${singular}s'}'", T_MC),
    ("mlCount ignores the supplied irregular plural - '3 batchs'",
     MC, "(plural ?? '${singular}s')", "'${singular}s'", T_MC),

    # ---- route titles (S5-12) ----------------------------------------------
    # The two tables this resolver replaced lean on `contains`/`startsWith`,
    # so several routes match more than one rule and only the ORDER decides.
    # A reordered branch compiles and renders; nothing but this notices.
    ("the leaderboard branch falls behind the generic insights rule",
     RT, "  if (path.endsWith('/leaderboard')) return 'Leaderboard';\n  if (path.startsWith('/super-admin/insights/') &&\n      !path.contains('/company/')) {\n    return 'Organization insights';\n  }",
         "  if (path.startsWith('/super-admin/insights/') &&\n      !path.contains('/company/')) {\n    return 'Organization insights';\n  }\n  if (path.endsWith('/leaderboard')) return 'Leaderboard';", T_RT),
    ("a deep portal alias takes the whole tail instead of the first segment",
     RT, "      return slash < 0 ? rest : rest.substring(0, slash);",
         "      return rest;", T_RT),
    ("the active-tab index stops being bounds-checked",
     RT, "      homeIndex >= 0 && homeIndex < labels.length "
         "? labels[homeIndex] : null;",
         "      homeIndex >= 0 ? labels[homeIndex] : null;", T_RT),
    ("a blank ?title= is treated as a title",
     RT, "    if (t != null && t.trim().isNotEmpty) return t.trim();",
         "    if (t != null) return t.trim();", T_RT),

    # ---- recon table: the column order and the all-time Total (S6-18/S6-19) -
    # These pin what is DRAWN. The row builder indexes `_cols` positionally and
    # its own comment records that two columns were once inserted ahead of POD
    # and nearly moved the POD link onto the Variance cell -- so a silent
    # reorder is a defect this codebase has already come close to shipping.
    ("recon columns reorder - PRODUCT and SOURCE swap",
     RR, "_ReconCol('Product', flex: 20),\n    _ReconCol('Source', flex: 22),",
         "_ReconCol('Source', flex: 22),\n    _ReconCol('Product', flex: 20),", T_RR),
    ("the export abbreviates a spec column name",
     RR, "'WAYBILL NUMBER',", "'WAYBILL',", T_RR),
    ("a period card stops saying which window it measures (S6-21)",
     RR, "'Month': 'net_mass · last_30_days',",
         "'Month': 'net_mass',", T_RR),
    # Reported NOT DETECTED on 2026-08-16 and that was correct: the fixture
    # had no row between 20 and 200 days, so widening Month by a day changed
    # nothing. A window test with no row near the edge tests the middle of the
    # range and calls it the boundary. Two rows 12 hours outside the 7- and
    # 30-day edges fixed it.
    ("the Month window drifts a day from the caption that describes it",
     RR, "if (at.isAfter(now.subtract(const Duration(days: 30)))) month += q;",
         "if (at.isAfter(now.subtract(const Duration(days: 31)))) month += q;", T_RR),
    ("the Week window drifts a day",
     RR, "if (at.isAfter(now.subtract(const Duration(days: 7)))) week += q;",
         "if (at.isAfter(now.subtract(const Duration(days: 8)))) week += q;", T_RR),
    ("the Total card becomes a 1-year window instead of all-time",
     RR, "      total += q;",
         "      if (at.isAfter(now.subtract(const Duration(days: 365)))) total += q;",
         T_RR),

    # ---- order flow: the fill arithmetic the buyer and transporter act on ---
    ("loadsReady rounds up instead of down",
     OS, "(balanceTons / 30).floor()", "(balanceTons / 30).ceil()", T_OS),
    ("fill fraction loses its clamp",
     OS, "(balanceTons / maxCapTons!).clamp(0.0, 1.0)",
         "(balanceTons / maxCapTons!)", T_OS),
    ("isComplete stops counting exactly-at-cap",
     OS, "balanceTons >= maxCapTons!", "balanceTons > maxCapTons!", T_OS),

    # ---- waypoints: the tare/gross contract with auto_generate_trip_waypoints
    ("tare weighbridge moves to sequence 4 (tare and gross swap)",
     TW, "locationType == WaypointType.weighbridge && sequenceOrder == 2",
         "locationType == WaypointType.weighbridge && sequenceOrder == 4", T_TW),
    ("hasCoordinates requires BOTH axes to be non-zero",
     TW, "latitude != 0 || longitude != 0", "latitude != 0 && longitude != 0", T_TW),
    ("WaypointType.parse stops normalising spaces and hyphens",
     TW, r"""(raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_')""",
         r"""(raw ?? '').trim().toLowerCase()""", T_TW),
    ("a gate confirmation needs only ONE party",
     TW, "driverConfirmed && securityConfirmed",
         "driverConfirmed || securityConfirmed", T_TW),

    # ---- quality: the penalty boundaries a mine and a buyer are shown -------
    ("excess moisture penalises a load exactly in spec",
     LQ, "return excess > 0 ? excess : null;",
         "return excess >= 0 ? excess : null;", T_LQ),
    ("grade tolerance tightens from 0.9999 to 1.0",
     LQ, "gradeFactor != null && gradeFactor! < 0.9999",
         "gradeFactor != null && gradeFactor! < 1.0", T_LQ),
    ("hasCert stops counting an attached lab PDF",
     LQ, "sizing != null ||\n      certPath != null;", "sizing != null;", T_LQ),
    ("a zero moisture maximum reads as 'no spec set'",
     LQ, "specCr2o3Pct != null || specMoistureMaxPct != null || specSizing != null;",
         "specCr2o3Pct != null || (specMoistureMaxPct ?? 0) > 0 || specSizing != null;",
         T_LQ),

    # ---- buyer money row ----------------------------------------------------
    ("a blank currency stops falling back to ZAR",
     BV, "currency: _s(j['currency']) ?? 'ZAR',",
         "currency: (j['currency'] as String?) ?? 'ZAR',", T_BV),
    ("an R0/ton load stops counting as priced",
     BV, "bool get isPriced => ratePerTon != null;",
         "bool get isPriced => (ratePerTon ?? 0) > 0;", T_BV),
    ("a zero-ton delivery stops counting as delivered",
     BV, "bool get isDelivered => deliveredTons != null;",
         "bool get isDelivered => (deliveredTons ?? 0) > 0;", T_BV),
    ("hasInvoice keys off the number rather than the amount",
     BV, "bool get hasInvoice => invoicedAmount != null;",
         "bool get hasInvoice => invoiceNumber != null;", T_BV),

    # ---- production & stockpile audit trail ---------------------------------
    ("a missing tonnage stops defaulting to 0",
     PE, "tons: ((j['tons'] as num?) ?? 0).toDouble(),",
         "tons: ((j['tons'] as num?) ?? -1).toDouble(),", T_PS),
    ("a null mined_tons stops defaulting to 0",
     PE, "minedTons: ((j['mined_tons'] as num?) ?? 0).toDouble(),",
         "minedTons: ((j['mined_tons'] as num?) ?? -1).toDouble(),", T_PS),
    ("stockpile movement magnitude loses its abs()",
     ST, "double get magnitude => delta.abs();",
         "double get magnitude => delta;", T_PS),
    ("any non-lab-result document becomes a picture",
     SD, "bool get isPicture => kind == 'picture';",
         "bool get isPicture => kind != 'lab_result';", T_PS),
    ("an untyped stockpile document defaults to picture",
     SD, "kind: (m['kind'] as String?) ?? 'lab_result',",
         "kind: (m['kind'] as String?) ?? 'picture',", T_PS),

    # ---- support tickets & chat rooms --------------------------------------
    ("only 'sent' counts as an open ticket (an unknown status vanishes)",
     SM, "bool get isOpen => status != 'completed';",
         "bool get isOpen => status == 'sent';", T_SU),
    ("a support notification defaults to already-read",
     SM, "read: j['read'] as bool? ?? false,",
         "read: j['read'] as bool? ?? true,", T_SU),
    ("the ticket category default stops matching the picker",
     SM, "category: j['category'] as String? ?? 'General',",
         "category: j['category'] as String? ?? 'Uncategorised',", T_SU),
    ("ticket timestamps stop converting to local time",
     SM, "createdAt: DateTime.parse(j['created_at'] as String).toLocal(),\n"
         "        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),",
         "createdAt: DateTime.parse(j['created_at'] as String),\n"
         "        updatedAt: DateTime.parse(j['updated_at'] as String),", T_SU),
    ("participant ids are cast lazily instead of validated at the boundary",
     CR, "participantIds: List<String>.from(json['participant_ids'] as List),",
         "participantIds: (json['participant_ids'] as List).cast<String>(),", T_SU),
]


def apply_and_run(label, path, old, new, testfile):
    full = os.path.join(REPO, path)
    original = open(full, "rb").read()
    src = original.decode("utf-8")
    if src.count(old) != 1:
        print("  SKIP    %-62s (anchor matched %d times)" % (label, src.count(old)))
        return None
    try:
        open(full, "wb").write(src.replace(old, new).encode("utf-8"))
        r = subprocess.run(["flutter", "test", testfile],
                           capture_output=True, text=True, cwd=REPO, shell=True)
        bit = r.returncode != 0
        print("  %s  %-62s" % ("BITES " if bit else "SILENT", label))
        return bit
    finally:
        open(full, "wb").write(original)


def main(argv):
    selected = MUTATIONS
    if "--list" in argv:
        for label, path, _, _, testfile in MUTATIONS:
            print("%-62s  %s  ->  %s" % (label, path, testfile))
        return 0
    needle = next((a for a in argv[1:] if not a.startswith("-")), None)
    if needle:
        selected = [m for m in MUTATIONS
                    if needle.lower() in m[0].lower() or needle.lower() in m[1].lower()]
        if not selected:
            print("no mutation matches %r" % needle)
            return 2

    print("Mutation check — every mutation must turn its test file RED\n")
    results = [(m[0], apply_and_run(*m)) for m in selected]
    ran = [b for _, b in results if b is not None]
    silent = [l for l, b in results if b is False]
    skipped = [l for l, b in results if b is None]

    print("\n%d/%d mutations detected" % (sum(1 for b in ran if b), len(ran)))
    for title, items in (("SKIPPED (anchor no longer matches — the source moved)", skipped),
                         ("NOT DETECTED (the test proves nothing about this)", silent)):
        if items:
            print(title + ":")
            for i in items:
                print("   -", i)
    return 1 if (silent or skipped) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
