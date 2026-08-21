import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart' show CompanyPin;
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';
import 'package:flutter_application_1/features/portal/widgets/recon_uploads_panel.dart';
import 'package:flutter_application_1/features/portal/widgets/weight_reconciliation_view.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Transporter reconciliations (ui_kits/transporter): load vs delivery
/// variance batches with status.
class TransporterReconciliationsScreen extends ConsumerWidget {
  const TransporterReconciliationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }

    final async = ref.watch(logisticsSnapshotProvider(companyId));
    // Party ids -> names for the batch rows (P8-22).
    final nameById = <String, String>{
      for (final p in ref
              .watch(partnerCompaniesProvider(
                  (companyId: companyId, orgFilter: '')))
              .valueOrNull ??
          const <CompanyPin>[])
        p.id: p.name,
    };

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'the reconciliations',
          error: e,
          onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) => MlPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MlPageHeader(
              title: 'Reconciliations',
              meta: mlCount(snap.trips.length, 'trip'),
              description:
                  'Load vs delivery variance reports — track disputes, approvals and discrepancies.',
            ),
            const SizedBox(height: 16),
            WeightReconciliationView(companyId: companyId),
            const SizedBox(height: 16),
            RawReconView(companyId: companyId),
            const SizedBox(height: 16),
            // Transporters are non-initiators — view-only per §4 (the server
            // also rejects their save_recon_upload).
            ReconUploadsPanel(companyId: companyId, canEdit: false),
            const SizedBox(height: 20),
            Text(
              'Reconciliation batches',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (snap.reconciliations.isEmpty)
              MlCard(
                child: MlEmptyState(
                  icon: Icons.balance_outlined,
                  title: 'No reconciliation batches yet.',
                  message:
                      'Batches are seeded automatically as trucks are loaded and delivered.',
                ),
              )
            else
              MlCard(
                padding: const EdgeInsets.all(18),
                child: MlDataTable(
                  columns: const [
                    MlColumn('Batch', flex: 3),
                    MlColumn('Status', flex: 2, align: TextAlign.right),
                    MlColumn('Updated', flex: 2, align: TextAlign.right),
                  ],
                  rows: [
                    for (final r in snap.reconciliations)
                      [
                        Row(
                          children: [
                            const MlIconWell(
                                icon: Icons.balance_outlined,
                                size: 36,
                                radius: 10),
                            const SizedBox(width: 12),
                            Flexible(
                              // Who the batch is between, not the first eight
                              // characters of its primary key (P8-22). A
                              // company whose name cannot be resolved reads
                              // "Unknown company" -- never the id.
                              child: Text(
                                  '${_party(nameById, r.supplierCompanyId)} → '
                                  '${_party(nameById, r.buyerCompanyId)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        MlStatusBadge.forStatus(r.status),
                        Text(
                          MlTime.day(r.updatedAt),
                          textAlign: TextAlign.right,
                          style: context.mlText.code(
                            color: MlSemantic.of(context).textMuted,
                            size: 13,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Party company id → display name, or an honest "Unknown company".
///
/// Never falls back to printing the id: a UUID under a label reading
/// "Supplier" is the label-vs-data fault this sweep exists to remove (P8-21,
/// P8-22).
String _party(Map<String, String> nameById, String? id) {
  if (id == null || id.isEmpty) return 'Not set';
  return nameById[id] ?? 'Unknown company';
}
