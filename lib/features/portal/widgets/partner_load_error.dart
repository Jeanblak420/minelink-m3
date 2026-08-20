import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/friendly_error.dart';

import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// Shown when the partner-companies read fails (P2-04 / P2-09).
///
/// `listPartnerCompanies` used to end in `catch (_) { return const []; }`, so
/// an RLS denial, an expired session and a dead network were all indistinguish-
/// able from "this company has no partners" — the screen rendered a confident,
/// wrong empty state. That swallow is gone and the service rethrows, but the
/// rethrow only buys something where a caller actually shows it: two screens
/// still resolved the provider with `.valueOrNull ?? []` and quietly restored
/// the old behaviour one layer up.
///
/// This is deliberately a **blocking** state rather than a banner over a
/// partial list. On the mine's Buyers screen the partner read *is* the list;
/// on the dashboard it resolves the buyer names in the tons-out table, so a
/// failure there turns named rows into blanks. In both cases a partial render
/// looks like a complete one, which is the fault being fixed.
///
/// Retry invalidates the provider rather than the whole snapshot: the rest of
/// the page's data is fine and re-fetching it would be a slower, noisier
/// recovery for no benefit.
class PartnerLoadError extends ConsumerWidget {
  final String companyId;
  final String orgFilter;
  final Object error;

  /// What this screen could not build, in the operator's words — "buyers",
  /// "linked mines". Used in the message so the failure names the thing the
  /// user was looking at rather than a provider.
  final String subject;

  const PartnerLoadError({
    super.key,
    required this.companyId,
    required this.orgFilter,
    required this.error,
    required this.subject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MlEmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load $subject',
      message: 'This is a failure to read, not an empty list — the $subject '
          'shown would be incomplete.\n\n${friendlyError(error)}',
      action: FilledButton.tonalIcon(
        onPressed: () => ref.invalidate(
          partnerCompaniesProvider((companyId: companyId, orgFilter: orgFilter)),
        ),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Retry'),
      ),
    );
  }
}
