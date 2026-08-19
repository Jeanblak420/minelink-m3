import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/core/design/components/ml_page_header.dart';
import 'package:flutter_application_1/features/portal/providers/live_tracking_provider.dart';
import 'package:flutter_application_1/features/portal/widgets/live_trip_map_view.dart';

/// Super-admin live map: every active trip on the platform with live truck
/// positions and ETA (§4 Live GPS tracking).
///
/// **Deliberately the same page as `LiveTripMapScreen`, differing only in
/// scope.** It already shared the content widget (`LiveTripMapView`) and
/// nothing else: the chrome around it was hand-rolled, so an admin and a
/// company looking at the same map saw a 19px serif title against a 24px one,
/// a flat 20px gutter against a responsive 28, no width cap against 1280, and
/// no meta line at all. Same data, two page frames.
///
/// `MlPageBody` + `MlPageHeader` are what the portal twin uses, so the two are
/// now identical by construction rather than by anyone remembering.
class LiveMapScreen extends ConsumerWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null = platform-wide; the RPC scopes by caller and an admin sees all.
    // Watched here as well as inside the view so the header can state how many
    // trucks are actually reporting — Riverpod dedupes, so this is the same
    // stream rather than a second one.
    final live = ref.watch(liveTripPositionsProvider(null));

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Live map',
            meta: live.valueOrNull == null
                ? null
                : mlCount(
                    live.value!.length,
                    'truck reporting',
                    'trucks reporting',
                  ),
            description:
                'Every active trip on the platform in real time — trucks appear '
                'as drivers share their GPS position.',
          ),
          const SizedBox(height: 18),
          const LiveTripMapView(companyId: null),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
