import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/auth/services/logout_service.dart';
import 'package:flutter_application_1/features/portal/providers/company_access_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// The full explanation behind the notice bar: what has lapsed, what still
/// works, and the two routes to fixing it.
///
/// Rewritten 2026-08-15. It used to be a dead end — it read `companyName` and
/// `reason` from `state.extra`, which **nothing ever passed**, and offered a
/// single action: Sign Out. So the one screen dedicated to explaining a lapsed
/// licence knew nothing about the licence and told the customer to leave.
///
/// It now reads [companyAccessProvider], the same source as the notice bar and
/// the same `is_company_active()` the write policies consult, so the three
/// cannot disagree. The constructor arguments are kept because the route still
/// passes them, and they now act as a fallback for the company name only.
///
/// **Not a redirect target.** By the client's ruling of 2026-08-15 an expired
/// company is *read-only*, not locked out — so the router deliberately does not
/// send anyone here. Operational screens stay readable with the notice bar
/// explaining the state; this page is where "What does this mean?" leads.
class ExpiredAccessScreen extends ConsumerWidget {
  final String? companyName;
  final String? reason;

  const ExpiredAccessScreen({super.key, this.companyName, this.reason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = companyAccessOf(ref);
    final semantic = MlSemantic.of(context);
    // Suspension is the only state the customer cannot resolve themselves, so
    // it is the only one painted as an error.
    final tone = access.isSuspended ? MlTone.error : MlTone.warn;
    final name = access.companyName ?? companyName;

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: access.isRestricted ? access.headline : 'Access and licence',
            // The licence date is the whole subject of this screen, so the
            // meta carries it rather than a count. Null when there is no
            // token on file — "Expires —" would read as a date that exists.
            meta: access.tokenExpiresAt == null
                ? null
                : '${access.isRestricted ? 'Expired' : 'Expires'} '
                    '${access.tokenExpiresAt!.toIso8601String().split('T').first}',
            description: name == null
                ? null
                : 'For $name.${access.orgType == null ? '' : ' (${access.orgType})'}',
          ),

          if (!access.isRestricted)
            const MlEmptyState(
              icon: Icons.verified_user_outlined,
              title: 'Your access is active.',
              message: 'Nothing is restricted. This page explains what would '
                  'change if your token lapsed.',
            )
          else ...[
            MlCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    MlIconWell(
                        icon: Icons.lock_clock_rounded, tone: tone, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        access.explanation,
                        style: context.mlText.bodyMedium.copyWith(
                          color: semantic.textBody,
                        ),
                      ),
                    ),
                  ]),
                  if (reason != null) ...[
                    const SizedBox(height: 12),
                    Text('Reason given: $reason',
                        style:
                            context.mlText.bodyMedium.copyWith(
                              color: semantic.textMuted,
                            )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Spelled out rather than summarised. The single most useful thing
            // this page can do is stop somebody assuming they have lost data.
            _Section(
              title: 'What you can still do',
              tone: MlTone.done,
              items: const [
                'View every record you already have — trips, waybills, '
                    'reconciliations, tonnages and documents.',
                'Message MineLink, and read your existing conversations.',
                'Request a renewal, a new token, or extra seats.',
                'Log a support ticket and reply to it.',
                'Open and edit your own profile and account settings.',
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'What needs an active token',
              tone: tone,
              items: const [
                'Recording loads, weights, seals and proof of delivery.',
                'Moving a trip through its lifecycle, or dispatching one.',
                'Adding to or drawing down a stockpile.',
                'Raising or answering transportation and product requests.',
                'Messaging your own team or connected companies.',
              ],
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                MlButton.primary(
                  label: access.isPendingActivation
                      ? 'Request activation'
                      : 'Request a renewal',
                  icon: Icons.autorenew_rounded,
                  onPressed: () => context.go('/profile'),
                ),
                MlButton.outline(
                  label: 'Message MineLink',
                  icon: Icons.forum_outlined,
                  onPressed: () => context.go('/messages'),
                ),
                MlButton.ghost(
                  label: 'Back to my records',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => context.go('/home'),
                ),
                MlButton.ghost(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  onPressed: () =>
                      LogoutService.logoutWithConfirmation(context, ref),
                ),
              ],
            ),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

/// A titled list of plain statements, tinted by tone.
class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.tone, required this.items});

  final String title;
  final MlTone tone;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final tones = tone.colors(Theme.of(context).brightness);
    return MlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.mlText.editorialSmall.copyWith(
              color: semantic.textStrong,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      tone == MlTone.done
                          ? Icons.check_circle_outline_rounded
                          : Icons.lock_outline_rounded,
                      size: 15,
                      color: tones.fg,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: context.mlText.bodyMedium.copyWith(
                        color: semantic.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
