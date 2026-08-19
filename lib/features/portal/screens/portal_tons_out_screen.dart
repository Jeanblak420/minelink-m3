import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';
import 'package:flutter_application_1/main.dart' show companyRepositoryProvider;
import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/core/design/components/ml_page_header.dart';

// Extracted from `app_router.dart` (P4-01…P4-07). It was declared inside
// the router itself, which is why it had no screen file and no test.

final _log = LoggerFactory.getLogger('PortalTonsOutScreen');

/// Resolves a transporter company id from `/portal/{org}/tons-out/:transporterId`
/// to its display name (the value [RawReconView]'s transporter filter keys on).
/// Unknown / inaccessible ids resolve to null → unfiltered view, non-fatally.
final _transporterNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, transporterId) async {
  try {
    final company =
        await ref.watch(companyRepositoryProvider).getById(transporterId);
    return company.companyName;
  } catch (e) {
    _log.w('Could not resolve transporter $transporterId: $e');
    return null;
  }
});

/// Glue for `/portal/{org}/tons-out[/:transporterId]` (phase-2 nav merge T4):
/// the raw recon table ("tons out") company-scoped via the same resolution the
/// portal shell uses, optionally pre-filtered to one transporter.
class PortalTonsOutScreen extends ConsumerWidget {
  const PortalTonsOutScreen({super.key, this.transporterId});

  final String? transporterId;

  Widget _body(BuildContext context, String companyId, String? transporter) {
    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Tons out',
            // Not a row count: `RawReconView` owns the rows, and duplicating
            // the query here to print a number would be a second source of
            // truth for the figure this screen exists to show. What the page
            // itself knows is which transporter it was opened for, and that
            // is exactly the context the reader needs — the table below is
            // pre-filtered and would otherwise look like the whole set.
            meta: transporter == null
                ? 'All transporters'
                : 'Filtered to one transporter',
            description:
                'Every check-in → check-out as captured, with live Day / Week / '
                'Month / Year / Total cards and Excel/CSV/PDF export.',
          ),
          RawReconView(companyId: companyId, initialTransporter: transporter),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired(subject: 'tons-out rows');
    }
    final id = transporterId;
    if (id == null || id.isEmpty) {
      return _body(context, companyId, null);
    }
    final nameAsync = ref.watch(_transporterNameProvider(id));
    return nameAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _body(context, companyId, null),
      data: (name) => _body(context, companyId, name),
    );
  }
}
