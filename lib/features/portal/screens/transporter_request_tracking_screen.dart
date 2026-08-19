import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/request_tracking_view.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/core/design/components/ml_page_header.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';

/// Transporter "Tracking": every request this transporter was dispatched on,
/// followed through to completion (all trips completed).
class TransporterRequestTrackingScreen extends ConsumerWidget {
  const TransporterRequestTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    // Same provider `RequestTrackingView` reads; Riverpod dedupes it.
    final tracked = ref.watch(requestTrackingProvider(companyId));

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Request tracking',
            meta: tracked.valueOrNull == null
                ? null
                : mlCount(tracked.value!.length, 'request'),
            description:
                'Where each of your requests sits in the admin review — '
                'submitted, sent back for revision, approved or linked.',
          ),
          RequestTrackingView(companyId: companyId),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
