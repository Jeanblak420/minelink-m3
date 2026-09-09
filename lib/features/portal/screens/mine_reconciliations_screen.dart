import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';
import 'package:flutter_application_1/features/portal/widgets/recon_uploads_panel.dart';
import 'package:flutter_application_1/features/portal/widgets/weight_reconciliation_view.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/core/design/components/ml_page_header.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/mine_reconciliations_keys.dart';

/// Mine/Supplier reconciliations (CLAUDE.md §4): the mine's view of the same
/// three layers the buyer and transporter get — Side B weight variance
/// (mine net is the authoritative figure), Side A raw records, and the
/// two-version export→edit→re-upload panel. Server-side scoping shows only
/// trips where this company is the source.
class MineReconciliationsScreen extends ConsumerWidget {
  const MineReconciliationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }

    // The same rows the views below render, read here so the header can
    // say how many there are rather than say nothing.
    final rows = ref.watch(rawReconRowsProvider(companyId));

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Reconciliations',
            meta: rows.valueOrNull == null
                ? null
                : mlCount(rows.value!.length, 'recon row'),
            description:
                'Your loaded Net Weight is the authoritative figure. Compare it '
                'against delivered tons, view the raw records, and keep the '
                'original next to any edited re-upload.',
          ),
          TourTarget(
            id: 'mine.reconciliations.weight',
            targetKey: MineReconciliationsTourKeys.weightReconciliation,
            child: WeightReconciliationView(companyId: companyId),
          ),
          const SizedBox(height: 16),
          TourTarget(
            id: 'mine.reconciliations.raw',
            targetKey: MineReconciliationsTourKeys.rawRecords,
            child: RawReconView(companyId: companyId),
          ),
          const SizedBox(height: 16),
          TourTarget(
            id: 'mine.reconciliations.uploads',
            targetKey: MineReconciliationsTourKeys.uploadsPanel,
            child: ReconUploadsPanel(companyId: companyId),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
