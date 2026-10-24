import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/core/design/components/ml_page_header.dart';
import 'package:flutter_application_1/features/portal/widgets/load_quality_table.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';

/// Super-admin combined recon table (CLAUDE.md §4 "Recon tables"): every
/// truck from every transporter in one table — the platform-wide view of the
/// same data each org sees scoped to their own loop. The transporter filter
/// inside the view gives the transporter-based cut.
///
/// **Deliberately the same page as `PortalTonsOutScreen`, differing only in
/// scope.** It already shared the content widget (`RawReconView`) and nothing
/// else: the chrome was hand-rolled, so an admin and a company reading the same
/// table saw a 19px serif title against a 24px one, a flat 20px gutter against
/// a responsive 28, no width cap against 1280, and no meta line at all.
class ReconTablesScreen extends StatelessWidget {
  const ReconTablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Recon tables',
            // Not a row count, for the same reason the portal twin gives: the
            // view below owns the rows, and re-querying here to print a number
            // would put a second source of truth behind the very figure this
            // screen exists to show. What the page itself knows is its scope.
            meta: 'All transporters · platform-wide',
            description:
                'The combined recon table — every truck from every transporter. '
                'Use the Transporter filter for the per-transporter view.',
          ),
          // null = platform-wide (the RPC scopes by caller; the admin sees all).
          const RawReconView(companyId: null, cardsOnPhone: true),
          const SizedBox(height: 16),
          // Platform-wide quality certificates per load (view-only here — the
          // loading mine attaches them).
          const LoadQualityTable(companyId: null),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
