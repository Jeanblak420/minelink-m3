import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// What a user sees when a link does not resolve.
///
/// ## Why this exists
///
/// It did not, and `GoRouter` supplies a default when you give it no
/// `errorBuilder`. Driving the live app on 2026-08-22, a mistyped portal path
/// produced go_router's own page:
///
///     Page Not Found                                      (bare app bar)
///     GoException: no routes for location: /portal/buyer/does-not-exist
///     Home                                                (bare text link)
///
/// Three things wrong with that, and the redesign had never touched any of
/// them because the screen belongs to a package rather than to this app:
///
/// 1. **It prints a raw exception class name at a customer.** This repo has a
///    release guard for exactly that (`no-raw-exception-in-ui`) and a
///    `friendlyError()` helper to obey it — and neither can see this string,
///    because it is interpolated inside go_router, not inside `lib/`. A guard
///    that greps this project's source is blind to a default supplied by a
///    dependency.
/// 2. **It carries none of the design system** — no tokens, no `MlEmptyState`,
///    no chrome. Every other empty and error state in the product is an
///    `MlEmptyState`; this was the one surface that looked like a crash.
/// 3. **"Home" is not where a signed-in user lives.** Every role has its own
///    landing route, resolved by `portalLandingRoute` on sign-in. Sending a
///    weighbridge controller to `/` is a second dead end after the first.
///
/// The path IS still shown, because "which link was wrong" is the one useful
/// fact here and it is a path, not an exception. What is dropped is the
/// machinery around it.
class RouteNotFoundScreen extends StatelessWidget {
  const RouteNotFoundScreen({
    super.key,
    required this.location,
    required this.onGoBack,
  });

  /// The path that did not resolve. Shown verbatim so a support conversation
  /// can start from the actual link rather than from "it said not found".
  final String location;

  /// Where the primary action goes — the caller resolves the signed-in user's
  /// real landing route, since this widget has no session of its own.
  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);

    return Scaffold(
      backgroundColor: semantic.surfaceApp,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MlTokens.contentPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: MlEmptyState(
                icon: Icons.explore_off_outlined,
                title: 'That page is not here',
                message:
                    'Nothing in MineLink answers to this address. The link may '
                    'be out of date, or it may have been typed by hand.\n\n'
                    '$location',
                action: MlButton.primary(
                  label: 'Back to your dashboard',
                  icon: Icons.arrow_back_rounded,
                  onPressed: onGoBack,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
