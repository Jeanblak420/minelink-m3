import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/models/tons_out_entry.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';

/// The Tons-out rows, from the same real data the recon tables read.
///
/// This file used to hold `tonsOutEntriesFromWaybills`, which built the rows out
/// of `OperationTransaction` metadata via a key-alias lookup. It had **zero call
/// sites** anywhere in `lib/` or `test/`, so the screen it fed could only ever be
/// constructed with an empty list — 845 lines of table, filters, sorting and
/// range pickers with no way to reach a single row. Jean, 2026-08-17, on being
/// asked whether to delete it: *"no all of these are supposed to be linked to
/// real stuff/real places/real data."*
///
/// So it is, now — through `list_raw_recon_rows`, the RPC that already backs
/// every recon surface in the product. One source of truth, two ways of looking
/// at it: the recon table is the spreadsheet, this is the one you search and
/// sort.
final tonsOutEntriesProvider =
    FutureProvider.family.autoDispose<List<TonsOutEntry>, String?>(
  (ref, companyId) async {
    final rows = await ref.watch(rawReconRowsProvider(companyId).future);
    return tonsOutEntriesFromReconRows(rows);
  },
);

/// Maps recon rows to Tons-out rows, newest first.
///
/// Kept as a plain function so it is testable without a container, and so the
/// ordering is stated in one place rather than assumed from the RPC.
List<TonsOutEntry> tonsOutEntriesFromReconRows(List<RawReconRow> rows) {
  final out = [for (final r in rows) TonsOutEntry.fromReconRow(r)];
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}
