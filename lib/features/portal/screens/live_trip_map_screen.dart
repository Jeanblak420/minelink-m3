import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/live_trip_map_view.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/core/design/components/ml_page_header.dart';
import 'package:flutter_application_1/features/portal/providers/live_tracking_provider.dart';

/// Org-portal "Live map" tab (§4 Live GPS tracking): the company's active
/// trips with live truck positions and ETA, scoped to trips the org is a
/// party to.
class LiveTripMapScreen extends ConsumerWidget {
  const LiveTripMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    // Watched here as well as inside LiveTripMapView so the header can
    // state how many trucks are actually reporting. Riverpod dedupes the
    // subscription — this is the same stream, not a second one.
    final live = ref.watch(liveTripPositionsProvider(companyId));

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Live map',
            meta: live.valueOrNull == null
                ? null
                : mlCount(live.value!.length, 'truck reporting',
                    'trucks reporting'),
            description:
                'Active trips in real time — trucks appear as drivers share their '
                'GPS position.',
          ),
          const SizedBox(height: 18),
          LiveTripMapView(companyId: companyId),
        ],
      ),
    );
  }
}
