import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/screens/tons_out_detail_screen.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/utils/tons_out_mapping.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';

/// The searchable, sortable view of the same loads the recon table shows.
///
/// `TonsOutDetailScreen` has always had the things the recon spreadsheet does
/// not — a free-text search across every column, a date range, a net-mass
/// range, and sorting on any column — and none of it had ever run, because the
/// screen was only ever constructed as `TonsOutDetailScreen(entries: [])` by a
/// widget test. Nothing in `lib/` imported it, no route pointed at it, and the
/// one function that could have supplied its rows had no callers either.
///
/// Jean, 2026-08-17, asked for it to be connected rather than removed: *"all of
/// these are supposed to be linked to real stuff/real places/real data."* This
/// is the connection — the same `list_raw_recon_rows` output that feeds every
/// recon surface, mapped through [tonsOutEntriesProvider].
class PortalTonsOutSearchScreen extends ConsumerWidget {
  const PortalTonsOutSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) return const PortalCompanyRequired();

    final async = ref.watch(tonsOutEntriesProvider(companyId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
        subject: 'the loads',
        error: e,
        onRetry: () => ref.invalidate(tonsOutEntriesProvider(companyId)),
      ),
      // A key on the row count so the screen's range sliders, which bound
      // themselves to the data in `initState`, are rebuilt when the data
      // changes rather than keeping the first load's floor and ceiling.
      data: (entries) => TonsOutDetailScreen(
        key: ValueKey('tons-out-${entries.length}'),
        entries: entries,
      ),
    );
  }
}
